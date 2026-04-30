import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:cs_auth/cs_auth.dart';
import 'package:cs_core/cs_core.dart';

/// 登录/注册表单积木
///
/// 可嵌入任意页面（全屏页、BottomSheet、Dialog 均可）。
/// 支持三种模式：
/// - [CsLoginFormMode.login]：邮箱密码登录
/// - [CsLoginFormMode.register]：邮箱密码注册（注册后自动进入 OTP 验证步骤）
/// - [CsLoginFormMode.linkEmail]：匿名账号绑定邮箱（升级，保留历史数据）
///
/// ## 注册 OTP 验证流程
///
/// 注册成功后若 Supabase 要求邮件验证，表单自动切换到 OTP 输入步骤：
/// 用户查收邮件中的 6 位数字验证码 → 填入表单 → 验证通过即完成登录。
/// 无需点击邮件链接，彻底解决跨设备打开链接的兼容问题。
///
/// ## 使用示例
///
/// ```dart
/// // 全屏嵌入
/// CsLoginForm(
///   mode: CsLoginFormMode.login,
///   onSuccess: (user) => context.go('/home'),
///   onForgotPassword: () => context.push('/forgot-password'),
/// )
///
/// // BottomSheet 弹出（匿名用户绑定邮箱）
/// showModalBottomSheet(
///   context: context,
///   builder: (_) => CsLoginForm(
///     mode: CsLoginFormMode.linkEmail,
///     onSuccess: (_) => Navigator.pop(context),
///   ),
/// );
/// ```
enum CsLoginFormMode { login, register, linkEmail }

class CsLoginForm extends StatefulWidget {
  const CsLoginForm({
    super.key,
    this.mode = CsLoginFormMode.login,
    this.onSuccess,
    this.onForgotPassword,
    this.onSwitchMode,
  });

  final CsLoginFormMode mode;

  /// 登录/注册/绑定成功后的回调
  final ValueChanged<dynamic>? onSuccess;

  /// 点击「忘记密码」的回调（仅 login 模式显示）
  final VoidCallback? onForgotPassword;

  /// 切换模式（login ↔ register）的回调，由父级控制模式切换
  final ValueChanged<CsLoginFormMode>? onSwitchMode;

  @override
  State<CsLoginForm> createState() => _CsLoginFormState();
}

