import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebviewPage extends StatefulWidget {
  final String url;
  const WebviewPage({super.key, required this.url});

  @override
  State<WebviewPage> createState() => _WebviewPageState();
}

class _WebviewPageState extends State<WebviewPage> {
  InAppWebViewController? webViewController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Download Page"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.url)),
          onWebViewCreated: (controller) {
            webViewController = controller;
          },
          onLoadStop: (controller, url) async {
            String query = """
              var paragraphTag = document.querySelector('p[class="mb-4 text-xl font-bold"]');
              if (paragraphTag && paragraphTag.querySelector('a')) {
                var anchorTagHref = paragraphTag.querySelector('a').href; 
                anchorTagHref;
              } else {
                null;
              }
            """;

            String? mirrorLink = await webViewController?.evaluateJavascript(source: query);
            if (mirrorLink != null && mirrorLink.isNotEmpty && mirrorLink != "null") {
              Future.delayed(const Duration(milliseconds: 100), () {
                Navigator.pop(context, mirrorLink);
              });
            }
          },
        ),
      ),
    );
  }
}