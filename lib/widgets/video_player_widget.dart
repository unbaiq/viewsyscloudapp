import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/media_item.dart';
import '../providers/player_provider.dart';
import '../services/video_preload_manager.dart';

/// A wrapper widget to manage the lifecycle of a video controller safely.
class VideoPlayerWidget extends ConsumerStatefulWidget {
  final MediaItem item;
  final VoidCallback onComplete;
  final VoidCallback? onInitialized;

  const VideoPlayerWidget({
    super.key,
    required this.item,
    required this.onComplete,
    this.onInitialized,
  });

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  Timer? _fallbackTimer;
  bool _notifiedReady = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateLoopingState();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  void _updateLoopingState() {
    if (_controller == null || !_initialized) return;
    final playlistState = ref.read(playlistProvider);
    final items = playlistState.items;
    final now = DateTime.now();
    final validCount = items.where((item) => item.isValidNow(now, isOnline: playlistState.isOnline)).length;
    final shouldLoop = validCount <= 1;
    if (_controller!.value.isLooping != shouldLoop) {
      _controller!.setLooping(shouldLoop);
      print('[VideoPlayerWidget] Dynamic looping updated to: $shouldLoop');
    }
  }

  Future<void> _initVideo() async {
    try {
      final preloaded = VideoPreloadManager.instance.getAndRemove(widget.item.id);

      if (preloaded != null) {
        _controller = preloaded;
        _controller!.addListener(_videoListener);

        if (mounted) {
          setState(() {
            _initialized = _controller!.value.isInitialized;
          });

          if (!_controller!.value.isInitialized) {
            await _controller!.initialize();
            if (mounted) {
              setState(() {
                _initialized = true;
              });
            }
          }

          _updateLoopingState();
          _controller!.play();
        }
      } else {
        final fileExists = widget.item.localPath != null &&
            widget.item.localPath!.isNotEmpty &&
            !kIsWeb &&
            File(widget.item.localPath!).existsSync() &&
            File(widget.item.localPath!).lengthSync() > 0;

        final playlistState = ref.read(playlistProvider);

        if (!fileExists && !kIsWeb) {
          if (!playlistState.isOnline) {
            if (mounted) {
              setState(() {
                _hasError = true;
              });
            }
            return;
          }

          print('[VideoPlayerWidget] File not cached yet. Streaming from network: ${widget.item.url}');
          _controller = VideoPlayerController.networkUrl(Uri.parse(widget.item.url));
        } else {
          if (kIsWeb) {
            _controller = VideoPlayerController.networkUrl(Uri.parse(widget.item.url));
          } else {
            _controller = VideoPlayerController.file(File(widget.item.localPath!));
          }
        }

        _controller!.addListener(_videoListener);
        await _controller!.initialize();

        if (mounted) {
          setState(() {
            _initialized = true;
          });

          _updateLoopingState();
          _controller!.play();
        }
      }
    } catch (e) {
      print('Video controller initialization failure: $e');
      ref.read(playlistProvider.notifier).handleCorruptVideo(widget.item.id);

      if (mounted) {
        setState(() {
          _hasError = true;
        });
        // Sched fallback to automatically advance in 4 seconds if initialization fails
        _fallbackTimer = Timer(const Duration(seconds: 4), () {
          widget.onComplete();
        });
      }
    }
  }

  void _videoListener() {
    if (_controller == null || !mounted) return;

    if (_controller!.value.hasError) {
      print('Video playback error: ${_controller!.value.errorDescription}');
      ref.read(playlistProvider.notifier).handleCorruptVideo(widget.item.id);

      _controller!.removeListener(_videoListener);
      widget.onComplete();
      return;
    }

    // Trigger parent ready callback only after video starts rendering/playing frames
    if (!_notifiedReady &&
        _controller!.value.isInitialized &&
        _controller!.value.isPlaying &&
        _controller!.value.position.inMilliseconds > 0) {
      _notifiedReady = true;
      widget.onInitialized?.call();
    }

    // Advance index once video playout finishes (only if it is not looping)
    if (!_controller!.value.isLooping &&
        _controller!.value.isInitialized &&
        _controller!.value.isCompleted) {
      _controller!.removeListener(_videoListener);
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off_rounded, color: Colors.redAccent, size: 40),
              SizedBox(height: 12),
              Text('Video playout failed',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return const SizedBox.shrink();
    }

    // FittedBox correctly fills any rotated space while preserving aspect ratio
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}
