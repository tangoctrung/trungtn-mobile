import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:flutter_demo/features/auth/device_auth_service.dart';
import 'package:flutter_demo/features/auth/lock_session.dart';
import 'package:flutter_demo/features/discover/discover_models.dart';
import 'package:flutter_demo/features/discover/discover_widgets.dart';
import 'package:flutter_demo/features/discover/news_article_screen.dart';
import 'package:flutter_demo/main.dart';

final _post = NewsPost(
  title: 'Bài báo trong ứng dụng',
  summary: 'Nội dung tin tức',
  url: Uri.parse('https://vnexpress.net/tin-moi-123.html'),
  category: NewsCategory.domestic,
);

class _Authenticator implements DeviceAuthenticator {
  bool succeed = true;
  @override
  Future<bool> authenticate() async => succeed;
}

class _WebPlatform extends WebViewPlatform {
  late _WebController controller;
  late _WebDelegate delegate;
  int creations = 0;
  bool failInitialization = false;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    if (failInitialization) throw StateError('Native view unavailable');
    creations++;
    return controller = _WebController(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => delegate = _WebDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _WebWidget(params);
}

class _WebController extends PlatformWebViewController {
  _WebController(super.params) : super.implementation();

  late _WebDelegate delegate;
  final history = <Uri>[];
  final scripts = <String>[];
  int reloads = 0;

  void finish() {
    final url = history.last.toString();
    delegate.started(url);
    delegate.progress(100);
    delegate.finished(url);
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    history.add(params.uri);
    finish();
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}
  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async => delegate = handler as _WebDelegate;
  @override
  Future<bool> canGoBack() async => history.length > 1;
  @override
  Future<void> goBack() async {
    history.removeLast();
    finish();
  }

  @override
  Future<void> reload() async {
    reloads++;
    finish();
  }

  @override
  Future<void> runJavaScript(String javaScript) async =>
      scripts.add(javaScript);
}

class _WebDelegate extends PlatformNavigationDelegate {
  _WebDelegate(super.params) : super.implementation();
  late NavigationRequestCallback navigation;
  late PageEventCallback started;
  late PageEventCallback finished;
  late ProgressCallback progress;
  late WebResourceErrorCallback error;
  late HttpResponseErrorCallback httpError;

  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback value) async =>
      navigation = value;
  @override
  Future<void> setOnPageStarted(PageEventCallback value) async =>
      started = value;
  @override
  Future<void> setOnPageFinished(PageEventCallback value) async =>
      finished = value;
  @override
  Future<void> setOnProgress(ProgressCallback value) async => progress = value;
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback value) async =>
      error = value;
  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback value) async =>
      httpError = value;
  @override
  Future<void> setOnUrlChange(UrlChangeCallback value) async {}
}

class _WebWidget extends PlatformWebViewWidget {
  _WebWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.expand(
    child: ColoredBox(color: Colors.white, child: Text('Nội dung trang báo')),
  );
}

