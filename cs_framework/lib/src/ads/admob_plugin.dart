import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_plugin.dart';

/// AdMob 广告插件（框架内置）
///
/// 支持 iOS + Android 双端，覆盖 Banner / 插屏 / 激励视频三种格式。
///
/// 注册方式：
/// ```dart
/// AdManager.registerPlugin(
///   AdMobPlugin(),
///   config: {
///     // 可选：测试设备 ID 列表（开发期间防止产生无效点击）
///     'test_device_ids': ['YOUR_TEST_DEVICE_ID'],
///   },
/// );
/// ```
///
/// 广告位 ID 格式：
/// - iOS：'ca-app-pub-xxx/xxx'
/// - Android：'ca-app-pub-xxx/xxx'
/// - 测试用：AdMob 官方测试 ID（见各方法注释）
class AdMobPlugin implements AdPlugin {
  @override
  String get pluginId => 'admob';

  bool _initialized = false;

  /// 已加载的插屏广告（adUnitId → ad）
  final Map<String, InterstitialAd> _interstitialAds = {};

  /// 已加载的激励视频广告（adUnitId → ad）
  final Map<String, RewardedAd> _rewardedAds = {};

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    final testDeviceIds =
        (config['test_device_ids'] as List?)?.cast<String>() ?? [];

    await MobileAds.instance.initialize();

    if (testDeviceIds.isNotEmpty) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: testDeviceIds),
      );
    }

    _initialized = true;

    if (kDebugMode) {
      debugPrint('[AdMobPlugin] 初始化完成 testDevices=${testDeviceIds.length}');
    }
  }

  // ---------------------------------------------------------------------------
  // Banner 广告
  // ---------------------------------------------------------------------------

  /// 创建 Banner 广告 Widget
  ///
  /// 测试广告位 ID（开发期使用）：
  /// - iOS：'ca-app-pub-3940256099942544/2934735716'
  /// - Android：'ca-app-pub-3940256099942544/6300978111'
  @override
  Widget buildBannerAd({
    required String adUnitId,
    CsAdCallbacks? callbacks,
  }) {
    if (!_initialized) {
      if (kDebugMode) {
        debugPrint('[AdMobPlugin] 未初始化，无法创建 Banner');
      }
      return const SizedBox.shrink();
    }
    return _AdMobBannerWidget(adUnitId: adUnitId, callbacks: callbacks);
  }

  // ---------------------------------------------------------------------------
  // 插屏广告
  // ---------------------------------------------------------------------------

  /// 预加载插屏广告
  ///
  /// 测试广告位 ID：
  /// - iOS：'ca-app-pub-3940256099942544/4411468910'
  /// - Android：'ca-app-pub-3940256099942544/1033173712'
  @override
  Future<void> loadInterstitialAd({
    required String adUnitId,
    CsAdCallbacks? callbacks,
  }) async {
    if (!_initialized) return;

    // 已加载则跳过
    if (_interstitialAds.containsKey(adUnitId)) return;

    await InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAds[adUnitId] = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (_) => callbacks?.onShown?.call(),
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAds.remove(adUnitId);
              callbacks?.onClosed?.call();
            },
            onAdClicked: (_) => callbacks?.onClicked?.call(),
            onAdFailedToShowFullScreenContent: (_, error) {
              _interstitialAds.remove(adUnitId);
              callbacks?.onLoadFailed?.call(error.message);
            },
          );
          callbacks?.onLoaded?.call();
          if (kDebugMode) {
            debugPrint('[AdMobPlugin] 插屏广告加载完成 $adUnitId');
          }
        },
        onAdFailedToLoad: (error) {
          callbacks?.onLoadFailed?.call(error.message);
          if (kDebugMode) {
            debugPrint('[AdMobPlugin] 插屏广告加载失败 $adUnitId: ${error.message}');
          }
        },
      ),
    );
  }

  @override
  Future<bool> showInterstitialAd({required String adUnitId}) async {
    final ad = _interstitialAds[adUnitId];
    if (ad == null) {
      if (kDebugMode) {
        debugPrint('[AdMobPlugin] 插屏广告未就绪，请先调用 loadInterstitialAd');
      }
      return false;
    }
    await ad.show();
    return true;
  }

  @override
  bool isInterstitialAdReady({required String adUnitId}) =>
      _interstitialAds.containsKey(adUnitId);

  // ---------------------------------------------------------------------------
  // 激励视频广告
  // ---------------------------------------------------------------------------

  /// 预加载激励视频广告
  ///
  /// 测试广告位 ID：
  /// - iOS：'ca-app-pub-3940256099942544/1712485313'
  /// - Android：'ca-app-pub-3940256099942544/5224354917'
  @override
  Future<void> loadRewardedAd({
    required String adUnitId,
    CsAdCallbacks? callbacks,
  }) async {
    if (!_initialized) return;

    if (_rewardedAds.containsKey(adUnitId)) return;

    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAds[adUnitId] = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (_) => callbacks?.onShown?.call(),
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAds.remove(adUnitId);
              callbacks?.onClosed?.call();
            },
            onAdClicked: (_) => callbacks?.onClicked?.call(),
            onAdFailedToShowFullScreenContent: (_, error) {
              _rewardedAds.remove(adUnitId);
              callbacks?.onLoadFailed?.call(error.message);
            },
          );
          callbacks?.onLoaded?.call();
          if (kDebugMode) {
            debugPrint('[AdMobPlugin] 激励视频加载完成 $adUnitId');
          }
        },
        onAdFailedToLoad: (error) {
          callbacks?.onLoadFailed?.call(error.message);
          if (kDebugMode) {
            debugPrint('[AdMobPlugin] 激励视频加载失败 $adUnitId: ${error.message}');
          }
        },
      ),
    );
  }

  @override
  Future<bool> showRewardedAd({required String adUnitId}) async {
    final ad = _rewardedAds[adUnitId];
    if (ad == null) {
      if (kDebugMode) {
        debugPrint('[AdMobPlugin] 激励视频未就绪，请先调用 loadRewardedAd');
      }
      return false;
    }
    ad.show(
      onUserEarnedReward: (_, reward) {
        if (kDebugMode) {
          debugPrint('[AdMobPlugin] 用户获得奖励 type=${reward.type} amount=${reward.amount}');
        }
      },
    );
    return true;
  }

  @override
  bool isRewardedAdReady({required String adUnitId}) =>
      _rewardedAds.containsKey(adUnitId);

  // ---------------------------------------------------------------------------
  // 资源释放
  // ---------------------------------------------------------------------------

  @override
  Future<void> dispose() async {
    for (final ad in _interstitialAds.values) {
      ad.dispose();
    }
    for (final ad in _rewardedAds.values) {
      ad.dispose();
    }
    _interstitialAds.clear();
    _rewardedAds.clear();
  }
}

// ---------------------------------------------------------------------------
// Banner Widget（内部实现）
// ---------------------------------------------------------------------------

class _AdMobBannerWidget extends StatefulWidget {
  final String adUnitId;
  final CsAdCallbacks? callbacks;

  const _AdMobBannerWidget({required this.adUnitId, this.callbacks});

  @override
  State<_AdMobBannerWidget> createState() => _AdMobBannerWidgetState();
}

class _AdMobBannerWidgetState extends State<_AdMobBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isLoaded = true);
          widget.callbacks?.onLoaded?.call();
        },
        onAdFailedToLoad: (_, error) {
          widget.callbacks?.onLoadFailed?.call(error.message);
        },
        onAdClicked: (_) => widget.callbacks?.onClicked?.call(),
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) return const SizedBox.shrink();
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
