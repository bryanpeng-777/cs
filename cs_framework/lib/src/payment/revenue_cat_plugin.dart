import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'payment_plugin.dart';

/// RevenueCat 支付插件（框架内置）
///
/// 支持 iOS App Store + Google Play 双端内购，
/// 覆盖订阅制和一次性付费两种模式。
///
/// 注册方式：
/// ```dart
/// PaymentManager.registerPlugin(
///   RevenueCatPlugin(),
///   config: {
///     'ios_api_key': 'appl_xxx',
///     'android_api_key': 'goog_xxx',
///   },
/// );
/// ```
///
/// RevenueCat 后台需提前配置：
/// 1. 创建 App（iOS + Android）
/// 2. 配置 Entitlements（如 'premium'）
/// 3. 配置 Products 并关联 App Store Connect / Google Play Console
class RevenueCatPlugin implements PaymentPlugin {
  @override
  String get pluginId => 'revenue_cat';

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    final iosKey = config['ios_api_key'] as String?;
    final androidKey = config['android_api_key'] as String?;

    String? apiKey;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      apiKey = iosKey;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      apiKey = androidKey;
    }

    if (apiKey == null || apiKey.isEmpty) {
      if (kDebugMode) {
        debugPrint('[RevenueCatPlugin] 当前平台无 API Key，跳过初始化');
      }
      return;
    }

    await Purchases.configure(PurchasesConfiguration(apiKey));

    if (kDebugMode) {
      await Purchases.setLogLevel(LogLevel.debug);
      debugPrint('[RevenueCatPlugin] 初始化完成 platform=$defaultTargetPlatform');
    }
  }

  @override
  Future<void> setUserId(String userId) async {
    try {
      await Purchases.logIn(userId);
      if (kDebugMode) {
        debugPrint('[RevenueCatPlugin] 已绑定用户 userId=$userId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RevenueCatPlugin] setUserId 失败: $e');
      }
    }
  }

  @override
  Future<void> logOut() async {
    try {
      await Purchases.logOut();
      if (kDebugMode) {
        debugPrint('[RevenueCatPlugin] 已登出');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RevenueCatPlugin] logOut 失败: $e');
      }
    }
  }

  @override
  Future<List<CsOffering>> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.all.values.map(_mapOffering).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RevenueCatPlugin] getOfferings 失败: $e');
      }
      return [];
    }
  }

  @override
  Future<CsPurchaseResult> purchase(CsPackage package) async {
    try {
      // 从 package 的 productId 找到对应的 RevenueCat Package
      final offerings = await Purchases.getOfferings();
      Package? rcPackage;
      for (final offering in offerings.all.values) {
        for (final pkg in offering.availablePackages) {
          if (pkg.storeProduct.identifier == package.product.productId) {
            rcPackage = pkg;
            break;
          }
        }
        if (rcPackage != null) break;
      }

      if (rcPackage == null) {
        return CsPurchaseResult.failed(
          '找不到产品 ${package.product.productId}，请检查 RevenueCat 后台配置，'
          '确认 productId 与 RevenueCat 后台一致',
        );
      }

      final customerInfo = await Purchases.purchasePackage(rcPackage);
      return CsPurchaseResult.succeeded(_mapEntitlements(customerInfo));
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        return CsPurchaseResult.cancelled();
      }
      return CsPurchaseResult.failed(e.name);
    } catch (e) {
      return CsPurchaseResult.failed(e.toString());
    }
  }

  @override
  Future<CsPurchaseResult> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      return CsPurchaseResult.succeeded(_mapEntitlements(customerInfo));
    } catch (e) {
      return CsPurchaseResult.failed(e.toString());
    }
  }

  @override
  Future<List<CsEntitlementInfo>> getEntitlements() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return _mapEntitlements(customerInfo);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RevenueCatPlugin] getEntitlements 失败: $e');
      }
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // 数据映射（RevenueCat 模型 → cs 统一模型）
  // ---------------------------------------------------------------------------

  CsOffering _mapOffering(Offering offering) {
    return CsOffering(
      offeringId: offering.identifier,
      description: offering.serverDescription,
      packages: offering.availablePackages.map(_mapPackage).toList(),
    );
  }

  CsPackage _mapPackage(Package pkg) {
    final product = pkg.storeProduct;
    // subscriptionPeriod 不为 null 说明是订阅类型
    final isSubscription = product.subscriptionPeriod != null;
    return CsPackage(
      packageId: pkg.identifier,
      packageType: _mapPackageType(pkg.packageType),
      product: CsProduct(
        productId: product.identifier,
        title: product.title,
        description: product.description,
        priceString: product.priceString,
        type: isSubscription
            ? CsProductType.subscription
            : CsProductType.nonConsumable,
      ),
    );
  }

  CsPackageType _mapPackageType(PackageType type) {
    switch (type) {
      case PackageType.monthly:
        return CsPackageType.monthly;
      case PackageType.annual:
        return CsPackageType.annual;
      case PackageType.lifetime:
        return CsPackageType.lifetime;
      case PackageType.weekly:
        return CsPackageType.weekly;
      default:
        return CsPackageType.unknown;
    }
  }

  List<CsEntitlementInfo> _mapEntitlements(CustomerInfo info) {
    return info.entitlements.all.values.map((e) {
      return CsEntitlementInfo(
        entitlementId: e.identifier,
        isActive: e.isActive,
        isSandbox: e.isSandbox,
        expirationDate: e.expirationDate != null
            ? DateTime.tryParse(e.expirationDate!)
            : null,
        originalPurchaseDate: DateTime.tryParse(e.originalPurchaseDate),
      );
    }).toList();
  }
}
