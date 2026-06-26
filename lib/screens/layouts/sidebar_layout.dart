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
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            child: ZoneMediaViewer(
              provider: zoneContentProvider,
              fallbackUrl: widget.sidebarUrl,
            ),
          ),
        ),
      ],
    );
  }
}