void main() {
  late _WebPlatform platform;
  late _Authenticator authenticator;
  late LockSessionController session;
  late ScrollController scroll;
  final previousPlatform = WebViewPlatform.instance;

  setUp(() {
    platform = _WebPlatform();
    WebViewPlatform.instance = platform;
    authenticator = _Authenticator();
    session = LockSessionController(store: MemoryLockSessionStore());
    scroll = ScrollController();
  });
  tearDown(() {
    WebViewPlatform.instance = previousPlatform ?? _WebPlatform();
    session.dispose();
    scroll.dispose();
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(
        authenticator: authenticator,
        sessionController: session,
        homeBuilder: (_) => Scaffold(
          body: ListView(
            controller: scroll,
            children: [
              const SizedBox(height: 900),
              NewsPostCard(post: _post),
              const SizedBox(height: 900),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    scroll.jumpTo(900);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NewsPostCard));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'News card opens original page inside protected app and keeps list position',
    (tester) async {
      await mount(tester);
      expect(find.byType(NewsArticleScreen), findsOneWidget);
      expect(find.byKey(const Key('news-webview')), findsOneWidget);
      expect(platform.controller.history, [_post.url]);
      expect(find.text('vnexpress.net'), findsOneWidget);
      expect(find.byKey(const Key('article-progress')), findsNothing);
      await tester.tap(find.byKey(const Key('article-close')));
      await tester.pumpAndSettle();
      expect(find.byType(NewsArticleScreen), findsNothing);
      expect(scroll.offset, 900);
      expect(find.byType(NewsPostCard), findsOneWidget);
    },
  );

  testWidgets(
    'Web links stay inside app; Back uses page history then edge swipe returns to list',
    (tester) async {
      await mount(tester);
      final next = Uri.parse('https://vnexpress.net/tin-khac-456.html');
      expect(
        await platform.delegate.navigation(
          NavigationRequest(url: next.toString(), isMainFrame: true),
        ),
        NavigationDecision.navigate,
      );
      expect(
        await platform.delegate.navigation(
          const NavigationRequest(
            url: 'intent://external-app',
            isMainFrame: true,
          ),
        ),
        NavigationDecision.prevent,
      );
      await platform.controller.loadRequest(LoadRequestParams(uri: next));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(platform.controller.history, [_post.url]);
      expect(find.byType(NewsArticleScreen), findsOneWidget);
      await tester.flingFrom(const Offset(6, 250), const Offset(240, 0), 900);
      await tester.pumpAndSettle();
      expect(find.byType(NewsArticleScreen), findsNothing);
    },
  );

  testWidgets(
    'Only main article failures show retry; retry reloads inside app',
    (tester) async {
      await mount(tester);
      platform.delegate.error(
        const WebResourceError(
          errorCode: -2,
          description: 'Advertisement failed',
          isForMainFrame: false,
        ),
      );
      platform.delegate.httpError(
        HttpResponseError(
          request: WebResourceRequest(
            uri: Uri.parse('https://ads.example/image'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('article-retry')), findsNothing);
      platform.delegate.error(
        const WebResourceError(
          errorCode: -2,
          description: 'Offline',
          isForMainFrame: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('article-retry')), findsOneWidget);
      await tester.tap(find.byKey(const Key('article-retry')));
      await tester.pumpAndSettle();
      expect(platform.controller.reloads, 1);
      expect(find.byKey(const Key('article-retry')), findsNothing);
      platform.delegate.httpError(
        HttpResponseError(request: WebResourceRequest(uri: _post.url)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('article-retry')), findsOneWidget);
    },
  );

  testWidgets(
    'Progress is visible while loading and toolbar fits a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await mount(tester);
      platform.delegate.started(_post.url.toString());
      platform.delegate.progress(45);
      await tester.pump();
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const Key('article-progress')),
            )
            .value,
        .45,
      );
      expect(tester.takeException(), isNull);
      platform.delegate.finished(_post.url.toString());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('article-progress')), findsNothing);
    },
  );

  testWidgets(
    'Native initialization failure allows retry without leaving app',
    (tester) async {
      platform.failInitialization = true;
      await mount(tester);
      expect(find.byKey(const Key('article-retry')), findsOneWidget);
      platform.failInitialization = false;
      await tester.tap(find.byKey(const Key('article-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('news-webview')), findsOneWidget);
      expect(platform.controller.history, [_post.url]);
    },
  );

  testWidgets(
    'Lock hides article and pauses media; unlocking preserves the same page',
    (tester) async {
      await mount(tester);
      final controller = platform.controller;
      authenticator.succeed = false;
      session.lock(reason: SessionLockReason.expired);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('news-webview')), findsNothing);
      expect(find.text('Xác thực thất bại'), findsOneWidget);
      expect(
        controller.scripts.any((script) => script.contains('m.pause()')),
        isTrue,
      );
      authenticator.succeed = true;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('news-webview')), findsOneWidget);
      expect(platform.creations, 1);
      expect(platform.controller, same(controller));
      expect(controller.history, [_post.url]);
    },
  );
}
