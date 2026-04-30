import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'config/config_manager.dart';
import 'data/data_manager.dart';
import 'storage/storage_manager.dart';

/// 运行环境
enum CsEnvironment { dev, staging, prod }

/// cs_core 全局配置
class CsConfig {
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String appId;
  final CsEnvironment environment;
  final String locale;

  /// App 的 URL Scheme，用于密码重置深链接唤起
  /// 命名规则：mountain + appId（全小写），例如 appId=demo → mountaindemo
  final String urlScheme;

  const CsConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.appId,
    this.environment = CsEnvironment.prod,
    this.locale = 'all',
    String? urlScheme,
  }) : urlScheme = urlScheme ?? 'mountain$appId';

  String get environmentName => environment.name;

  /// 邮箱注册确认后的深链接回调地址
  String get emailConfirmRedirectUrl => '$urlScheme://email-confirm';

  /// 密码重置后的深链接回调地址
  String get passwordResetRedirectUrl => '$urlScheme://reset-password';
}

/// cs_core 主入口
/// 负责初始化核心子模块（Config / Data / Storage），业务项目只需调用一次 [initialize]
class CsClient {
  CsClient._();

  static CsConfig? _config;
  static bool _initialized = false;

  static CsConfig get config {
    assert(_config != null, 'CsClient.initialize() 未调用');
    return _config!;
  }

  static SupabaseClient get supabase => Supabase.instance.client;

  static bool get isInitialized => _initialized;

  /// 初始化框架核心模块，在 main() 中 runApp 之前调用
  ///
  /// ```dart
  /// await CsClient.initialize(
  ///   supabaseUrl: 'https://xxx.supabase.co',
  ///   supabaseAnonKey: 'your-anon-key',
  ///   appId: 'your-app-id',
  ///   environment: CsEnvironment.prod,
  /// );
  /// ```
  static Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String appId,
    CsEnvironment environment = CsEnvironment.prod,
    String locale = 'all',
    String? urlScheme,
  }) async {
    if (_initialized) return;

    _config = CsConfig(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      appId: appId,
      environment: environment,
      locale: locale,
      urlScheme: urlScheme,
    );

    // 初始化 Hive 本地缓存
    await Hive.initFlutter();

    // 初始化 Supabase（启用 PKCE 以支持密码重置深链接）
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    await ConfigManager.initialize();
    await DataManager.initialize();
    await StorageManager.initialize();

    _initialized = true;

    if (kDebugMode) {
      debugPrint('[CsClient] 初始化完成 appId=$appId env=${environment.name}');
    }
  }

  /// 运行时切换环境（dev ↔ prod），会清空本地缓存并重新同步
  static Future<void> switchEnvironment(CsEnvironment environment) async {
    if (_config == null) return;
    if (_config!.environment == environment) return;

    _config = CsConfig(
      supabaseUrl: _config!.supabaseUrl,
      supabaseAnonKey: _config!.supabaseAnonKey,
      appId: _config!.appId,
      environment: environment,
      locale: _config!.locale,
    );

    await ConfigManager.forceRefresh();

    if (kDebugMode) {
      debugPrint('[CsClient] 环境已切换为 ${environment.name}');
    }
  }

  /// 切换 locale（国际化场景下动态切换语言）
  static Future<void> setLocale(String locale) async {
    _config = CsConfig(
      supabaseUrl: _config!.supabaseUrl,
      supabaseAnonKey: _config!.supabaseAnonKey,
      appId: _config!.appId,
      environment: _config!.environment,
      locale: locale,
    );
    await ConfigManager.onLocaleChanged(locale);
  }

  /// 释放资源（通常不需要手动调用）
  static Future<void> dispose() async {
    await ConfigManager.dispose();
    await Hive.close();
    _initialized = false;
  }
}
