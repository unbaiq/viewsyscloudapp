import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/media_item.dart';
import '../../providers/zone_content_provider.dart';
import '../../services/zone_content_service.dart';
import '../../widgets/video_player_widget.dart';
import '../../widgets/shimmer_placeholder.dart';
import '../../widgets/cms_webview_panel.dart';

const int _flexLeft = 7;
const int _flexRight = 3;

class SidebarLayout extends ConsumerStatefulWidget {
  final Widget baseMediaSurface;
  final String? sidebarUrl;

  const SidebarLayout({
    super.key,
    required this.baseMediaSurface,
    this.sidebarUrl,
  });

  @override
  ConsumerState<SidebarLayout> createState() => _SidebarLayoutState();
}

class _SidebarLayoutState extends ConsumerState<SidebarLayout> {
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
        // LEFT ZONE (~70%): Existing base media surface
        Expanded(
          flex: _flexLeft,
          child: widget.baseMediaSurface,
        ),
        
        // Divider
        Container(
          width: 2,
          color: Colors.white.withValues(alpha: 0.1),
        ),

        // RIGHT ZONE (~30%): Schedule API content, with fallback to sidebarUrl
        Expanded(
          flex: _flexRight,
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

    if (state.errorMessage != null || state.item == null) {
      // Fallback to the webview panel using sidebarUrl if provided
      if (widget.sidebarUrl != null && widget.sidebarUrl!.isNotEmpty) {
        return CmsWebviewPanel(url: widget.sidebarUrl);
      }
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
        key: ValueKey('zone_video_${item.id}_${item.localPath ?? item.url}'),
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
    if (widget.sidebarUrl != null && widget.sidebarUrl!.isNotEmpty) {
      return CmsWebviewPanel(url: widget.sidebarUrl);
    }
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
