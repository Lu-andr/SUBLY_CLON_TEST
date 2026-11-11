import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
        Expanded(child: WebViewWidget(controller: controller)),
      ],
    ),
  );
}
