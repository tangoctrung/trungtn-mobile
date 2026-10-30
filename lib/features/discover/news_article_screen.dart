import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../shared/edge_back_gesture.dart';
import '../../shared/ui.dart';
import 'discover_models.dart';

Future<void> openNewsArticle(BuildContext context, NewsPost post) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => NewsArticleScreen(post: post)),
    );

class NewsArticleScreen extends StatefulWidget {
  const NewsArticleScreen({super.key, required this.post});

  final NewsPost post;

  @override
  State<NewsArticleScreen> createState() => _NewsArticleScreenState();
}

class _NewsArticleScreenState extends State<NewsArticleScreen>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  late Uri _url = widget.post.url;
  int _progress = 0;
  bool _failed = false;
  bool _canGoBack = false;
  bool _initializing = false;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    if (_initializing) return;
    _initializing = true;
    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.white);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            return uri != null &&
                    (uri.scheme == 'https' || uri.scheme == 'http')
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _url = Uri.tryParse(url) ?? _url;
              _progress = 0;
              _failed = false;
            });
            unawaited(_updateHistory());
          },
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _progress = 100);
            unawaited(_updateHistory());
            if (!_visible) unawaited(_pauseMedia());
          },
          onUrlChange: (_) => unawaited(_updateHistory()),
          onWebResourceError: (error) {
            // Failed advertisements/images must not hide a readable article.
            if (error.isForMainFrame == true) _showError();
          },
          onHttpError: (error) {
            if (error.request?.uri == _url) _showError();
          },
        ),
      );
      if (!mounted) return;
      setState(() => _controller = controller);
      await controller.loadRequest(widget.post.url);
    } catch (_) {
      _showError();
    } finally {
      _initializing = false;
    }
  }

  void _showError() {
    if (mounted) setState(() => _failed = true);
  }

  Future<void> _updateHistory() async {
    try {
      final canGoBack = await _controller?.canGoBack() ?? false;
      if (mounted) setState(() => _canGoBack = canGoBack);
    } catch (_) {
      // The native view may already be closing.
    }
  }

  Future<void> _back() async {
    final controller = _controller;
    if (controller != null) {
      try {
        if (await controller.canGoBack()) {
          await controller.goBack();
          await _updateHistory();
          return;
        }
      } catch (_) {
        // A failed WebView must still allow returning to the news list.
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _reload() async {
    setState(() {
      _failed = false;
      _progress = 0;
    });
    if (_controller == null) {
      await _initialize();
      return;
    }
    try {
      await _controller!.reload();
    } catch (_) {
      _showError();
    }
  }

  Future<void> _pauseMedia() async {
    try {
      await _controller?.runJavaScript(
        "document.querySelectorAll('video,audio').forEach(m => m.pause());",
      );
    } catch (_) {
      // A page that has not loaded yet has no media to pause.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The protected Navigator stays mounted while the app is locked.
    _visible = TickerMode.valuesOf(context).enabled;
    if (!_visible) unawaited(_pauseMedia());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_pauseMedia());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_pauseMedia());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_canGoBack,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_back());
    },
    child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('article-back'),
          tooltip: 'Quay lại',
          onPressed: _back,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.post.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              _url.host,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            key: const Key('article-close'),
            tooltip: 'Đóng bài viết',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            if (_controller != null)
              WebViewWidget(
                key: const Key('news-webview'),
                controller: _controller!,
              ),
            if (_failed)
              Positioned.fill(
                child: ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Center(
                    child: EmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: 'Chưa tải được bài viết',
                      message: 'Kiểm tra kết nối mạng rồi thử lại.',
                      action: FilledButton.icon(
                        key: const Key('article-retry'),
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Thử lại'),
                      ),
                    ),
                  ),
                ),
              ),
            if (!_failed && _progress < 100)
              LinearProgressIndicator(
                key: const Key('article-progress'),
                minHeight: 2,
                value: _progress == 0 ? null : _progress / 100,
              ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 24 + MediaQuery.paddingOf(context).left,
              child: EdgeBackGesture(
                onBack: _back,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