class _CsLoginFormState extends State<CsLoginForm> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _formKey = GlobalKey<ShadFormState>();
  final _otpFormKey = GlobalKey<ShadFormState>();
  bool _loading = false;
  String? _errorMessage;

  /// 注册成功但需要邮件验证时，记录待验证的邮箱并切换到 OTP 步骤
  String? _pendingOtpEmail;

  bool get _isOtpStep => _pendingOtpEmail != null;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      switch (widget.mode) {
        case CsLoginFormMode.login:
          final res = await AuthManager.signInWithEmail(
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
          );
          widget.onSuccess?.call(res.user);

        case CsLoginFormMode.register:
          final res = await AuthManager.signUpWithEmail(
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
          );
          if (res.session != null) {
            // Supabase 未开启邮件确认，直接登录成功
            widget.onSuccess?.call(res.user);
          } else if (res.user?.identities?.isEmpty ?? true) {
            // identities 为空 = 该邮箱已注册（user_repeated_signup）
            // Supabase 故意返回 200 防止邮箱枚举，但不发送验证邮件
            throw Exception('User already registered');
          } else {
            // identities 有值 = 新用户注册成功，等待邮件验证
            setState(() => _pendingOtpEmail = _emailCtrl.text.trim());
          }

        case CsLoginFormMode.linkEmail:
          final res = await AuthManager.linkWithEmail(
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
          );
          widget.onSuccess?.call(res.user);
      }
    } catch (e) {
      setState(() => _errorMessage = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (!(_otpFormKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final res = await AuthManager.verifyEmailOtp(
        _pendingOtpEmail!,
        _otpCtrl.text.trim(),
      );
      widget.onSuccess?.call(res.user);
    } catch (e) {
      setState(() => _errorMessage = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('Invalid login credentials')) return '邮箱或密码不正确';
    if (raw.contains('User already registered')) return '该邮箱已注册，请切换到「登录」';
    if (raw.contains('Password should be at least')) return '密码至少需要 6 位';
    if (raw.contains('Unable to validate email')) return '邮箱格式不正确';
    if (raw.contains('Email not confirmed')) return '邮箱尚未验证，请查收验证邮件';
    if (raw.contains('Token has expired')) return '验证码已过期，请重新注册';
    if (raw.contains('otp_expired')) return '验证码已过期，请重新注册';
    if (raw.contains('Invalid') && raw.contains('otp')) return '验证码不正确，请重新输入';
    if (raw.contains('over_email_send_rate_limit') ||
        raw.contains('For security purposes')) {
      return '发送太频繁，请稍等片刻再试';
    }
    return '操作失败，请稍后重试';
  }

  String get _submitLabel {
    return switch (widget.mode) {
      CsLoginFormMode.login => '登录',
      CsLoginFormMode.register => '注册',
      CsLoginFormMode.linkEmail => '绑定账号（保留历史数据）',
    };
  }

  Widget _buildErrorBanner(ShadThemeData shadTheme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    color: shadTheme.colorScheme.destructive,
                  ),
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

    // OTP 验证步骤
    if (_isOtpStep) {
      return ShadForm(
        key: _otpFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 说明文字
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
                    '请查收发送到 $_pendingOtpEmail 的邮件，\n将其中的数字验证码输入下方',
                    style: TextStyle(
                      fontSize: 12,
                      color: shadTheme.colorScheme.mutedForeground,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // OTP 输入框
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
                if (v.trim().length < 6) return '验证码不完整，请检查后重新输入';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 错误提示
            if (_errorMessage != null) _buildErrorBanner(shadTheme),

            // 验证按钮
            ShadButton(
              onPressed: _loading ? null : _verifyOtp,
              child: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('验证并登录'),
            ),
            const SizedBox(height: 8),

            // 重新填写
            Center(
              child: ShadButton.link(
                onPressed: _loading
                    ? null
                    : () => setState(() {
                          _pendingOtpEmail = null;
                          _otpCtrl.clear();
                          _errorMessage = null;
                        }),
                child: Text(
                  '重新填写邮箱/密码',
                  style: TextStyle(
                    fontSize: 12,
                    color: shadTheme.colorScheme.mutedForeground,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 登录/注册/绑定表单
    return ShadForm(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 邮箱
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
          const SizedBox(height: 12),

          // 密码
          ShadInputFormField(
            controller: _passwordCtrl,
            id: 'password',
            label: const Text('密码'),
            placeholder: const Text('至少 6 位'),
            obscureText: true,
            validator: (v) {
              if (v.isEmpty) return '请输入密码';
              if (v.length < 6) return '密码至少需要 6 位';
              return null;
            },
          ),

          // 确认密码（注册和绑定模式）
          if (widget.mode != CsLoginFormMode.login) ...[
            const SizedBox(height: 12),
            ShadInputFormField(
              controller: _confirmPasswordCtrl,
              id: 'confirmPassword',
              label: const Text('确认密码'),
              placeholder: const Text('再次输入密码'),
              obscureText: true,
              validator: (v) {
                if (v.isEmpty) return '请再次输入密码';
                if (v != _passwordCtrl.text) return '两次密码不一致';
                return null;
              },
            ),
          ],

          // 忘记密码（仅登录模式）
          if (widget.mode == CsLoginFormMode.login &&
              widget.onForgotPassword != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: ShadButton.link(
                onPressed: widget.onForgotPassword,
                child: Text(
                  '忘记密码？',
                  style: TextStyle(
                    fontSize: 12,
                    color: shadTheme.colorScheme.mutedForeground,
                  ),
                ),
              ),
            ),
          ] else
            const SizedBox(height: 16),

          // 错误提示
          if (_errorMessage != null) _buildErrorBanner(shadTheme),

          // 提交按钮
          ShadButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_submitLabel),
          ),

          // 切换模式（login ↔ register，linkEmail 不显示）
          if (widget.mode != CsLoginFormMode.linkEmail &&
              widget.onSwitchMode != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.mode == CsLoginFormMode.login ? '还没有账号？' : '已有账号？',
                  style: TextStyle(
                    fontSize: 13,
                    color: shadTheme.colorScheme.mutedForeground,
                  ),
                ),
                ShadButton.link(
                  onPressed: () => widget.onSwitchMode?.call(
                    widget.mode == CsLoginFormMode.login
                        ? CsLoginFormMode.register
                        : CsLoginFormMode.login,
                  ),
                  child: Text(
                    widget.mode == CsLoginFormMode.login ? '注册' : '登录',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
