import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// 视频占位组件。
///
/// 在视频尚未提供时显示，样式与 [CsPlaceholderImage] 和 [CsPlaceholderLottie] 均有明显区别：
/// - 图标：[Icons.play_circle_outline]（区别于图片的 image_outlined / 动画的 animation）
/// - 背景色：secondary 色（区别于图片的 muted 灰色 / 动画的 accent 彩色）
/// - 带扩散脉冲动效，视觉上与其他占位区分
///
/// 通常由 [CsVideo] 在无视频源时自动使用，也可直接使用。
class CsPlaceholderVideo extends StatefulWidget {
  const CsPlaceholderVideo({
    super.key,
    this.width,
    this.height,
    this.description,
  });

  final double? width;
  final double? height;

  /// 占位图中心显示的描述文字，通常填写该视频插槽的用途。
  final String? description;

  @override
  State<CsPlaceholderVideo> createState() => _CsPlaceholderVideoState();
}

class _CsPlaceholderVideoState extends State<CsPlaceholderVideo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final bgColor = theme.colorScheme.secondary;
    final fgColor = theme.colorScheme.secondaryForeground;
    final borderRadius = theme.radius as BorderRadiusGeometry;

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Opacity(
              opacity: _pulseAnimation.value,
              child: child,
            ),
            child: Icon(
              Icons.play_circle_outline,
              size: 36,
              color: fgColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Video',
            style: theme.textTheme.muted.copyWith(
              fontSize: 10,
              color: fgColor.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.8,
            ),
          ),
          if (widget.description != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                widget.description!,
                style: theme.textTheme.muted.copyWith(
                  fontSize: 12,
                  color: fgColor,
                ),
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
