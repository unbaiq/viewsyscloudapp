import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/media_item.dart';
import '../../providers/zone_content_provider.dart';
import '../../services/zone_content_service.dart';
import '../../widgets/video_player_widget.dart';
import '../../widgets/shimmer_placeholder.dart';

class HalfSplitLayout extends ConsumerStatefulWidget {
  final Widget baseMediaSurface;

  const HalfSplitLayout({
    super.key,
    required this.baseMediaSurface,
  });

  @override
  ConsumerState<HalfSplitLayout> createState() => _HalfSplitLayoutState();
}

class _HalfSplitLayoutState extends ConsumerState<HalfSplitLayout> {
  @override
  void initState() {
    super.initState();
    ZoneContentService.instance.start(ref);
  }

  @override
  void dispose() {
    ZoneContentService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zoneState = ref.watch(zoneContentProvider);

    return Row(
      children: [
        // LEFT ZONE (50%): Existing base media surface
        Expanded(
          flex: 1,
          child: widget.baseMediaSurface,
        ),
        
        // Divider (optional, but good for visual separation)
        Container(
          width: 2,
          color: Colors.white.withOpacity(0.1),
        ),

        // RIGHT ZONE (50%): New independent content area
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.black,
            child: _buildRightZoneContent(zoneState),
          ),
        ),
      ],
    );
  }

  Widget _buildRightZoneContent(ZoneContentState state) {
    if (state.isLoading) {
      return const Center(child: ShimmerPlaceholder());
    }

    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(
              'Failed to load zone content',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (state.item == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined, color: Colors.white24, size: 40),
            SizedBox(height: 12),
            Text(
              'No content configured',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return _buildMediaView(state.item!);
  }

  Widget _buildMediaView(MediaItem item) {
    if (item.type == 'video') {
      return VideoPlayerWidget(
        key: ValueKey('zone_video_${item.id}'),
        item: item,
        forceLoop: true,
        onComplete: () {
          // Loop the video until new content is fetched
        },
      );
    } else {
      return _buildImageView(item);
    }
  }

  Widget _buildImageView(MediaItem item) {
    final fileExists = item.localPath != null &&
        item.localPath!.isNotEmpty &&
        !kIsWeb &&
        File(item.localPath!).existsSync() &&
        File(item.localPath!).lengthSync() > 0;

    if (!fileExists) {
      return Image.network(
        item.url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) =>
            _buildErrorPlaceholder('Image failed to stream'),
      );
    }

    return Image.file(
      File(item.localPath!),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) =>
          _buildErrorPlaceholder('Cached image failed to read'),
    );
  }

  Widget _buildErrorPlaceholder(String error) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(
              error,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
