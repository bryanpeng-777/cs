import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'ad_plugin.dart';
import 'admob_plugin.dart';

export 'ad_plugin.dart';
export 'admob_plugin.dart';

/// 广告管理器（插件路由层）
///
/// 统一对外暴露广告能力，支持多渠道插件并存。
/// 框架内置 [AdMobPlugin]，国内广告渠道由各 App 自行实现 [AdPlugin] 后注册。
///
/// ## 快速接入（AdMob 国际广告）
///
/// ```dart
/// await AdManager.useAdMob(testDeviceIds: ['YOUR_TEST_DEVICE_ID']);
/// final banner = AdManager.buildBannerAd(adUnitId: 'ca-app-pub-xxx/xxx');
/// ```
class AdManager {
  AdManager._();

  static final Map<String, AdPlugin> _plugins = {};
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

  /// 快捷注册 AdMob
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
  static Future<void> loadInterstitialAd({
    required String adUnitId,
    CsAdCallbacks? callbacks,
    String? pluginId,
  }) async {
    final plugin = _getPlugin(pluginId);
    await plugin?.loadInterstitialAd(adUnitId: adUnitId, callbacks: callbacks);
  }

  /// 展示插屏广告（需先调用 [loadInterstitialAd]）
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

  /// 预加载激励视频广告
  static Future<void> loadRewardedAd({
    required String adUnitId,
    CsAdCallbacks? callbacks,
    String? pluginId,
  }) async {
    final plugin = _getPlugin(pluginId);
    await plugin?.loadRewardedAd(adUnitId: adUnitId, callbacks: callbacks);
  }

  /// 展示激励视频广告
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

  static List<String> get registeredPluginIds => _plugins.keys.toList();
}
