/// cs_auth_ui — CS 框架登录 UI 组件
///
/// 提供：
/// - [CsLoginPage]：开箱即用的完整登录页（邮箱登录/注册/跳过）
/// - [CsForgotPasswordPage]：忘记密码页
/// - [CsResetPasswordPage]：重置密码页
/// - [CsLoginForm]：可嵌入任意页面的登录/注册表单积木
///
/// 依赖：cs_auth + cs_ui
library cs_auth_ui;

export 'src/cs_login_page.dart'
    show CsLoginPage, CsForgotPasswordPage, CsResetPasswordPage;
export 'src/cs_login_form.dart';
