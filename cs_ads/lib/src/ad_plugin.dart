import 'package:flutter/widgets.dart';

/// 广告类型
enum CsAdType {
  banner,
  interstitial,
  rewarded,
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
  final VoidCallback? onLoaded;
  final void Function(String error)? onLoadFailed;
  final VoidCallback? onShown;
  final VoidCallback? onClicked;
  final VoidCallback? onClosed;
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
abstract class AdPlugin {
  String get pluginId;
  Future<void> initialize(Map<String, dynamic> config);
  bool get isInitialized;

  Widget buildBannerAd({
    required String adUnitId,
    CsAdCallbacks? callbacks,
  });

  Future<void> loadInterstitialAd({
    required String adUnitId,
    CsAdCallbacks? callbacks,
  });

  Future<bool> showInterstitialAd({required String adUnitId});
  bool isInterstitialAdReady({required String adUnitId});

  Future<void> loadRewardedAd({
    required String adUnitId,
    CsAdCallbacks? callbacks,
  });

  Future<bool> showRewardedAd({required String adUnitId});
  bool isRewardedAdReady({required String adUnitId});

  Future<void> dispose();
}
