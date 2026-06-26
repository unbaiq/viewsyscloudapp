import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:viewsys/widgets/zone_media_viewer.dart';

import '../../models/media_item.dart';
import '../../providers/zone_content_provider.dart';
import '../../services/zone_content_service.dart';
import '../../widgets/video_player_widget.dart';
import '../../widgets/shimmer_placeholder.dart';
import '../../widgets/cms_webview_panel.dart';

class TripleLayout extends ConsumerStatefulWidget {
  final Widget baseMediaSurface;
  final String? centerUrl;
  final String? rightUrl;

  const TripleLayout({
    super.key,
    required this.baseMediaSurface,
    this.centerUrl,
    this.rightUrl,
  });

  @override
  ConsumerState<TripleLayout> createState() => _TripleLayoutState();
}

class _TripleLayoutState extends ConsumerState<TripleLayout> {
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
        // LEFT ZONE (1/3): Existing base media surface
        Expanded(
          flex: 1,
          child: widget.baseMediaSurface,
        ),
        
        // Divider
        Container(
          width: 2,
          color: Colors.white.withValues(alpha: 0.1),
        ),

        // CENTER ZONE (1/3): Schedule API Content with fallback
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.black,
            child: ZoneMediaViewer(
              provider: centerZoneProvider,
              fallbackUrl: widget.centerUrl,
            ),
          ),
        ),

        // Divider
        Container(
          width: 2,
          color: Colors.white.withValues(alpha: 0.1),
        ),

        // RIGHT ZONE (1/3): Schedule API Content with fallback
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.black,
            child: ZoneMediaViewer(
              provider: rightZoneProvider,
              fallbackUrl: widget.rightUrl,
            ),
          ),
        ),
      ],
    );
  }
}
