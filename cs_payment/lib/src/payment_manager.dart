import 'package:flutter/foundation.dart';

import 'payment_plugin.dart';
import 'revenue_cat_plugin.dart';

export 'payment_plugin.dart';
export 'revenue_cat_plugin.dart';

/// 支付管理器（插件路由层）
///
/// 统一对外暴露支付能力，支持多渠道插件并存。
/// 框架内置 [RevenueCatPlugin]，国内支付渠道由各 App 自行实现 [PaymentPlugin] 后注册。
///
/// ## 快速接入（RevenueCat 国际支付）
///
/// ```dart
/// await PaymentManager.useRevenueCat(
///   iosApiKey: 'appl_xxx',
///   androidApiKey: 'goog_xxx',
/// );
/// final isPremium = await PaymentManager.hasEntitlement('premium');
/// ```
class PaymentManager {
  PaymentManager._();

  static final Map<String, PaymentPlugin> _plugins = {};
  static String? _defaultPluginId;

  // ---------------------------------------------------------------------------
  // 插件注册
  // ---------------------------------------------------------------------------

  /// 注册支付插件
  static Future<void> registerPlugin(
    PaymentPlugin plugin, {
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
        '[PaymentManager] 注册插件 ${plugin.pluginId}'
        '${_defaultPluginId == plugin.pluginId ? "（默认）" : ""}',
      );
    }
  }

  /// 快捷注册 RevenueCat
  static Future<void> useRevenueCat({
    String? iosApiKey,
    String? androidApiKey,
  }) async {
    await registerPlugin(
      RevenueCatPlugin(),
      config: {
        if (iosApiKey != null) 'ios_api_key': iosApiKey,
        if (androidApiKey != null) 'android_api_key': androidApiKey,
      },
    );
  }

  /// 是否已有插件注册
  static bool get isAvailable => _plugins.isNotEmpty;

  // ---------------------------------------------------------------------------
  // 用户绑定
  // ---------------------------------------------------------------------------

  /// 绑定用户 ID（所有已注册插件均同步绑定）
  static Future<void> setUserId(String userId) async {
    for (final plugin in _plugins.values) {
      await plugin.setUserId(userId);
    }
  }

  /// 登出（所有已注册插件均同步登出）
  static Future<void> logOut() async {
    for (final plugin in _plugins.values) {
      await plugin.logOut();
    }
  }

  // ---------------------------------------------------------------------------
  // 核心购买 API
  // ---------------------------------------------------------------------------

  /// 获取可购买套餐列表
  static Future<List<CsOffering>> getOfferings({String? pluginId}) async {
    final plugin = _getPlugin(pluginId);
    if (plugin == null) return [];
    return plugin.getOfferings();
  }

  /// 发起购买
  static Future<CsPurchaseResult> purchase(
    CsPackage package, {
    String? pluginId,
  }) async {
    final plugin = _getPlugin(pluginId);
    if (plugin == null) {
      return CsPurchaseResult.failed('未注册任何支付插件，请先调用 PaymentManager.registerPlugin');
    }
    return plugin.purchase(package);
  }

  /// 恢复购买
  static Future<CsPurchaseResult> restorePurchases({String? pluginId}) async {
    final plugin = _getPlugin(pluginId);
    if (plugin == null) {
      return CsPurchaseResult.failed('未注册任何支付插件');
    }
    return plugin.restorePurchases();
  }

  /// 获取当前用户所有权益
  static Future<List<CsEntitlementInfo>> getEntitlements({
    String? pluginId,
  }) async {
    if (pluginId != null) {
      final plugin = _getPlugin(pluginId);
      return plugin?.getEntitlements() ?? Future.value([]);
    }
    final all = <CsEntitlementInfo>[];
    for (final plugin in _plugins.values) {
      all.addAll(await plugin.getEntitlements());
    }
    return all;
  }

  /// 检查用户是否拥有指定权益
  static Future<bool> hasEntitlement(
    String entitlementId, {
    String? pluginId,
  }) async {
    final entitlements = await getEntitlements(pluginId: pluginId);
    return entitlements.any(
      (e) => e.entitlementId == entitlementId && e.isActive,
    );
  }

  // ---------------------------------------------------------------------------
  // 工具方法
  // ---------------------------------------------------------------------------

  static PaymentPlugin? _getPlugin(String? pluginId) {
    final id = pluginId ?? _defaultPluginId;
    if (id == null) {
      if (kDebugMode) {
        debugPrint('[PaymentManager] 未注册任何支付插件');
      }
      return null;
    }
    final plugin = _plugins[id];
    if (plugin == null && kDebugMode) {
      debugPrint('[PaymentManager] 找不到插件 $id，已注册：${_plugins.keys.join(", ")}');
    }
    return plugin;
  }

  static List<String> get registeredPluginIds => _plugins.keys.toList();
}
