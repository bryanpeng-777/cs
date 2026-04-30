import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:cs_core/cs_core.dart';
import 'package:cs_auth/cs_auth.dart';

/// 推送通知管理器 - FCM token 注册 + 消息接收 + silent push 处理
class PushManager {
  PushManager._();

  static SupabaseClient get _supabase => CsClient.supabase;
  static CsConfig get _config => CsClient.config;

  static FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  /// 前台消息回调
  static void Function(RemoteMessage message)? onForegroundMessage;

  /// 通知点击回调
  static void Function(RemoteMessage message)? onNotificationTap;

  static Future<void> initialize() async {
    try {
      _fcm.app;
    } catch (_) {
      if (kDebugMode) {
        debugPrint('[PushManager] Firebase 未初始化，跳过推送注册');
      }
      return;
    }

    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      if (kDebugMode) {
        debugPrint('[PushManager] 用户拒绝通知权限');
      }
      return;
    }

    final token = await _fcm.getToken();
    if (token != null) {
      await _registerDevice(token);
    }

    _fcm.onTokenRefresh.listen(_registerDevice);

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    if (kDebugMode) {
      debugPrint('[PushManager] 初始化完成 token=${token?.substring(0, 20)}...');
    }
  }

  /// 注册设备到 Supabase devices 表
  static Future<void> _registerDevice(String fcmToken) async {
    try {
      final deviceId = await AuthManager.getDeviceId();
      final packageInfo = await PackageInfo.fromPlatform();

      await _supabase.from('devices').upsert({
        'app_id': _config.appId,
        'device_id': deviceId,
        'fcm_token': fcmToken,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'app_version': packageInfo.version,
        'locale': _config.locale,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'app_id,device_id');

      if (kDebugMode) {
        debugPrint('[PushManager] 设备注册成功 deviceId=$deviceId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PushManager] 设备注册失败: $e');
      }
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[PushManager] 收到前台消息: ${message.data}');
    }

    if (message.data['type'] == 'config_sync') {
      ConfigManager.forceRefresh();
      return;
    }

    onForegroundMessage?.call(message);
  }

  static void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[PushManager] 通知被点击: ${message.data}');
    }
    onNotificationTap?.call(message);
  }

  /// 获取当前设备的 FCM token
  static Future<String?> getToken() => _fcm.getToken();
}
