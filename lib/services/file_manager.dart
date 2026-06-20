import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../models/media_item.dart';

class FileManager {
  static final FileManager instance = FileManager._init();
  final http.Client _client = http.Client();

  FileManager._init();

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<Directory> get _mediaDirectory async {
    final path = await _localPath;
    final dir = Directory(p.join(path, 'media'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Downloads a file from the remote URL and saves it to local disk storage using Dio.
  /// On Web, it bypasses downloading and returns the original URL.
  Future<String?> downloadFile(
    String url,
    int itemId, {
    String? itemType,
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (kIsWeb) {
      return url; // Direct URL streaming fallback on Web
    }

    String? localFilePath;
    String? tempFilePath;
    try {
      final dir = await _mediaDirectory;
      // Handle urls with spaces
      final encodedUrl = url.trim().replaceAll(' ', '%20');
      final uri = Uri.parse(encodedUrl);
      
      // Handle file extension or default to custom binary format suffix
      String extension = p.extension(uri.path);
      if (extension.isEmpty) {
        if (itemType != null) {
          extension = itemType == 'video' ? '.mp4' : '.jpeg';
        } else {
          // Infer from typical media types or default to generic extension
          extension = url.contains('.mp4') ? '.mp4' : '.jpeg';
        }
      }
      
      final localFileName = 'media_$itemId$extension';
      localFilePath = p.join(dir.path, localFileName);
      tempFilePath = '$localFilePath.tmp';
      final file = File(localFilePath);
      final tempFile = File(tempFilePath);

      // Return path if file is already fully downloaded and not empty (e.g. from failed downloads)
      if (await file.exists() && await file.length() > 0) {
        print('Media file ID $itemId already exists locally at: $localFilePath');
        if (onProgress != null) onProgress(1.0);
        return localFilePath;
      }

      if (isCancelled?.call() == true) return null;

      print('Querying headers for media file ID $itemId...');
      int totalBytes = -1;
      bool acceptRanges = false;
      try {
        final headRequest = http.Request('HEAD', uri);
        headRequest.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
        final headResponse = await _client.send(headRequest).timeout(const Duration(seconds: 5));
        if (headResponse.statusCode == 200 || headResponse.statusCode == 206) {
          final lengthStr = headResponse.headers['content-length'];
          if (lengthStr != null) {
            totalBytes = int.tryParse(lengthStr) ?? -1;
          }
          final rangeStr = headResponse.headers['accept-ranges'];
          if (rangeStr != null && rangeStr.trim().toLowerCase() == 'bytes') {
            acceptRanges = true;
          }
        }
      } catch (e) {
        print('HEAD request failed for ID $itemId, using defaults: $e');
      }

      if (isCancelled?.call() == true) return null;

      String? downloadedTempPath;
      // If file size is large (> 2MB) and server supports range queries, do parallel range downloads
      if (totalBytes > 2 * 1024 * 1024 && acceptRanges) {
        print('Downloading media file ID $itemId via range-based parallel threads...');
        downloadedTempPath = await _downloadMultiThreaded(uri, tempFile, totalBytes, onProgress, isCancelled: isCancelled);
      } else {
        print('Downloading media file ID $itemId via single-threaded stream...');
        downloadedTempPath = await _downloadSingleThreaded(uri, tempFile, totalBytes, onProgress, isCancelled: isCancelled);
      }

      if (isCancelled?.call() == true) return null;

      if (downloadedTempPath != null) {
        final downloadedTempFile = File(downloadedTempPath);
        if (await downloadedTempFile.exists() && await downloadedTempFile.length() > 0) {
          if (await file.exists()) {
            await file.delete();
          }
          await downloadedTempFile.rename(localFilePath);
          print('Successfully completed download for ID $itemId: $localFilePath');
          return localFilePath;
        }
      }
    } catch (e) {
      // Log error internally and return null to fallback to network streaming if needed
      print('Media download error for ID $itemId: $e');
      // Clean up partial file on failure if it exists
      try {
        if (tempFilePath != null) {
          final tempFile = File(tempFilePath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<String?> _downloadMultiThreaded(
    Uri uri,
    File file,
    int totalBytes,
    void Function(double progress)? onProgress, {
    bool Function()? isCancelled,
  }) async {
    const int numChunks = 4;
    final chunkSize = (totalBytes / numChunks).ceil();
    final List<Map<String, int>> ranges = [];
    for (int i = 0; i < numChunks; i++) {
      final start = i * chunkSize;
      final end = (i == numChunks - 1) ? totalBytes - 1 : (start + chunkSize - 1);
      ranges.add({'start': start, 'end': end});
    }

    final List<int> downloadedBytesPerChunk = List.filled(numChunks, 0);

    void updateProgress() {
      if (onProgress != null) {
        final totalDownloaded = downloadedBytesPerChunk.reduce((a, b) => a + b);
        onProgress(totalDownloaded / totalBytes);
      }
    }

    // Temporary chunk files to prevent writing to the same file concurrently
    final List<File> chunkFiles = List.generate(numChunks, (index) {
      return File('${file.path}_chunk_$index.tmp');
    });

    try {
      await Future.wait(
        List.generate(numChunks, (index) async {
          if (isCancelled?.call() == true) throw Exception('Download cancelled');
          final range = ranges[index];
          final start = range['start']!;
          final end = range['end']!;
          final chunkFile = chunkFiles[index];

          final request = http.Request('GET', uri);
          request.headers['Range'] = 'bytes=$start-$end';
          request.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
          
          final response = await _client.send(request).timeout(const Duration(seconds: 15));
          if (response.statusCode != 206) {
            throw Exception('Server returned HTTP ${response.statusCode} instead of 206 for range download');
          }

          final sink = chunkFile.openWrite();
          try {
            int received = 0;
            await for (final chunk in response.stream.timeout(const Duration(seconds: 15))) {
              if (isCancelled?.call() == true) throw Exception('Download cancelled');
              sink.add(chunk);
              received += chunk.length;
              downloadedBytesPerChunk[index] = received;
              updateProgress();
            }
            await sink.flush();
          } finally {
            await sink.close();
          }
        }),
      );
      
      if (isCancelled?.call() == true) throw Exception('Download cancelled');

      // Concatenate all downloaded chunks into the final temp file
      final finalSink = file.openWrite();
      try {
        for (final chunkFile in chunkFiles) {
          final chunkStream = chunkFile.openRead();
          await for (final data in chunkStream) {
            if (isCancelled?.call() == true) throw Exception('Download cancelled');
            finalSink.add(data);
          }
        }
        await finalSink.flush();
      } finally {
        await finalSink.close();
      }

      // Delete the temporary chunk files
      for (final chunkFile in chunkFiles) {
        try {
          if (await chunkFile.exists()) {
            await chunkFile.delete();
          }
        } catch (_) {}
      }

      print('Successfully finished multi-threaded download: ${file.path}');
      return file.path;
    } catch (e) {
      print('Multi-threaded download failed, cleaning up chunk files and falling back to single-threaded download: $e');
      // Clean up chunk files on failure
      for (final chunkFile in chunkFiles) {
        try {
          if (await chunkFile.exists()) {
            await chunkFile.delete();
          }
        } catch (_) {}
      }
      return _downloadSingleThreaded(uri, file, totalBytes, onProgress, isCancelled: isCancelled);
    }
  }

  Future<String?> _downloadSingleThreaded(
    Uri uri,
    File file,
    int totalBytes,
    void Function(double progress)? onProgress, {
    bool Function()? isCancelled,
  }) async {
    final request = http.Request('GET', uri);
    request.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
    final response = await _client.send(request).timeout(const Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final total = totalBytes > 0 ? totalBytes : (response.contentLength ?? -1);
      int received = 0;
      
      final sink = file.openWrite();
      try {
        await for (final chunk in response.stream.timeout(const Duration(seconds: 15))) {
          if (isCancelled?.call() == true) throw Exception('Download cancelled');
          sink.add(chunk);
          received += chunk.length;
          if (total != -1 && onProgress != null) {
            onProgress(received / total);
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      print('Successfully finished single-threaded download: ${file.path}');
      return file.path;
    } else {
      throw Exception('Failed to download: HTTP Status Code ${response.statusCode}');
    }
  }

  /// Deletes local media files that are no longer referenced in the active playlist.
  Future<void> cleanUnusedFiles(List<MediaItem> activeItems) async {
    if (kIsWeb) return;

    try {
      final dir = await _mediaDirectory;
      final localFiles = dir.listSync();

      // Gather names of files that should remain in cache
      final Set<String> expectedFileNames = {};
      for (final item in activeItems) {
        if (item.localPath != null) {
          expectedFileNames.add(p.basename(item.localPath!));
        }
      }

      // Sweep media folder and delete unreferenced assets
      for (final entity in localFiles) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if (!expectedFileNames.contains(name)) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      print('Media cleanup error: $e');
    }
  }

  /// Helper to clear all media files in the folder (e.g. on unlinking).
  Future<void> clearAllCachedMedia() async {
    if (kIsWeb) return;

    try {
      final dir = await _mediaDirectory;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      print('Clear cached media error: $e');
    }
  }
}
