/// cs_framework — CS 框架伞包（向后兼容层）
///
/// 此包将所有子模块统一 re-export，旧版引用 `package:cs_framework/cs_framework.dart`
/// 的代码无需改动即可继续使用。
///
/// 新项目建议按需引入独立子包：
/// - `package:cs_core/cs_core.dart`   → CsClient / ConfigManager / DataManager / StorageManager
/// - `package:cs_auth/cs_auth.dart`   → AuthManager / AuthGuard
/// - `package:cs_push/cs_push.dart`   → PushManager
/// - `package:cs_payment/cs_payment.dart` → PaymentManager / RevenueCatPlugin
/// - `package:cs_ads/cs_ads.dart`     → AdManager / AdMobPlugin
library cs_framework;

export 'package:cs_core/cs_core.dart';
export 'package:cs_auth/cs_auth.dart';
export 'package:cs_push/cs_push.dart';
export 'package:cs_payment/cs_payment.dart';
export 'package:cs_ads/cs_ads.dart';
