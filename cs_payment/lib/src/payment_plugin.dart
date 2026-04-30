// 支付插件抽象接口
//
// 框架内置 RevenueCatPlugin（iOS App Store + Google Play）。
// 国内支付（微信支付、支付宝）由各 App 自行实现此接口后注册到 PaymentManager。

/// 单个可购买产品
class CsProduct {
  final String productId;
  final String title;
  final String description;
  final String priceString;
  final CsProductType type;

  const CsProduct({
    required this.productId,
    required this.title,
    required this.description,
    required this.priceString,
    required this.type,
  });
}

/// 产品类型
enum CsProductType {
  nonConsumable,
  consumable,
  subscription,
}

/// 购买套餐（一个套餐可包含多个产品，如月订阅 + 年订阅）
class CsOffering {
  final String offeringId;
  final String? description;
  final List<CsPackage> packages;

  const CsOffering({
    required this.offeringId,
    this.description,
    required this.packages,
  });
}

/// 购买包（套餐内的单个选项）
class CsPackage {
  final String packageId;
  final CsProduct product;
  final CsPackageType packageType;

  const CsPackage({
    required this.packageId,
    required this.product,
    required this.packageType,
  });
}

/// 包类型
enum CsPackageType {
  monthly,
  annual,
  lifetime,
  weekly,
  custom,
  unknown,
}

/// 用户当前拥有的权益
class CsEntitlementInfo {
  final String entitlementId;
  final bool isActive;
  final bool isSandbox;
  final DateTime? expirationDate;
  final DateTime? originalPurchaseDate;

  const CsEntitlementInfo({
    required this.entitlementId,
    required this.isActive,
    required this.isSandbox,
    this.expirationDate,
    this.originalPurchaseDate,
  });
}

/// 购买结果
class CsPurchaseResult {
  final bool success;
  final bool userCancelled;
  final String? errorMessage;
  final List<CsEntitlementInfo> entitlements;

  const CsPurchaseResult({
    required this.success,
    required this.userCancelled,
    this.errorMessage,
    this.entitlements = const [],
  });

  factory CsPurchaseResult.cancelled() => const CsPurchaseResult(
        success: false,
        userCancelled: true,
      );

  factory CsPurchaseResult.failed(String message) => CsPurchaseResult(
        success: false,
        userCancelled: false,
        errorMessage: message,
      );

  factory CsPurchaseResult.succeeded(List<CsEntitlementInfo> entitlements) =>
      CsPurchaseResult(
        success: true,
        userCancelled: false,
        entitlements: entitlements,
      );
}

/// 支付插件抽象接口
abstract class PaymentPlugin {
  String get pluginId;
  Future<void> initialize(Map<String, dynamic> config);
  Future<void> setUserId(String userId);
  Future<void> logOut();
  Future<List<CsOffering>> getOfferings();
  Future<CsPurchaseResult> purchase(CsPackage package);
  Future<CsPurchaseResult> restorePurchases();
  Future<List<CsEntitlementInfo>> getEntitlements();
}
