/// cs_ads — CS 框架广告模块
///
/// 提供：
/// - [AdManager]：广告管理器（插件路由层）
/// - [AdMobPlugin]：AdMob 内置插件（Banner / 插屏 / 激励视频）
/// - [AdPlugin]：自定义广告插件接口
/// - [CsAdCallbacks] / [CsAdReward] / [CsAdType] / [CsAdState]：广告回调与类型
///
/// 依赖：cs_core
library cs_ads;

export 'src/ad_manager.dart';
