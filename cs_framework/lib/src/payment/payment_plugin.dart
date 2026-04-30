// 支付插件抽象接口
//
// 框架内置 RevenueCatPlugin（iOS App Store + Google Play）。
// 国内支付（微信支付、支付宝）由各 App 自行实现此接口后注册到 PaymentManager。
//
// 实现示例：
//   class MyWechatPayPlugin implements PaymentPlugin {
//     @override String get pluginId => 'wechat_pay';
//     @override Future<void> initialize(Map<String, dynamic> config) async { ... }
//     // ... 实现其他方法
//   }
//   PaymentManager.registerPlugin(MyWechatPayPlugin());

/// 单个可购买产品
class CsProduct {
  final String productId;
  final String title;
  final String description;
  final String priceString;

  /// 产品类型
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
  /// 一次性购买（永久解锁）
  nonConsumable,

  /// 消耗型（如金币、次数）
  consumable,

  /// 订阅
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

  /// 包类型（月订阅、年订阅、终身等）
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
  /// 权益 ID（如 'premium'、'pro'）
  final String entitlementId;

  /// 是否当前有效（订阅未过期 / 已永久购买）
  final bool isActive;

  /// 是否为沙盒环境购买（测试环境）
  final bool isSandbox;

  /// 过期时间（订阅类型有值；一次性购买为 null）
  final DateTime? expirationDate;

  /// 原始购买时间
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
  /// 是否成功
  final bool success;

  /// 是否被用户取消（非错误，不需要弹错误提示）
  final bool userCancelled;

  /// 失败原因（success 为 false 且 userCancelled 为 false 时有值）
  final String? errorMessage;

  /// 购买成功后更新的权益列表
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
///
/// 所有支付渠道（RevenueCat、微信支付、支付宝等）均需实现此接口。
abstract class PaymentPlugin {
  /// 插件唯一标识，用于注册和调试
  String get pluginId;

  /// 初始化插件
  ///
  /// [config] 由 App 传入，内容由各插件自行定义（如 API Key、商户号等）
  Future<void> initialize(Map<String, dynamic> config);

  /// 绑定用户 ID（用户登录后调用，将购买记录与账号关联）
  ///
  /// 支持此功能的插件应实现；不支持可空实现
  Future<void> setUserId(String userId);

  /// 登出（用户退出登录后调用）
  Future<void> logOut();

  /// 获取可购买的套餐列表
  Future<List<CsOffering>> getOfferings();

  /// 发起购买
  Future<CsPurchaseResult> purchase(CsPackage package);

  /// 恢复购买（用户换手机 / 重装 App 时调用）
  Future<CsPurchaseResult> restorePurchases();

  /// 获取当前用户所有权益
  Future<List<CsEntitlementInfo>> getEntitlements();
}
