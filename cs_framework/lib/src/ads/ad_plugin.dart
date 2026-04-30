import 'package:flutter/widgets.dart';

/// 广告插件抽象接口
///
/// 框架内置 [AdMobPlugin]（Google AdMob，国际广告）。
/// 国内广告（穿山甲、优量汇等）由各 App 自行实现此接口后注册到 [AdManager]。
///
/// 实现示例：
/// ```dart
/// class MyPanglePlugin implements AdPlugin {
///   @override
///   String get pluginId => 'pangle';
///
///   @override
///   Future<void> initialize(Map<String, dynamic> config) async {
///     // 初始化穿山甲 SDK
///   }
///   // ... 实现其他方法
/// }
///
/// // 注册到框架
/// AdManager.registerPlugin(MyPanglePlugin(), config: {'app_id': 'xxx'});
/// ```

/// 广告类型
enum CsAdType {
  /// 横幅广告（页面底部/顶部常驻）
  banner,

  /// 插屏广告（全屏，适合关卡切换等场景）
  interstitial,

  /// 激励视频（看完视频获得奖励）
  rewarded,

  /// 原生广告（嵌入内容流）
  native,
}

/// 广告加载状态
enum CsAdState {
  idle,
  loading,
  loaded,
  failed,
  shown,
  closed,
}

/// 激励广告奖励
class CsAdReward {
  final String type;
  final int amount;

  const CsAdReward({required this.type, required this.amount});
}

/// 广告事件回调
class CsAdCallbacks {
  /// 广告加载完成
  final VoidCallback? onLoaded;

  /// 广告加载失败
  final void Function(String error)? onLoadFailed;

  /// 广告开始展示
  final VoidCallback? onShown;

  /// 广告被点击
  final VoidCallback? onClicked;

  /// 广告关闭（插屏/激励视频关闭后触发）
  final VoidCallback? onClosed;

  /// 激励视频看完，发放奖励
  final void Function(CsAdReward reward)? onRewarded;

  const CsAdCallbacks({
    this.onLoaded,
    this.onLoadFailed,
    this.onShown,
    this.onClicked,
    this.onClosed,
    this.onRewarded,
  });
}

/// 广告插件抽象接口
///
/// 所有广告渠道（AdMob、穿山甲、优量汇等）均需实现此接口。
abstract class AdPlugin {
  /// 插件唯一标识
  String get pluginId;

  /// 初始化插件
  ///
  /// [config] 由 App 传入，内容由各插件自行定义
  Future<void> initialize(Map<String, dynamic> config);

  /// 是否已初始化
  bool get isInitialized;

  // ---------------------------------------------------------------------------
  // Banner 广告
  // ---------------------------------------------------------------------------

  /// 创建 Banner 广告 Widget
  ///
  /// [adUnitId]：广告位 ID（从广告平台后台获取）
  /// [callbacks]：事件回调
  Widget buildBannerAd({
    required String adUnitId,
    CsAdCallbacks? callbacks,
  });

  // ---------------------------------------------------------------------------
  // 插屏广告
  // ---------------------------------------------------------------------------

  /// 预加载插屏广告（建议提前调用，避免展示时等待）
  Future<void> loadInterstitialAd({
    required String adUnitId,
    CsAdCallbacks? callbacks,
  });

  /// 展示插屏广告（需先调用 [loadInterstitialAd]）
  Future<bool> showInterstitialAd({required String adUnitId});

  /// 插屏广告是否已加载完成
  bool isInterstitialAdReady({required String adUnitId});

  // ---------------------------------------------------------------------------
  // 激励视频广告
  // ---------------------------------------------------------------------------

  /// 预加载激励视频广告
  Future<void> loadRewardedAd({
    required String adUnitId,
    CsAdCallbacks? callbacks,
  });

  /// 展示激励视频广告
  Future<bool> showRewardedAd({required String adUnitId});

  /// 激励视频广告是否已加载完成
  bool isRewardedAdReady({required String adUnitId});

  // ---------------------------------------------------------------------------
  // 资源释放
  // ---------------------------------------------------------------------------

  /// 释放所有已加载的广告资源
  Future<void> dispose();
}
