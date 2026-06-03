import 'package:cached_network_image/cached_network_image.dart';
import 'package:cs_core/cs_core.dart';
import 'package:flutter/material.dart';

import 'cs_placeholder_image.dart';

/// 图片管理层核心 Widget。
///
/// 通过 [configKey] 从配置系统读取图片信息，自动按优先级降级显示：
///
/// 1. **远程 URL**（`url` 字段）：优先，支持 Supabase 热更新，不发版生效
/// 2. **本地 asset**（`asset` 字段）：次之，随 App 打包，离线可用
/// 3. **[CsPlaceholderImage]**：图片尚未提供时的占位
///
/// 配置由 AI Skill `cs-image-manager` 统一管理，开发者无需在代码里写路径。
///
/// 示例：
/// ```dart
/// CsImage(
///   configKey: 'home_banner_image',
///   description: '首页横幅',
///   height: 200,
/// )
/// ```
///
/// `default_configs.json` 配置格式：
/// ```json
/// "home_banner_image": {
///   "url": null,
///   "asset": "assets/images/home_banner.png"
/// }
/// ```
class CsImage extends StatefulWidget {
  const CsImage({
    super.key,
    required this.configKey,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.description,
  });

  /// 配置 key，对应 `default_configs.json` / Supabase 中的图片配置项。
  final String configKey;

  final double? width;
  final double? height;
  final BoxFit fit;

  /// 占位图显示的描述文字，建议填写图片用途（如「首页横幅」）。
  final String? description;

  @override
  State<CsImage> createState() => _CsImageState();
}

class _CsImageState extends State<CsImage> {
  late Future<Map<String, dynamic>?> _configFuture;

  @override
  void initState() {
    super.initState();
    _configFuture = ConfigManager.getMap(widget.configKey);
  }

  @override
  void didUpdateWidget(CsImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configKey != widget.configKey) {
      _configFuture = ConfigManager.getMap(widget.configKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _configFuture,
      builder: (context, snapshot) {
        final config = snapshot.data;

        // 远程 URL 优先
        final url = config?['url'] as String?;
        if (url != null && url.isNotEmpty) {
          return CachedNetworkImage(
            imageUrl: url,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            placeholder: (_, __) => CsPlaceholderImage(
              width: widget.width,
              height: widget.height,
              description: widget.description,
            ),
            errorWidget: (_, __, ___) => CsPlaceholderImage(
              width: widget.width,
              height: widget.height,
              description: widget.description,
            ),
          );
        }

        // 本地 asset 次之（须用宿主 App 的 AssetBundle，否则会误查 cs_ui 包内资源）
        final asset = config?['asset'] as String?;
        if (asset != null && asset.isNotEmpty) {
          return Image.asset(
            asset,
            bundle: DefaultAssetBundle.of(context),
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            errorBuilder: (_, __, ___) => CsPlaceholderImage(
              width: widget.width,
              height: widget.height,
              description: widget.description,
            ),
          );
        }

        // 配置加载中：仅占位，避免误显示「无图源」占位（与 loaded-null 区分可选）
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CsPlaceholderImage(
            width: widget.width,
            height: widget.height,
            description: widget.description,
          );
        }

        // 无配置或加载中：占位图
        return CsPlaceholderImage(
          width: widget.width,
          height: widget.height,
          description: widget.description,
        );
      },
    );
  }
}
