import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:cs_auth/cs_auth.dart';
import 'package:cs_core/cs_core.dart';

import 'cs_login_form.dart';
import '../widgets/cs_app_bar.dart';

/// 开箱即用的完整登录页
///
/// 当 App 启动时无 session，自动显示此页。
/// 支持：邮箱登录 / 注册 / 跳过（匿名使用）
///
/// ## 使用示例（go_router）
///
/// ```dart
/// GoRouter(
///   initialLocation: '/',
///   redirect: (context, state) {
///     final needsLogin = !AuthManager.isLoggedIn && state.uri.path != '/login';
///     return needsLogin ? '/login' : null;
///   },
///   routes: [
///     GoRoute(
///       path: '/login',
///       builder: (_, state) => CsLoginPage(
///         onLoginSuccess: () => context.go('/home'),
///         onSkip: () => context.go('/home'),
///         redirectPath: state.uri.queryParameters['redirect'],
///       ),
///     ),
///     GoRoute(path: '/home', builder: ...),
///   ],
/// )
/// ```
///
/// ## 自定义外观
///
/// ```dart
/// CsLoginPage(
///   logo: Image.asset('assets/logo.png', height: 80),
///   title: '欢迎来到 MyApp',
///   subtitle: '登录后享受完整功能',
///   showSkipButton: true,
///   onLoginSuccess: () => context.go('/home'),
/// )
/// ```
class CsLoginPage extends StatefulWidget {
  const CsLoginPage({
    super.key,
    this.logo,
    this.title,
    this.subtitle,
    this.showSkipButton = true,
    this.continueOnSkipFailure = false,
    this.onLoginSuccess,
    this.onSkip,
    this.onForgotPassword,
    this.redirectPath,
  });

  /// 自定义 logo Widget（默认显示 App 名称文字）
  final Widget? logo;

  /// 页面标题（默认「登录」）
  final String? title;

  /// 副标题（默认显示框架描述）
  final String? subtitle;

  /// 是否显示「跳过」按钮（匿名使用），默认 true
  final bool showSkipButton;

  /// 匿名登录失败时是否仍触发 [onSkip]（由业务层决定是否以游客模式继续）
  final bool continueOnSkipFailure;

  /// 登录/注册成功后的回调
  final VoidCallback? onLoginSuccess;

  /// 点击「跳过」后的回调（完成匿名登录后触发）
  final VoidCallback? onSkip;

  /// 自定义忘记密码跳转（不传则使用框架内置流程）
  final VoidCallback? onForgotPassword;

  /// 登录成功后跳回的路径（从 URL 参数 redirect 读取）
  final String? redirectPath;

  @override
  State<CsLoginPage> createState() => _CsLoginPageState();
}

class _CsLoginPageState extends State<CsLoginPage> {
  CsLoginFormMode _mode = CsLoginFormMode.login;
  bool _skipping = false;

