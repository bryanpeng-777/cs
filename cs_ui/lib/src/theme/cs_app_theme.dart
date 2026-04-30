import 'package:shadcn_ui/shadcn_ui.dart';
import 'fresh_minimal_theme.dart';
import 'cartoon_theme.dart';
import 'nature_theme.dart';

export 'fresh_minimal_theme.dart';
export 'cartoon_theme.dart';
export 'nature_theme.dart';

/// 可用主题风格枚举
enum CsThemeStyle {
  /// 清新简约 — 冷灰蓝 + 8px 圆角 + 轻盈排版
  freshMinimal,

  /// 卡通风 — 珊瑚粉 + 20px 圆角 + 活泼大按钮
  cartoon,

  /// 自然绿 — 翡翠绿 + 10px 圆角 + 专业清爽
  nature,
}

/// 主题工厂 — Skill 切换时只改 [activeStyle] 一行
///
/// 新增风格步骤：
/// 1. 创建 `xxx_theme.dart` 实现 [ShadThemeData]
/// 2. 在 [CsThemeStyle] 新增枚举值
/// 3. 在 [_themeForStyle] / [_darkThemeForStyle] 补 case
/// 4. 更新 [activeStyle] 指向新枚举值
class CsAppTheme {
  const CsAppTheme._();

  // ─────────────────────────────────────────────
  // ↓↓↓ Skill 切换时只改这一行 ↓↓↓
  static const CsThemeStyle activeStyle = CsThemeStyle.cartoon;
  // ↑↑↑ Skill 切换时只改这一行 ↑↑↑
  // ─────────────────────────────────────────────

  static ShadThemeData get active => _themeForStyle(activeStyle);
  static ShadThemeData get activeDark => _darkThemeForStyle(activeStyle);

  static ShadThemeData _themeForStyle(CsThemeStyle style) {
    switch (style) {
      case CsThemeStyle.freshMinimal:
        return FreshMinimalTheme.themeData;
      case CsThemeStyle.cartoon:
        return CartoonTheme.themeData;
      case CsThemeStyle.nature:
        return NatureTheme.themeData;
    }
  }

  static ShadThemeData _darkThemeForStyle(CsThemeStyle style) {
    switch (style) {
      case CsThemeStyle.freshMinimal:
        return FreshMinimalTheme.darkThemeData;
      case CsThemeStyle.cartoon:
        return CartoonTheme.darkThemeData;
      case CsThemeStyle.nature:
        return NatureTheme.darkThemeData;
    }
  }
}
