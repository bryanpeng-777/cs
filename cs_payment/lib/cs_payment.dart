/// cs_payment — CS 框架支付模块
///
/// 提供：
/// - [PaymentManager]：支付管理器（插件路由层）
/// - [RevenueCatPlugin]：RevenueCat 内置插件（iOS App Store + Google Play）
/// - [PaymentPlugin]：自定义支付插件接口
/// - [CsOffering] / [CsPackage] / [CsProduct] / [CsEntitlementInfo] / [CsPurchaseResult]：数据模型
///
/// 依赖：cs_core
library cs_payment;

export 'src/payment_manager.dart';
