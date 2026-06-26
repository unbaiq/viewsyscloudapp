import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/zone_content_provider.dart';
import '../../services/zone_content_service.dart';
import '../../widgets/zone_media_viewer.dart';

class FourGridLayout extends ConsumerStatefulWidget {
  final Widget baseMediaSurface;
  final String? topRightUrl;
  final String? bottomLeftUrl;
  final String? bottomRightUrl;

  const FourGridLayout({
    super.key,
    required this.baseMediaSurface,
    this.topRightUrl,
    this.bottomLeftUrl,
    this.bottomRightUrl,
  });

  @override
  ConsumerState<FourGridLayout> createState() => _FourGridLayoutState();
}

class _FourGridLayoutState extends ConsumerState<FourGridLayout> {
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
    return Column(
      children: [
        // TOP ROW
        Expanded(
          flex: 1,
          child: Row(
            children: [
              // TOP-LEFT: Existing base media surface
              Expanded(
                flex: 1,
                child: widget.baseMediaSurface,
              ),
              // TOP-RIGHT: Independent API Media
              Expanded(
                flex: 1,
                child: Container(
                  color: Colors.black,
                  child: ZoneMediaViewer(provider: topRightZoneProvider),
                ),
              ),
            ],
          ),
        ),
        // BOTTOM ROW
        Expanded(
          flex: 1,
          child: Row(
            children: [
              // BOTTOM-LEFT: Independent API Media
              Expanded(
                flex: 1,
                child: Container(
                  color: Colors.black,
                  child: ZoneMediaViewer(provider: bottomLeftZoneProvider),
                ),
              ),
              // BOTTOM-RIGHT: Independent API Media
              Expanded(
                flex: 1,
                child: Container(
                  color: Colors.black,
                  child: ZoneMediaViewer(provider: bottomRightZoneProvider),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
