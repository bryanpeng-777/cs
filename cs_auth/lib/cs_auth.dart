/// cs_auth — CS 框架认证模块
///
/// 提供：
/// - [AuthManager]：用户认证管理器（匿名/邮箱登录、账号升级、密码重置）
/// - [AuthGuard]：go_router 路由守卫工具类
///
/// 依赖：cs_core
library cs_auth;

export 'src/auth_manager.dart';
export 'src/auth_guard.dart';
