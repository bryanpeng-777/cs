/// cs_core — CS 框架核心基座
///
/// 提供：
/// - [CsClient]：框架主入口，负责 Supabase 连接和各模块初始化
/// - [CsConfig]：全局配置对象（appId / environment / locale / urlScheme）
/// - [CsEnvironment]：运行环境枚举（dev / staging / prod）
/// - [ConfigManager]：三级缓存配置管理器（L1内存 → L2 Hive → L3 Supabase）
/// - [DataManager]：业务数据 CRUD（基于 Supabase + RLS）
/// - [StorageManager]：文件存储（用户上传 + 运营图片 CDN）
library cs_core;

export 'src/cs_client.dart';
export 'src/config/config_manager.dart';
export 'src/config/config_models.dart';
export 'src/data/data_manager.dart';
export 'src/storage/storage_manager.dart';
