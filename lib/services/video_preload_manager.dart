import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';
import '../models/media_item.dart';

class VideoPreloadManager {
  VideoPreloadManager._();
  static final VideoPreloadManager instance = VideoPreloadManager._();

  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, Future<void>> _initFutures = {};

  /// Preloads a video controller for the given [item] only if it exists locally.
  Future<void> preload(MediaItem item) async {
    if (item.type != 'video') return;
    if (_controllers.containsKey(item.id)) {
      // Already preloaded or preloading
      return;
    }

    final fileExists = item.localPath != null &&
        item.localPath!.isNotEmpty &&
        !kIsWeb &&
        File(item.localPath!).existsSync() &&
        File(item.localPath!).lengthSync() > 0;

    // Only preload if the file is cached locally. Network preloading causes severe buffering
    // congestion and stutters the currently playing video.
    if (!fileExists) return;

    print('[VideoPreloadManager] Preloading video for item ${item.id}: ${item.localPath}');
    try {
      final controller = VideoPlayerController.file(File(item.localPath!));
      _controllers[item.id] = controller;
      
      final initFuture = controller.initialize().then((_) {
        print('[VideoPreloadManager] Preload successfully initialized for item ${item.id}');
      }).catchError((e) {
        print('[VideoPreloadManager] Preload initialization failed for item ${item.id}: $e');
        _controllers.remove(item.id);
        _initFutures.remove(item.id);
      });
      
      _initFutures[item.id] = initFuture;
      await initFuture;
    } catch (e) {
      print('[VideoPreloadManager] Error setting up preload for item ${item.id}: $e');
      _controllers.remove(item.id);
      _initFutures.remove(item.id);
    }
  }

  /// Gets a preloaded controller if available, and removes it from the cache
  /// so that the caller widget takes full ownership of it.
  VideoPlayerController? getAndRemove(int itemId) {
    _initFutures.remove(itemId);
    final controller = _controllers.remove(itemId);
    if (controller != null) {
      print('[VideoPreloadManager] Reusing preloaded controller for item $itemId');
    }
    return controller;
  }

  /// Disposes of any controllers that are no longer needed
  void keepOnly(List<int> itemIdsToKeep) {
    final toRemove = _controllers.keys.where((id) => !itemIdsToKeep.contains(id)).toList();
    for (final id in toRemove) {
      print('[VideoPreloadManager] Disposing preloaded controller for item $id');
      _initFutures.remove(id);
      final controller = _controllers.remove(id);
      controller?.dispose();
    }
  }

  /// Clears and disposes all preloaded controllers
  void clearAll() {
    print('[VideoPreloadManager] Clearing all preloaded controllers');
    _initFutures.clear();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
  }
}
