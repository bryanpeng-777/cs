import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Lottie 动画占位组件。
///
/// 在动画尚未提供时显示，样式与 [CsPlaceholderImage] 有明显区别：
/// - 图标：[Icons.animation]（区别于图片的 image_outlined）
/// - 背景色：accent 色（彩色调，区别于图片占位的 muted 灰色）
/// - 带波形脉冲动效，视觉上与静态图片占位区分
///
/// 通常由 [CsLottie] 在无动画源时自动使用，也可直接使用。
class CsPlaceholderLottie extends StatefulWidget {
  const CsPlaceholderLottie({
    super.key,
    this.width,
    this.height,
    this.description,
  });

  final double? width;
  final double? height;

  /// 占位图中心显示的描述文字，通常填写该动画插槽的用途。
  final String? description;

  @override
  State<CsPlaceholderLottie> createState() => _CsPlaceholderLottieState();
}

class _CsPlaceholderLottieState extends State<CsPlaceholderLottie>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
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
    final bgColor = theme.colorScheme.accent;
    final fgColor = theme.colorScheme.accentForeground;
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
              Icons.animation,
              size: 32,
              color: fgColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Animation',
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
