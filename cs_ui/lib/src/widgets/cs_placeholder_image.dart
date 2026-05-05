import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// 图片占位组件。
///
/// 在图片尚未提供时显示，样式与当前主题保持一致。
/// 通常由 [CsImage] 在无图源时自动使用，也可直接使用。
class CsPlaceholderImage extends StatelessWidget {
  const CsPlaceholderImage({
    super.key,
    this.width,
    this.height,
    this.description,
  });

  final double? width;
  final double? height;

  /// 占位图中心显示的描述文字，通常填写该图片插槽的用途。
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final bgColor = theme.colorScheme.muted;
    final fgColor = theme.colorScheme.mutedForeground;

    final borderRadius = theme.radius as BorderRadiusGeometry;

    // 导航栏、卡片左侧等小尺寸占位：不可用 32dp 图标 + 说明文字塞进 24~44dp 盒子，否则会竖直溢出。
    final w = width;
    final h = height;
    final compact = (w != null && w <= 56) || (h != null && h <= 56);
    if (compact) {
      final side = (w != null && h != null)
          ? (w < h ? w : h)
          : (w ?? h ?? 24.0);
      final iconSize = (side * 0.58).clamp(12.0, 26.0);
      return Container(
        width: w,
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: borderRadius,
        ),
        child: Icon(
          Icons.image_outlined,
          size: iconSize,
          color: fgColor,
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 32,
            color: fgColor,
          ),
          if (description != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                description!,
                style: theme.textTheme.muted.copyWith(fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
