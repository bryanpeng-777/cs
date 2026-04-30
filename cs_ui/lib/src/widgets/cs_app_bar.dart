import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// cs_ui 顶层导航栏组件
///
/// 封装 Material [AppBar] 并使用 shadcn 主题色，与 [CsApp] 无缝集成。
/// 透明背景 + 无阴影，适合叠加在页面内容上方。
///
/// 用法：
/// ```dart
/// Scaffold(
///   appBar: CsAppBar(title: '页面标题'),
///   body: ...,
/// )
/// ```
class CsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CsAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.backgroundColor = Colors.transparent,
    this.elevation = 0,
    this.centerTitle = false,
    this.bottom,
    this.titleTextStyle,
  });

  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final Color backgroundColor;
  final double elevation;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;
  final TextStyle? titleTextStyle;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final defaultTitleStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 18,
      color: shadTheme.colorScheme.foreground,
    );

    return AppBar(
      backgroundColor: backgroundColor,
      elevation: elevation,
      centerTitle: centerTitle,
      leading: leading,
      actions: actions,
      bottom: bottom,
      title: title != null
          ? Text(title!, style: titleTextStyle ?? defaultTitleStyle)
          : null,
    );
  }
}
