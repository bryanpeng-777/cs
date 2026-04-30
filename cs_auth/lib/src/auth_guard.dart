import 'auth_manager.dart';

/// go_router 路由守卫工具类
///
/// 提供可以直接挂到 `GoRouter.redirect` 或 `GoRoute.redirect` 的回调函数。
/// 由于 cs_auth 不依赖 go_router，此处将回调签名定义为通用 typedef，
/// 业务方将函数直接传给 `GoRouter(redirect: ...)` 即可。
///
/// ## 使用方式
///
/// ```dart
/// import 'package:go_router/go_router.dart';
/// import 'package:cs_auth/cs_auth.dart';
///
/// GoRouter(
///   redirect: AuthGuard.requireAnySession,
///   routes: [...],
/// )
/// ```
class AuthGuard {
  AuthGuard._();

  /// 要求实名（邮箱）账号的路由守卫
  ///
  /// 已绑定邮箱 → 放行（返回 null）
  /// 匿名或未登录 → 跳转 `/login?redirect=<原路径>`
  static String? requireEmailUser(dynamic context, dynamic state) {
    if (AuthManager.isEmailUser) return null;

    final uri = (state as dynamic).uri?.toString() ?? '/';
    return '/login?redirect=${Uri.encodeComponent(uri)}';
  }

  /// 未登录守卫（匿名用户视为已登录）
  ///
  /// 有任意 session（邮箱或匿名）→ 放行
  /// 完全无 session → 跳转 `/login`
  static String? requireAnySession(dynamic context, dynamic state) {
    if (AuthManager.isLoggedIn) return null;
    final uri = (state as dynamic).uri?.toString() ?? '/';
    return '/login?redirect=${Uri.encodeComponent(uri)}';
  }
}
