import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'shimmer_placeholder.dart';

class CmsWebviewPanel extends StatefulWidget {
  final String? url;

  const CmsWebviewPanel({super.key, required this.url});

  @override
  State<CmsWebviewPanel> createState() => _CmsWebviewPanelState();
}

class _CmsWebviewPanelState extends State<CmsWebviewPanel> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  @override
  void didUpdateWidget(CmsWebviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) {
      _loadUrl();
    }
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            _retryTimer?.cancel();
          },
          onWebResourceError: (WebResourceError error) {
            print('WebView resource error: ${error.description}');
            _handleError();
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      );
    _loadUrl();
  }

  void _loadUrl() {
    _retryTimer?.cancel();
    if (widget.url == null || widget.url!.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final uri = Uri.parse(widget.url!);
      _controller.loadRequest(uri);
    } catch (e) {
      print('Invalid WebView URL: ${widget.url}');
      _handleError();
    }
  }

  void _handleError() {
    if (mounted) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
    // Unattended kiosk behavior: retry automatically
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 60), () {
      if (mounted) {
        _loadUrl();
      }
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, color: Colors.white54, size: 48),
            SizedBox(height: 16),
            Text(
              'Sidebar Content Unavailable',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Positioned.fill(
            child: ShimmerPlaceholder(),
          ),
      ],
    );
  }
}
