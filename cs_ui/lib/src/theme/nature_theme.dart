import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// 自然绿主题 — 翡翠绿 + 10px 圆角 + 专业清爽
///
/// 色彩来源：shadcn/ui 自定义主题（oklch 精确转换）
/// 主色调：翡翠绿 #0EA471 / 明亮绿 #12D392（暗色模式）
/// 圆角：0.6rem ≈ 10px
class NatureTheme {
  const NatureTheme._();

  // ── Light mode ────────────────────────────────────────
  static const _bgLight           = Color(0xFFFCFDFB);
  static const _fgLight           = Color(0xFF0D261E);
  static const _cardLight         = Color(0xFFFFFFFF);
  static const _primaryLight      = Color(0xFF0EA471);
  static const _primaryFgLight    = Color(0xFFF5FFFA);
  static const _secondaryLight    = Color(0xFFECF4F0);
  static const _secondaryFgLight  = Color(0xFF20604A);
  static const _mutedLight        = Color(0xFFEDF2EF);
  static const _mutedFgLight      = Color(0xFF628478);
  static const _accentLight       = Color(0xFFE2F3EC);
  static const _accentFgLight     = Color(0xFF1A664C);
  static const _destructiveLight  = Color(0xFFEF4342);
  static const _destructiveFgLight= Color(0xFFFAFAF9);
  static const _borderLight       = Color(0xFFDAE7E1);
  static const _inputLight        = Color(0xFFDAE7E1);

  // ── Dark mode ─────────────────────────────────────────
  static const _bgDark            = Color(0xFF050B09);
  static const _fgDark            = Color(0xFFF9FBF9);
  static const _cardDark          = Color(0xFF08120E);
  static const _popoverDark       = Color(0xFF060E0B);
  static const _primaryDark       = Color(0xFF12D392);
  static const _primaryFgDark     = Color(0xFFF5FFFA);
  static const _secondaryDark     = Color(0xFF172621);
  static const _secondaryFgDark   = Color(0xFFE0EBE6);
  static const _mutedDark         = Color(0xFF13201B);
  static const _mutedFgDark       = Color(0xFF98B3A9);
  static const _accentDark        = Color(0xFF19342A);
  static const _destructiveDark   = Color(0xFF912221);
  static const _destructiveFgDark = Color(0xFFFAFAF9);
  static const _borderDark        = Color(0xFF1F2E29);
  static const _inputDark         = Color(0xFF1F2E29);

  static ShadThemeData get themeData => ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadColorScheme(
          background:            _bgLight,
          foreground:            _fgLight,
          card:                  _cardLight,
          cardForeground:        _fgLight,
          popover:               _cardLight,
          popoverForeground:     _fgLight,
          primary:               _primaryLight,
          primaryForeground:     _primaryFgLight,
          secondary:             _secondaryLight,
          secondaryForeground:   _secondaryFgLight,
          muted:                 _mutedLight,
          mutedForeground:       _mutedFgLight,
          accent:                _accentLight,
          accentForeground:      _accentFgLight,
          destructive:           _destructiveLight,
          destructiveForeground: _destructiveFgLight,
          border:                _borderLight,
          input:                 _inputLight,
          ring:                  _primaryLight,
          selection:             Color(0x330EA471),
        ),
        radius: BorderRadius.circular(10),
        primaryButtonTheme:   const ShadButtonTheme(height: 40),
        secondaryButtonTheme: const ShadButtonTheme(height: 40),
        outlineButtonTheme:   const ShadButtonTheme(height: 40),
      );

  static ShadThemeData get darkThemeData => ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadColorScheme(
          background:            _bgDark,
          foreground:            _fgDark,
          card:                  _cardDark,
          cardForeground:        _fgDark,
          popover:               _popoverDark,
          popoverForeground:     _fgDark,
          primary:               _primaryDark,
          primaryForeground:     _primaryFgDark,
          secondary:             _secondaryDark,
          secondaryForeground:   _secondaryFgDark,
          muted:                 _mutedDark,
          mutedForeground:       _mutedFgDark,
          accent:                _accentDark,
          accentForeground:      _fgDark,
          destructive:           _destructiveDark,
          destructiveForeground: _destructiveFgDark,
          border:                _borderDark,
          input:                 _inputDark,
          ring:                  _primaryDark,
          selection:             Color(0x3312D392),
        ),
        radius: BorderRadius.circular(10),
        primaryButtonTheme:   const ShadButtonTheme(height: 40),
        secondaryButtonTheme: const ShadButtonTheme(height: 40),
        outlineButtonTheme:   const ShadButtonTheme(height: 40),
      );
}
