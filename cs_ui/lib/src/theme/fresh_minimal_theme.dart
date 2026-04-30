import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// 清新简约主题
///
/// 设计规范：
/// - ColorScheme: ShadSlateColorScheme（冷灰蓝系）
/// - 全局圆角：8px
/// - 背景：#FAFAFA 浅灰白
/// - 按钮：轻填充、细描边，高度 40px
/// - 字体：系统默认，行距 1.4
class FreshMinimalTheme {
  const FreshMinimalTheme._();

  static ShadThemeData get themeData => ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadSlateColorScheme.light(
          background: Color(0xFFFAFAFA),
        ),
        radius: BorderRadius.circular(8),
        primaryButtonTheme: const ShadButtonTheme(height: 40),
        secondaryButtonTheme: const ShadButtonTheme(height: 40),
        outlineButtonTheme: const ShadButtonTheme(height: 40),
      );

  static ShadThemeData get darkThemeData => ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadSlateColorScheme.dark(),
        radius: BorderRadius.circular(8),
        primaryButtonTheme: const ShadButtonTheme(height: 40),
        secondaryButtonTheme: const ShadButtonTheme(height: 40),
        outlineButtonTheme: const ShadButtonTheme(height: 40),
      );
}
