import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'ad_plugin.dart';
import 'admob_plugin.dart';

export 'ad_plugin.dart';
export 'admob_plugin.dart';

/// 广告管理器（插件路由层）
///
/// 统一对外暴露广告能力，支持多渠道插件并存。
/// 框架内置 [AdMobPlugin]，国内广告渠道（穿山甲、优量汇）由各 App 自行实现 [AdPlugin] 后注册。
///
/// ## 快速接入（AdMob 国际广告）
///
/// ```dart
/// await AdManager.useAdMob(
///   testDeviceIds: ['YOUR_TEST_DEVICE_ID'],   // 开发期可选
/// );
///
/// // 展示 Banner
/// final banner = AdManager.buildBannerAd(adUnitId: 'ca-app-pub-xxx/xxx');
///
/// // 预加载插屏
/// await AdManager.loadInterstitialAd(adUnitId: 'ca-app-pub-xxx/xxx');
/// // 切场景时展示
/// await AdManager.showInterstitialAd(adUnitId: 'ca-app-pub-xxx/xxx');
///
/// // 激励视频
/// await AdManager.loadRewardedAd(adUnitId: 'ca-app-pub-xxx/xxx');
/// await AdManager.showRewardedAd(
///   adUnitId: 'ca-app-pub-xxx/xxx',
///   onRewarded: (reward) => giveUserReward(reward),
/// );
/// ```
///
/// ## 接入自定义广告插件（如穿山甲）
///
/// ```dart
/// class MyPanglePlugin implements AdPlugin {
///   @override String get pluginId => 'pangle';
///   // ... 实现所有方法
/// }
///
/// await AdManager.registerPlugin(
///   MyPanglePlugin(),
///   config: { 'app_id': 'your_pangle_app_id' },
/// );
/// ```
class AdManager {
  AdManager._();

  /// 已注册的广告插件（pluginId → plugin）
  static final Map<String, AdPlugin> _plugins = {};

  /// 默认插件 ID
  static String? _defaultPluginId;

  // ---------------------------------------------------------------------------
  // 插件注册
  // ---------------------------------------------------------------------------

  /// 注册广告插件
  static Future<void> registerPlugin(
    AdPlugin plugin, {
    required Map<String, dynamic> config,
    bool? setAsDefault,
  }) async {
    await plugin.initialize(config);
    _plugins[plugin.pluginId] = plugin;

    if (_defaultPluginId == null || setAsDefault == true) {
      _defaultPluginId = plugin.pluginId;
    }

    if (kDebugMode) {
      debugPrint(
        '[AdManager] 注册插件 ${plugin.pluginId}'
        '${_defaultPluginId == plugin.pluginId ? "（默认）" : ""}',
      );
    }
  }

  /// 快捷注册 AdMob（最常用场景的简化方法）
  ///
  /// ```dart
  /// await AdManager.useAdMob(
  ///   testDeviceIds: ['YOUR_TEST_DEVICE_ID'],
  /// );
  /// ```
  static Future<void> useAdMob({List<String>? testDeviceIds}) async {
    await registerPlugin(
      AdMobPlugin(),
      config: {
        if (testDeviceIds != null) 'test_device_ids': testDeviceIds,
      },
    );
  }

  /// 是否已有插件注册
  static bool get isAvailable => _plugins.isNotEmpty;

  // ---------------------------------------------------------------------------
  // Banner 广告
  // ---------------------------------------------------------------------------

  /// 创建 Banner 广告 Widget
  ///
  /// 直接放入 Widget 树即可，自动加载和展示：
  /// ```dart
  /// Column(
  ///   children: [
  ///     // ... 页面内容
  ///     AdManager.buildBannerAd(adUnitId: 'ca-app-pub-xxx/xxx'),
  ///   ],
  /// )
  /// ```
  ///
  /// 测试广告位（开发期使用）：
  /// - iOS：'ca-app-pub-3940256099942544/2934735716'
  /// - Android：'ca-app-pub-3940256099942544/6300978111'
  static Widget buildBannerAd({
    required String adUnitId,
    CsAdCallbacks? callbacks,
    String? pluginId,
  }) {
    final plugin = _getPlugin(pluginId);
    if (plugin == null) return const SizedBox.shrink();
    return plugin.buildBannerAd(adUnitId: adUnitId, callbacks: callbacks);
  }

