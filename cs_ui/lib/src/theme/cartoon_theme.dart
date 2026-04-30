import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// 卡通风主题
///
/// 设计规范：
/// - ColorScheme: ShadRoseColorScheme（珊瑚粉系）
/// - 全局圆角：20px（大圆角）
/// - 背景：#FFF9F0 暖奶油
/// - 按钮：鲜艳填充、厚边框、大圆角，高度 48px
/// - 字体：系统默认，字号偏大
class CartoonTheme {
  const CartoonTheme._();

  static ShadThemeData get themeData => ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadRoseColorScheme.light(
          background: Color(0xFFFFF9F0),
        ),
        radius: BorderRadius.circular(20),
        primaryButtonTheme: const ShadButtonTheme(height: 48),
        secondaryButtonTheme: const ShadButtonTheme(height: 48),
        outlineButtonTheme: const ShadButtonTheme(height: 48),
      );

  static ShadThemeData get darkThemeData => ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadRoseColorScheme.dark(),
        radius: BorderRadius.circular(20),
        primaryButtonTheme: const ShadButtonTheme(height: 48),
        secondaryButtonTheme: const ShadButtonTheme(height: 48),
        outlineButtonTheme: const ShadButtonTheme(height: 48),
      );
}
