import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth/auth_manager.dart';
import 'config/config_manager.dart';
import 'data/data_manager.dart';
import 'notifications/push_manager.dart';
import 'storage/storage_manager.dart';
import 'payment/payment_manager.dart';
import 'ads/ad_manager.dart';

/// 运行环境
enum CsEnvironment { dev, staging, prod }

/// cs_framework 全局配置
class CsConfig {
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String appId;
  final CsEnvironment environment;
  final String locale;

  /// App 的 URL Scheme，用于密码重置深链接唤起
  /// 命名规则：mountain + appId（全小写），例如 appId=demo → mountaindemo
  final String urlScheme;

  /// RevenueCat iOS API Key（传入后自动启用支付模块）
  ///
  /// 在 RevenueCat 后台「App Settings → API Keys」中获取（以 appl_ 开头）
  final String? revenueCatIosApiKey;

  /// RevenueCat Android API Key（传入后自动启用支付模块）
  ///
  /// 在 RevenueCat 后台「App Settings → API Keys」中获取（以 goog_ 开头）
  final String? revenueCatAndroidApiKey;

  /// AdMob 应用 ID（iOS，传入后自动启用广告模块）
  ///
  /// 在 AdMob 后台「应用 → 应用设置」中获取（格式：ca-app-pub-xxx~xxx）
  /// 注意：还需在 Info.plist 中配置 GADApplicationIdentifier，此处仅用于框架初始化标识
  final String? adMobIosAppId;

  /// AdMob 应用 ID（Android，传入后自动启用广告模块）
  ///
  /// 还需在 AndroidManifest.xml 中配置 com.google.android.gms.ads.APPLICATION_ID
  final String? adMobAndroidAppId;

  /// AdMob 测试设备 ID 列表（开发期使用，防止产生无效广告点击）
  final List<String> adMobTestDeviceIds;

  const CsConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.appId,
    this.environment = CsEnvironment.prod,
    this.locale = 'all',
    String? urlScheme,
    this.revenueCatIosApiKey,
    this.revenueCatAndroidApiKey,
    this.adMobIosAppId,
    this.adMobAndroidAppId,
    this.adMobTestDeviceIds = const [],
  }) : urlScheme = urlScheme ?? 'mountain$appId';

  /// 是否配置了支付模块
  bool get hasPaymentConfig =>
      revenueCatIosApiKey != null || revenueCatAndroidApiKey != null;

  /// 是否配置了广告模块
  bool get hasAdConfig => adMobIosAppId != null || adMobAndroidAppId != null;

  String get environmentName => environment.name;

  /// 邮箱注册确认后的深链接回调地址
  /// 用户点击确认邮件 → Supabase 验证 token → 唤起 App 并交换 session
  String get emailConfirmRedirectUrl => '$urlScheme://email-confirm';

  /// 密码重置后的深链接回调地址
  String get passwordResetRedirectUrl => '$urlScheme://reset-password';
}

/// cs_framework 主入口
/// 负责初始化所有子模块，业务项目只需调用一次 [initialize]
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

  /// 初始化框架，在 main() 中 runApp 之前调用
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
    bool enablePushNotifications = true,
    String? urlScheme,
    // 支付模块（RevenueCat）：传入 Key 自动启用
    String? revenueCatIosApiKey,
    String? revenueCatAndroidApiKey,
    // 广告模块（AdMob）：传入 App ID 自动启用
    String? adMobIosAppId,
    String? adMobAndroidAppId,
    List<String> adMobTestDeviceIds = const [],
  }) async {
    if (_initialized) return;

    _config = CsConfig(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      appId: appId,
      environment: environment,
      locale: locale,
      urlScheme: urlScheme,
      revenueCatIosApiKey: revenueCatIosApiKey,
      revenueCatAndroidApiKey: revenueCatAndroidApiKey,
      adMobIosAppId: adMobIosAppId,
      adMobAndroidAppId: adMobAndroidAppId,
      adMobTestDeviceIds: adMobTestDeviceIds,
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

    // 初始化各子模块（顺序不可颠倒）
    // AuthManager 只恢复已有 session，不自动创建匿名账号
    // 匿名登录由用户在登录页主动点「跳过」触发
    await AuthManager.initialize();
    await ConfigManager.initialize();
    await DataManager.initialize();
    await StorageManager.initialize();

    if (enablePushNotifications) {
      try {
        await Firebase.initializeApp();
        await PushManager.initialize();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[CsClient] Firebase 初始化失败，跳过推送注册: $e');
        }
      }
    }

    // 支付模块（RevenueCat）：有 Key 时自动启用
    if (_config!.hasPaymentConfig) {
      try {
        await PaymentManager.useRevenueCat(
          iosApiKey: revenueCatIosApiKey,
          androidApiKey: revenueCatAndroidApiKey,
        );
        // 如果用户已登录，立即绑定购买记录
        final userId = AuthManager.currentUserId;
        if (userId != null) {
          await PaymentManager.setUserId(userId);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[CsClient] RevenueCat 初始化失败，跳过支付模块: $e');
        }
      }
    }

    // 广告模块（AdMob）：有 App ID 时自动启用
    if (_config!.hasAdConfig) {
      try {
        await AdManager.useAdMob(
          testDeviceIds:
              adMobTestDeviceIds.isNotEmpty ? adMobTestDeviceIds : null,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[CsClient] AdMob 初始化失败，跳过广告模块: $e');
        }
      }
    }

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

    // 清空缓存，重新从新环境拉取
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
