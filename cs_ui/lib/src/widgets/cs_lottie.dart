import 'package:cs_core/cs_core.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'cs_placeholder_lottie.dart';

/// Lottie 动画管理层核心 Widget。
///
/// 通过 [configKey] 从配置系统读取动画信息，自动按优先级降级显示：
///
/// 1. **远程 URL**（`url` 字段）：优先，支持热更新，不发版生效
/// 2. **本地 asset**（`asset` 字段）：次之，随 App 打包，离线可用
/// 3. **[CsPlaceholderLottie]**：动画尚未提供时的占位（与图片占位视觉明显不同）
///
/// 配置由 AI Skill `cs-lottie-manager` 统一管理，开发者无需在代码里写路径或 URL。
///
/// 示例：
/// ```dart
/// CsLottie(
///   configKey: 'home_loading_animation',
///   description: '首页加载动画',
///   width: 200,
///   height: 200,
/// )
/// ```
///
/// `default_configs.json` 配置格式：
/// ```json
/// "home_loading_animation": {
///   "url": null,
///   "asset": "assets/animations/home_loading.json"
/// }
/// ```
class CsLottie extends StatefulWidget {
  const CsLottie({
    super.key,
    required this.configKey,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.description,
    this.repeat = true,
    this.animate = true,
    this.reverse = false,
    this.frameRate = FrameRate.max,
    this.onLoaded,
  });

  /// 配置 key，对应 `default_configs.json` / Supabase 中的动画配置项。
  final String configKey;

  final double? width;
  final double? height;
  final BoxFit fit;

  /// 占位图显示的描述文字，建议填写动画用途（如「首页加载动画」）。
  final String? description;

  /// 是否循环播放，默认 true。
  final bool repeat;

  /// 是否自动播放，默认 true。
  final bool animate;

  /// 是否倒序播放，默认 false。
  final bool reverse;

  /// 帧率，默认 [FrameRate.max]（跟随设备刷新率）。
  final FrameRate frameRate;

  /// 动画加载完成回调，可用于获取 [LottieComposition] 信息。
  final void Function(LottieComposition)? onLoaded;

  @override
  State<CsLottie> createState() => _CsLottieState();
}

class _CsLottieState extends State<CsLottie> {
  late Future<Map<String, dynamic>?> _configFuture;

  @override
  void initState() {
    super.initState();
    _configFuture = ConfigManager.getMap(widget.configKey);
  }

  @override
  void didUpdateWidget(CsLottie oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configKey != widget.configKey) {
      _configFuture = ConfigManager.getMap(widget.configKey);
    }
  }

  Widget _placeholder() => CsPlaceholderLottie(
        width: widget.width,
        height: widget.height,
        description: widget.description,
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _configFuture,
      builder: (context, snapshot) {
        final config = snapshot.data;

        // 远程 URL 优先
        final url = config?['url'] as String?;
        if (url != null && url.isNotEmpty) {
          return Lottie.network(
            url,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            repeat: widget.repeat,
            animate: widget.animate,
            reverse: widget.reverse,
            frameRate: widget.frameRate,
            onLoaded: widget.onLoaded,
            errorBuilder: (_, __, ___) => _placeholder(),
            // 加载中显示占位
            frameBuilder: (context, child, composition) {
              if (composition == null) return _placeholder();
              return child;
            },
          );
        }

        // 本地 asset 次之
        final asset = config?['asset'] as String?;
        if (asset != null && asset.isNotEmpty) {
          return Lottie.asset(
            asset,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            repeat: widget.repeat,
            animate: widget.animate,
            reverse: widget.reverse,
            frameRate: widget.frameRate,
            onLoaded: widget.onLoaded,
            errorBuilder: (_, __, ___) => _placeholder(),
          );
        }

        // 无配置或加载中：占位
        return _placeholder();
      },
    );
  }
}
