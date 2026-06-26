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
import '../../widgets/zone_media_viewer.dart';

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
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            child: ZoneMediaViewer(provider: zoneContentProvider),
          ),
        ),
      ],
    );
  }
}
