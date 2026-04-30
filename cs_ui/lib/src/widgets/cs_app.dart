import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../theme/cs_app_theme.dart';

/// cs_ui 顶层应用 Widget
///
/// 封装 [ShadApp.custom] + [MaterialApp]，同时支持 shadcn_ui 组件和
/// Material 组件（NavigationBar、Scaffold 等）混用。
///
/// **普通模式**（home 参数）：
/// ```dart
/// return CsApp(title: 'My App', home: const HomeScreen());
/// ```
///
/// **Router 模式**（配合 go_router）：
/// ```dart
/// return CsApp.router(title: 'My App', routerConfig: appRouter);
/// ```
///
/// 切换主题只需修改 [CsAppTheme.activeStyle]，无需改动此文件。
class CsApp extends StatelessWidget {
  const CsApp({
    super.key,
    this.title = '',
    this.home,
    this.routes = const {},
    this.navigatorKey,
    this.onGenerateRoute,
    this.routerConfig,
    this.themeMode = ThemeMode.light,
    this.debugShowCheckedModeBanner = true,
    this.builder,
    this.localizationsDelegates,
    this.supportedLocales = const [Locale('zh', 'CN'), Locale('en', 'US')],
  }) : _useRouter = false;

  const CsApp.router({
    super.key,
    this.title = '',
    required RouterConfig<Object> this.routerConfig,
    this.themeMode = ThemeMode.light,
    this.debugShowCheckedModeBanner = true,
    this.builder,
    this.localizationsDelegates,
    this.supportedLocales = const [Locale('zh', 'CN'), Locale('en', 'US')],
  })  : _useRouter = true,
        home = null,
        routes = const {},
        navigatorKey = null,
        onGenerateRoute = null;

  final String title;
  final Widget? home;
  final Map<String, WidgetBuilder> routes;
  final GlobalKey<NavigatorState>? navigatorKey;
  final RouteFactory? onGenerateRoute;
  final RouterConfig<Object>? routerConfig;
  final ThemeMode themeMode;
  final bool debugShowCheckedModeBanner;
  final TransitionBuilder? builder;
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;
  final Iterable<Locale> supportedLocales;
  final bool _useRouter;

  @override
  Widget build(BuildContext context) {
    return ShadApp.custom(
      themeMode: themeMode,
      theme: CsAppTheme.active,
      darkTheme: CsAppTheme.activeDark,
      appBuilder: (context) {
        final materialTheme = Theme.of(context);
        final locDelegates = [
          ...?localizationsDelegates,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ];
        final toasterBuilder = (BuildContext ctx, Widget? child) {
          Widget result = ShadToaster(child: child ?? const SizedBox.shrink());
          if (builder != null) result = builder!(ctx, result);
          return result;
        };

        if (_useRouter) {
          return MaterialApp.router(
            title: title,
            routerConfig: routerConfig,
            theme: materialTheme,
            darkTheme: materialTheme,
            themeMode: themeMode,
            debugShowCheckedModeBanner: debugShowCheckedModeBanner,
            localizationsDelegates: locDelegates,
            supportedLocales: supportedLocales,
            builder: toasterBuilder,
          );
        }

        return MaterialApp(
          title: title,
          navigatorKey: navigatorKey,
          theme: materialTheme,
          darkTheme: materialTheme,
          themeMode: themeMode,
          home: home,
          routes: routes,
          onGenerateRoute: onGenerateRoute,
          debugShowCheckedModeBanner: debugShowCheckedModeBanner,
          localizationsDelegates: locDelegates,
          supportedLocales: supportedLocales,
          builder: toasterBuilder,
        );
      },
    );
  }
}