  // ---------------------------------------------------------------------------
  // 插屏广告
  // ---------------------------------------------------------------------------

  /// 预加载插屏广告（建议在页面初始化时调用）
  ///
  /// 测试广告位（开发期使用）：
  /// - iOS：'ca-app-pub-3940256099942544/4411468910'
  /// - Android：'ca-app-pub-3940256099942544/1033173712'
  static Future<void> loadInterstitialAd({
    required String adUnitId,
    CsAdCallbacks? callbacks,
    String? pluginId,
  }) async {
    final plugin = _getPlugin(pluginId);
    await plugin?.loadInterstitialAd(adUnitId: adUnitId, callbacks: callbacks);
  }

  /// 展示插屏广告（需先调用 [loadInterstitialAd]）
  ///
  /// 返回 true 表示成功展示，false 表示广告未就绪
  static Future<bool> showInterstitialAd({
    required String adUnitId,
    String? pluginId,
  }) async {
    final plugin = _getPlugin(pluginId);
    if (plugin == null) return false;
    return plugin.showInterstitialAd(adUnitId: adUnitId);
  }

  /// 插屏广告是否已就绪
  static bool isInterstitialAdReady({
    required String adUnitId,
    String? pluginId,
  }) {
    return _getPlugin(pluginId)?.isInterstitialAdReady(adUnitId: adUnitId) ??
        false;
  }

  // ---------------------------------------------------------------------------
  // 激励视频广告
  // ---------------------------------------------------------------------------

  /// 预加载激励视频广告（建议提前调用）
  ///
  /// 测试广告位（开发期使用）：
  /// - iOS：'ca-app-pub-3940256099942544/1712485313'
  /// - Android：'ca-app-pub-3940256099942544/5224354917'
  static Future<void> loadRewardedAd({
    required String adUnitId,
    CsAdCallbacks? callbacks,
    String? pluginId,
  }) async {
    final plugin = _getPlugin(pluginId);
    await plugin?.loadRewardedAd(adUnitId: adUnitId, callbacks: callbacks);
  }

  /// 展示激励视频广告
  ///
  /// [onRewarded]：用户看完视频后的奖励回调
  static Future<bool> showRewardedAd({
    required String adUnitId,
    void Function(CsAdReward reward)? onRewarded,
    String? pluginId,
  }) async {
    final plugin = _getPlugin(pluginId);
    if (plugin == null) return false;

    if (onRewarded != null) {
      await plugin.loadRewardedAd(
        adUnitId: adUnitId,
        callbacks: CsAdCallbacks(onRewarded: onRewarded),
      );
    }

    return plugin.showRewardedAd(adUnitId: adUnitId);
  }

  /// 激励视频广告是否已就绪
  static bool isRewardedAdReady({
    required String adUnitId,
    String? pluginId,
  }) {
    return _getPlugin(pluginId)?.isRewardedAdReady(adUnitId: adUnitId) ?? false;
  }

  // ---------------------------------------------------------------------------
  // 资源释放
  // ---------------------------------------------------------------------------

  /// 释放所有广告资源
  static Future<void> dispose() async {
    for (final plugin in _plugins.values) {
      await plugin.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // 工具方法
  // ---------------------------------------------------------------------------

  static AdPlugin? _getPlugin(String? pluginId) {
    final id = pluginId ?? _defaultPluginId;
    if (id == null) {
      if (kDebugMode) {
        debugPrint('[AdManager] 未注册任何广告插件');
      }
      return null;
    }
    final plugin = _plugins[id];
    if (plugin == null && kDebugMode) {
      debugPrint('[AdManager] 找不到插件 $id，已注册：${_plugins.keys.join(", ")}');
    }
    return plugin;
  }

  /// 获取已注册插件列表（调试用）
  static List<String> get registeredPluginIds => _plugins.keys.toList();
}
