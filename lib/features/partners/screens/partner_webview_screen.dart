import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

const _useAndroidHybridComposition = bool.fromEnvironment(
  'OFFER_WEBVIEW_HYBRID_COMPOSITION',
  defaultValue: true,
);

class PartnerWebViewScreen extends StatefulWidget {
  const PartnerWebViewScreen({
    required this.title,
    required this.initialUrl,
    super.key,
  });
  final String title;
  final Uri initialUrl;
  @override
  State<PartnerWebViewScreen> createState() => _PartnerWebViewScreenState();
}

class _PartnerWebViewScreenState extends State<PartnerWebViewScreen> {
  late final WebViewController controller;
  int progress = 0;
  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) => setState(() => progress = value),
        ),
      )
      ..loadRequest(widget.initialUrl);
  }

  Widget _buildWebView() {
    final platform = controller.platform;
    if (!_useAndroidHybridComposition ||
        platform is! AndroidWebViewController) {
      return WebViewWidget(controller: controller);
    }
    final params = AndroidWebViewWidgetCreationParams(
      controller: platform,
      displayWithHybridComposition: true,
    );
    return WebViewWidget.fromPlatformCreationParams(params: params);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Column(
      children: [
        if (progress < 100)
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: const LinearGradient(
              colors: [Color(0xFF461091), Color(0xFFF020BD)],
            ).createShader,
            child: LinearProgressIndicator(
              value: progress / 100,
              color: Colors.white,
              backgroundColor: Colors.transparent,
            ),
          ),
        Expanded(child: _buildWebView()),
      ],
    ),
  );
}
