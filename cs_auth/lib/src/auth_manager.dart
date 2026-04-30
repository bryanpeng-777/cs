import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

import 'package:cs_core/cs_core.dart';

/// 用户认证管理器
///
/// 支持的登录方式：
/// - 匿名登录（用户主动选择「跳过」时调用）
/// - 邮箱密码注册 / 登录
/// - 匿名账号升级为邮箱账号（保留历史数据）
/// - 退出登录
/// - 密码重置（邮件 + URL Scheme 深链接）
class AuthManager {
  AuthManager._();

  static bool _initialized = false;

  static SupabaseClient get _supabase => CsClient.supabase;

  /// 当前用户（未登录时为 null）
  static User? get currentUser => _supabase.auth.currentUser;

  /// 当前用户 ID
  static String? get currentUserId => currentUser?.id;

  /// 是否已登录（包括匿名登录）
  static bool get isLoggedIn => currentUser != null;

  /// 是否为匿名用户
  static bool get isAnonymous => currentUser?.isAnonymous ?? false;

  /// 是否为已绑定邮箱的正式用户
  static bool get isEmailUser => isLoggedIn && !isAnonymous;

  /// 初始化：仅尝试恢复已有 session，不自动创建匿名账号
  ///
  /// 匿名登录由用户在 CsLoginPage 主动点「跳过」触发。
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (kDebugMode) {
      debugPrint(
        '[AuthManager] 初始化完成 '
        'userId=${currentUserId ?? 'none'} '
        'isAnonymous=$isAnonymous',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 匿名登录
  // ---------------------------------------------------------------------------

  /// 匿名登录（用户在登录页点「跳过」时调用）
  static Future<AuthResponse> signInAnonymously() async {
    final response = await _supabase.auth.signInAnonymously();
    if (response.user != null) {
      await _upsertBusinessUser(response.user!);
    }
    if (kDebugMode) {
      debugPrint('[AuthManager] 匿名登录成功 userId=${response.user?.id}');
    }
    return response;
  }

  // ---------------------------------------------------------------------------
  // 邮箱注册 / 登录
  // ---------------------------------------------------------------------------

  /// 邮箱密码注册
  static Future<AuthResponse> signUpWithEmail(
    String email,
    String password,
  ) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: CsClient.config.emailConfirmRedirectUrl,
    );
    if (response.user != null) {
      await _upsertBusinessUser(response.user!);
    }
    return response;
  }

  /// 验证邮箱 OTP（注册后确认邮箱）
  static Future<AuthResponse> verifyEmailOtp(
    String email,
    String token,
  ) async {
    final response = await _supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.signup,
    );
    if (response.user != null) {
      await _upsertBusinessUser(response.user!);
    }
    return response;
  }

  /// 邮箱密码登录
  static Future<AuthResponse> signInWithEmail(
    String email,
    String password,
  ) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user != null) {
      await _upsertBusinessUser(response.user!);
    }
    return response;
  }

  // ---------------------------------------------------------------------------
  // 匿名账号升级
  // ---------------------------------------------------------------------------

  /// 将匿名账号升级为邮箱账号（保留历史数据）
  static Future<UserResponse> linkWithEmail(
    String email,
    String password,
  ) async {
    final response = await _supabase.auth.updateUser(
      UserAttributes(email: email, password: password),
    );
    if (kDebugMode) {
      debugPrint('[AuthManager] 匿名账号已升级为邮箱账号 email=$email');
    }
    return response;
  }

  // ---------------------------------------------------------------------------
  // 密码重置
  // ---------------------------------------------------------------------------

  /// 发送密码重置邮件
  static Future<void> sendPasswordResetEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: CsClient.config.passwordResetRedirectUrl,
    );
    if (kDebugMode) {
      debugPrint('[AuthManager] 密码重置邮件已发送 email=$email');
    }
  }

  /// 验证密码重置 OTP
  static Future<AuthResponse> verifyRecoveryOtp(
    String email,
    String token,
  ) async {
    return _supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.recovery,
    );
  }

  /// 设置新密码（用户通过深链接或 OTP 验证后调用）
  static Future<UserResponse> updatePassword(String newPassword) async {
    return _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // ---------------------------------------------------------------------------
  // 退出登录
  // ---------------------------------------------------------------------------

  /// 退出登录
  static Future<void> signOut() async {
    await _supabase.auth.signOut();
    if (kDebugMode) {
      debugPrint('[AuthManager] 已退出登录');
    }
  }

  // ---------------------------------------------------------------------------
  // 工具方法
  // ---------------------------------------------------------------------------

  /// 监听认证状态变化
  static Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  /// 获取设备唯一 ID（用于 devices 表注册）
  static Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return info.identifierForVendor ?? const Uuid().v4();
      } else if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return info.id;
      }
    } catch (_) {}
    return const Uuid().v4();
  }

  /// 在 business.users 表中同步用户记录
  static Future<void> _upsertBusinessUser(User user) async {
    try {
      await _supabase.schema('business').from('users').upsert({
        'id': user.id,
        'app_id': CsClient.config.appId,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthManager] upsert business.users 跳过: $e');
      }
    }
  }
}