  Future<void> _handleSkip() async {
    setState(() => _skipping = true);
    try {
      await AuthManager.signInAnonymously();
      widget.onSkip?.call();
    } catch (e) {
      if (widget.continueOnSkipFailure) {
        widget.onSkip?.call();
      } else if (mounted) {
        ShadToaster.of(context).show(
          const ShadToast.destructive(
            title: Text('跳过失败'),
            description: Text('网络异常，请稍后重试'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _skipping = false);
    }
  }

  void _handleForgotPassword() {
    if (widget.onForgotPassword != null) {
      widget.onForgotPassword!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CsForgotPasswordPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              // Logo 区域
              Center(
                child: widget.logo ??
                    Text(
                      widget.title ?? '登录',
                      style: shadTheme.textTheme.h1,
                    ),
              ),
              const SizedBox(height: 12),

              // 副标题
              if (widget.subtitle != null || widget.logo != null)
                Center(
                  child: Text(
                    widget.subtitle ?? (widget.logo != null ? widget.title ?? '登录' : ''),
                    style: TextStyle(
                      fontSize: 15,
                      color: shadTheme.colorScheme.mutedForeground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 40),

              // 登录/注册模式切换 Tab
              ShadTabs<CsLoginFormMode>(
                value: _mode,
                onChanged: (v) => setState(() => _mode = v),
                tabs: [
                  ShadTab(
                    value: CsLoginFormMode.login,
                    content: Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: CsLoginForm(
                        mode: CsLoginFormMode.login,
                        onSuccess: (_) => widget.onLoginSuccess?.call(),
                        onForgotPassword: _handleForgotPassword,
                      ),
                    ),
                    child: const Text('登录'),
                  ),
                  ShadTab(
                    value: CsLoginFormMode.register,
                    content: Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: CsLoginForm(
                        mode: CsLoginFormMode.register,
                        onSuccess: (_) => widget.onLoginSuccess?.call(),
                      ),
                    ),
                    child: const Text('注册'),
                  ),
                ],
              ),

              // 跳过按钮
              if (widget.showSkipButton) ...[
                const SizedBox(height: 24),
                const ShadSeparator.horizontal(),
                const SizedBox(height: 16),
                ShadButton.ghost(
                  onPressed: _skipping ? null : _handleSkip,
                  child: _skipping
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          '跳过，先逛逛',
                          style: TextStyle(
                            color: shadTheme.colorScheme.mutedForeground,
                            fontSize: 13,
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    '匿名使用，随时可绑定账号保存数据',
                    style: TextStyle(
                      fontSize: 11,
                      color: shadTheme.colorScheme.mutedForeground,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 忘记密码页（输入邮箱，发送重置邮件）
class CsForgotPasswordPage extends StatefulWidget {
  const CsForgotPasswordPage({super.key});

  @override
  State<CsForgotPasswordPage> createState() => _CsForgotPasswordPageState();
}

class _CsForgotPasswordPageState extends State<CsForgotPasswordPage> {
  // Step 1: 邮箱输入
  final _emailFormKey = GlobalKey<ShadFormState>();
  final _emailCtrl = TextEditingController();

  // Step 2: OTP + 新密码输入
  final _resetFormKey = GlobalKey<ShadFormState>();
  final _otpCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _loading = false;
  String? _errorMessage;

  /// null = Step1（输入邮箱），non-null = Step2（输入验证码+新密码）
  String? _pendingEmail;

  bool get _isOtpStep => _pendingEmail != null;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await AuthManager.sendPasswordResetEmail(_emailCtrl.text.trim());
      if (mounted) setState(() => _pendingEmail = _emailCtrl.text.trim());
    } catch (e) {
      if (mounted) setState(() => _errorMessage = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyAndReset() async {
    if (!(_resetFormKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      // 用验证码建立 recovery session
      await AuthManager.verifyRecoveryOtp(
        _pendingEmail!,
        _otpCtrl.text.trim(),
      );
      // 设置新密码
      await AuthManager.updatePassword(_newPasswordCtrl.text);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('rate limit') ||
        raw.contains('over_email_send_rate_limit')) {
      return '发送太频繁，请等待片刻后再试';
    }
    if (raw.contains('Token has expired') || raw.contains('otp_expired')) {
      return '验证码已过期，请重新发送';
    }
    if (raw.contains('Invalid') && raw.contains('otp')) {
      return '验证码不正确，请重新输入';
    }
    if (raw.contains('Password should be at least')) {
      return '新密码至少需要 6 位';
    }
    return '操作失败，请检查后重试';
  }

  Widget _buildErrorBanner(ShadThemeData shadTheme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: shadTheme.colorScheme.destructive.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline,
                  size: 14, color: shadTheme.colorScheme.destructive),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                      fontSize: 12,
                      color: shadTheme.colorScheme.destructive),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);

    return Scaffold(
      appBar: const CsAppBar(title: '找回密码'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _isOtpStep
              ? _buildOtpStep(shadTheme)
              : _buildEmailStep(shadTheme),
        ),
      ),
    );
  }

  // Step 1：输入邮箱，发送验证码
  Widget _buildEmailStep(ShadThemeData shadTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text('输入注册邮箱', style: shadTheme.textTheme.h3),
        const SizedBox(height: 8),
        Text(
          '我们将向该邮箱发送验证码，输入验证码后可设置新密码',
          style: TextStyle(color: shadTheme.colorScheme.mutedForeground),
        ),
        const SizedBox(height: 32),
        ShadForm(
          key: _emailFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShadInputFormField(
                controller: _emailCtrl,
                id: 'email',
                label: const Text('邮箱'),
                placeholder: const Text('your@email.com'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v.trim().isEmpty) return '请输入邮箱';
                  if (!v.contains('@')) return '邮箱格式不正确';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null) _buildErrorBanner(shadTheme),
              ShadButton(
                onPressed: _loading ? null : _sendResetEmail,
                child: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('发送验证码'),
              ),
              const SizedBox(height: 12),
              ShadButton.ghost(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('返回登录'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Step 2：输入验证码 + 新密码
  Widget _buildOtpStep(ShadThemeData shadTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        // 提示
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: shadTheme.colorScheme.muted.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.mark_email_unread_outlined,
                      size: 16,
                      color: shadTheme.colorScheme.mutedForeground),
                  const SizedBox(width: 6),
                  Text(
                    '验证码已发送',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: shadTheme.colorScheme.foreground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '请查收发送到 $_pendingEmail 的邮件，\n输入其中的数字验证码并设置新密码',
                style: TextStyle(
                  fontSize: 12,
                  color: shadTheme.colorScheme.mutedForeground,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ShadForm(
          key: _resetFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 验证码
              ShadInputFormField(
                controller: _otpCtrl,
                id: 'otp',
                label: const Text('验证码'),
                placeholder: const Text('输入邮件中的数字验证码'),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                validator: (v) {
                  if (v.trim().isEmpty) return '请输入验证码';
                  if (v.trim().length < 6) return '验证码不完整';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // 新密码
              ShadInputFormField(
                controller: _newPasswordCtrl,
                id: 'newPassword',
                label: const Text('新密码'),
                placeholder: const Text('至少 6 位'),
                obscureText: true,
                validator: (v) {
                  if (v.isEmpty) return '请输入新密码';
                  if (v.length < 6) return '密码至少需要 6 位';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // 确认新密码
              ShadInputFormField(
                controller: _confirmPasswordCtrl,
                id: 'confirmPassword',
                label: const Text('确认新密码'),
                placeholder: const Text('再次输入新密码'),
                obscureText: true,
                validator: (v) {
                  if (v.isEmpty) return '请再次输入新密码';
                  if (v != _newPasswordCtrl.text) return '两次密码不一致';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null) _buildErrorBanner(shadTheme),
              ShadButton(
                onPressed: _loading ? null : _verifyAndReset,
                child: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('验证并重置密码'),
              ),
              const SizedBox(height: 8),
              ShadButton.link(
                onPressed: _loading
                    ? null
                    : () => setState(() {
                          _pendingEmail = null;
                          _otpCtrl.clear();
                          _errorMessage = null;
                        }),
                child: Text(
                  '重新发送验证码',
                  style: TextStyle(
                    fontSize: 12,
                    color: shadTheme.colorScheme.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 设置新密码页（用户通过邮件链接唤起 App 后显示）
///
/// 通常由 go_router 监听深链接后跳转到此页。
/// 调用时 supabase_flutter 已通过深链接自动建立了临时 session。
class CsResetPasswordPage extends StatefulWidget {
  const CsResetPasswordPage({super.key, this.onSuccess});

  /// 密码重置成功后的回调
  final VoidCallback? onSuccess;

  @override
  State<CsResetPasswordPage> createState() => _CsResetPasswordPageState();
}

class _CsResetPasswordPageState extends State<CsResetPasswordPage> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<ShadFormState>();
  bool _loading = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      await AuthManager.updatePassword(_passwordCtrl.text);
      if (mounted) {
        ShadToaster.of(context).show(
          const ShadToast(
            title: Text('密码已更新'),
            description: Text('请用新密码登录'),
          ),
        );
        widget.onSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(
          const ShadToast.destructive(
            title: Text('更新失败'),
            description: Text('链接已过期，请重新申请密码重置'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置新密码')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text('设置新密码', style: shadTheme.textTheme.h3),
              const SizedBox(height: 8),
              Text(
                '新密码至少 6 位',
                style: TextStyle(color: shadTheme.colorScheme.mutedForeground),
              ),
              const SizedBox(height: 32),
              ShadForm(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ShadInputFormField(
                      controller: _passwordCtrl,
                      id: 'password',
                      label: const Text('新密码'),
                      placeholder: const Text('至少 6 位'),
                      obscureText: true,
                      validator: (v) {
                        if (v.isEmpty) return '请输入新密码';
                        if (v.length < 6) return '密码至少需要 6 位';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    ShadInputFormField(
                      controller: _confirmCtrl,
                      id: 'confirm',
                      label: const Text('确认新密码'),
                      placeholder: const Text('再次输入'),
                      obscureText: true,
                      validator: (v) {
                        if (v.isEmpty) return '请确认密码';
                        if (v != _passwordCtrl.text) return '两次密码不一致';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ShadButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('确认修改'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
