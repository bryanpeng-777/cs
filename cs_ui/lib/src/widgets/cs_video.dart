import 'package:cs_framework/cs_framework.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'cs_placeholder_video.dart';

/// 视频管理层核心 Widget。
///
/// 通过 [configKey] 从配置系统读取视频信息，自动按优先级降级显示：
///
/// 1. **远程 URL**（`url` 字段）：优先，支持热更新，不发版生效
/// 2. **本地 asset**（`asset` 字段）：次之，随 App 打包，离线可用
/// 3. **[CsPlaceholderVideo]**：视频尚未提供时的占位（与图片/动画占位视觉明显不同）
///
/// 配置由 AI Skill `cs-video-manager` 统一管理，开发者无需在代码里写路径或 URL。
///
/// 示例：
/// ```dart
/// CsVideo(
///   configKey: 'home_intro_video',
///   description: '首页介绍视频',
///   width: double.infinity,
///   height: 200,
/// )
/// ```
///
/// `default_configs.json` 配置格式：
/// ```json
/// "home_intro_video": {
///   "url": null,
///   "asset": "assets/videos/home_intro.mp4"
/// }
/// ```
class CsVideo extends StatefulWidget {
  const CsVideo({
    super.key,
    required this.configKey,
    this.width,
    this.height,
    this.description,
    this.loop = true,
    this.autoPlay = false,
    this.showControls = true,
  });

  /// 配置 key，对应 `default_configs.json` / Supabase 中的视频配置项。
  final String configKey;

  final double? width;
  final double? height;

  /// 占位图显示的描述文字，建议填写视频用途（如「首页介绍视频」）。
  final String? description;

  /// 是否循环播放，默认 true。
  final bool loop;

  /// 是否自动播放，默认 false。
  final bool autoPlay;

  /// 是否显示播放控制条（播放/暂停 + 进度条），默认 true。
  final bool showControls;

  @override
  State<CsVideo> createState() => _CsVideoState();
}

class _CsVideoState extends State<CsVideo> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _loadedSource;
  String? _errorText;
  Map<String, dynamic>? _lastConfig;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void didUpdateWidget(CsVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configKey != widget.configKey) {
      _disposeController();
      _loadConfig();
    }
  }

  Future<void> _loadConfig() async {
    final config = await ConfigManager.getMap(widget.configKey);
    if (!mounted) return;

    _lastConfig = config;

    final url = config?['url'] as String?;
    final asset = config?['asset'] as String?;

    if (kDebugMode) {
      debugPrint(
        '[CsVideo] ${widget.configKey} config=$config '
        'url=$url asset=$asset',
      );
    }

    if (url != null && url.isNotEmpty) {
      await _initController(url, isNetwork: true);
    } else if (asset != null && asset.isNotEmpty) {
      await _initController(asset, isNetwork: false);
    } else {
      // 无配置，保持占位状态
      if (mounted) {
        setState(() {
          _errorText = 'No video source in config';
        });
      }
    }
  }

  Future<void> _initController(String source, {required bool isNetwork}) async {
    if (_loadedSource == source || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    await _disposeController();

    final controller = isNetwork
        ? VideoPlayerController.networkUrl(Uri.parse(source))
        : VideoPlayerController.asset(source);

    try {
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      await controller.setLooping(widget.loop);
      if (widget.autoPlay) await controller.play();

      setState(() {
        _controller = controller;
        _isInitialized = true;
        _isLoading = false;
        _loadedSource = source;
        _errorText = null;
      });
      if (kDebugMode) {
        debugPrint(
          '[CsVideo] ${widget.configKey} initialized '
          'source=$source size=${controller.value.size}',
        );
      }
    } catch (e) {
      controller.dispose();
      if (kDebugMode) {
        debugPrint(
          '[CsVideo] ${widget.configKey} init failed '
          'source=$source isNetwork=$isNetwork error=$e',
        );
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = e.toString();
        });
      }
    }
  }

  Future<void> _disposeController() async {
    final old = _controller;
    _controller = null;
    _isInitialized = false;
    _loadedSource = null;
    await old?.dispose();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _placeholder() {
    final placeholder = CsPlaceholderVideo(
      width: widget.width,
      height: widget.height,
      description: widget.description,
    );
    if (!kDebugMode) return placeholder;

    final lines = <String>[
      if (_isLoading) 'loading=true',
      'config=${_lastConfig == null ? 'null' : _lastConfig.toString()}',
      if (_errorText != null) 'error=$_errorText',
    ];

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(
        children: [
          Expanded(child: placeholder),
          Container(
            width: double.infinity,
            color: Colors.black87,
            padding: const EdgeInsets.all(6),
            child: Text(
              lines.join('\n'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return _placeholder();
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: _CsVideoPlayer(
        controller: _controller!,
        showControls: widget.showControls,
      ),
    );
  }
}

// ── 视频播放器 + 控制条 ───────────────────────────────────────
class _CsVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final bool showControls;

  const _CsVideoPlayer({
    required this.controller,
    required this.showControls,
  });

  @override
  State<_CsVideoPlayer> createState() => _CsVideoPlayerState();
}

class _CsVideoPlayerState extends State<_CsVideoPlayer> {
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _togglePlayPause() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final isPlaying = value.isPlaying;
    final position = value.position;
    final duration = value.duration;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 视频画面
          AspectRatio(
            aspectRatio: widget.controller.value.aspectRatio,
            child: VideoPlayer(widget.controller),
          ),

          // 控制条（点击切换显隐）
          if (widget.showControls)
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _VideoProgressBar(
                        progress: progress,
                        onSeek: (ratio) {
                          widget.controller.seekTo(Duration(
                            milliseconds:
                                (duration.inMilliseconds * ratio).round(),
                          ));
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _fmt(position),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── 可拖动进度条 ─────────────────────────────────────────────
class _VideoProgressBar extends StatelessWidget {
  final double progress;
  final ValueChanged<double> onSeek;

  const _VideoProgressBar({required this.progress, required this.onSeek});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => onSeek(d.localPosition.dx / trackWidth),
          onHorizontalDragUpdate: (d) =>
              onSeek((d.localPosition.dx / trackWidth).clamp(0.0, 1.0)),
          child: SizedBox(
            height: 20,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 背景轨道
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 已播放进度
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                // 拖动手柄
                Positioned(
                  left: (trackWidth * progress - 6).clamp(0.0, trackWidth - 12),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
