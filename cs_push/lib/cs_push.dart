/// cs_push — CS 框架推送通知模块
///
/// 提供：
/// - [PushManager]：FCM token 注册、前台/后台消息接收、silent push 处理
///
/// 依赖：cs_core + cs_auth（用于设备 ID 获取）
library cs_push;

export 'src/push_manager.dart';
