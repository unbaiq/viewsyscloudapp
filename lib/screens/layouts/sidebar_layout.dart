import 'package:flutter/material.dart';
import '../../widgets/cms_webview_panel.dart';

const int _flexLeft = 7;
const int _flexRight = 3;

class SidebarLayout extends StatelessWidget {
  final Widget baseMediaSurface;
  final String? sidebarUrl;

  const SidebarLayout({
    super.key,
    required this.baseMediaSurface,
    this.sidebarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // LEFT ZONE (~70%): Existing base media surface
        Expanded(
          flex: _flexLeft,
          child: baseMediaSurface,
        ),
        
        // Divider
        Container(
          width: 2,
          color: Colors.white.withOpacity(0.1),
        ),

        // RIGHT ZONE (~30%): Independent CMS WebView
        Expanded(
          flex: _flexRight,
          child: Container(
            color: Colors.black,
            child: CmsWebviewPanel(
              url: sidebarUrl,
            ),
          ),
        ),
      ],
    );
  }
}
