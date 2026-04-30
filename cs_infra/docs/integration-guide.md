# cs_framework 新项目接入指南

## 前提：基础设施已搭建（一次性）

确认以下基础设施已就绪：

- [ ] Supabase 项目已创建（dev + prod）
- [ ] `001_config_layer.sql` 已执行
- [ ] `002_business_layer.sql` 已执行
- [ ] Supabase Storage 已创建 `configs` 和 `user-uploads` 两个 Bucket
- [ ] cs_admin MCP Server 已部署到 Railway
- [ ] Cursor 的 `~/.cursor/mcp.json` 已配置

---

## 接入步骤

### Step 1：注册新 App（1 分钟）

在 Cursor 中告诉 AI：

```
帮我注册一个新 App，app_id = "[your-app-id]"
```

AI 会调用 `register_app` 工具完成注册。

或手动在 Supabase Dashboard SQL Editor 执行：

```sql
INSERT INTO config_sync_versions (app_id, environment, version)
VALUES ('[your-app-id]', 'dev', 0), ('[your-app-id]', 'prod', 0)
ON CONFLICT DO NOTHING;
```

---

### Step 2：创建 Flutter 项目，引入 SDK（10 分钟）

**pubspec.yaml**：

```yaml
dependencies:
  cs_framework:
    git:
      url: https://github.com/your-org/cs_framework.git
      ref: v1.0.0
```

执行：

```bash
flutter pub get
```

---

### Step 3：初始化 SDK（5 分钟）

**lib/main.dart**：

```dart
import 'package:cs_framework/cs_framework.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase（推送通知需要）
  await Firebase.initializeApp();

  // cs_framework 初始化
  await CsClient.initialize(
    supabaseUrl: 'https://your-project.supabase.co',
    supabaseAnonKey: 'your-anon-key',
    appId: 'your-app-id',
    environment: CsEnvironment.prod,
  );

  runApp(MyApp());
}
```

---

### Step 4：提供默认配置（10 分钟）

在 `assets/default_configs.json` 填写离线兜底配置：

```json
{
  "_comment": "无网络时的默认值",
  "home_banner_image": {
    "url": "assets/images/default_banner.png"
  },
  "enable_new_feature": {
    "enabled": false
  }
}
```

**pubspec.yaml** 声明：

```yaml
flutter:
  assets:
    - assets/default_configs.json
    - assets/images/
```

---

### Step 5：建业务表（按需，15 分钟）

如果 App 需要存用户数据，复制 `003_new_app_template.sql` 并修改后在 Supabase SQL Editor 执行。

无用户数据（纯配置下发）可跳过此步。

---

### Step 6：初始化配置数据（AI 操作，10 分钟）

在 Cursor 中告诉 AI：

```
帮我初始化 [your-app-id] 的配置：
1. 上传这张图片作为 home_banner_image（附件：banner.png）
2. 设置 enable_new_feature 为 false
3. 创建一个 items_list 配置，包含以下数据：...
```

---

### Step 7：写业务代码

```dart
// 读取配置（AI 下发的通用配置）
final bannerUrl = await ConfigManager.getString('home_banner_image');
final isEnabled = await ConfigManager.getBool('enable_new_feature');
final items = await ConfigManager.getList('items_list');

// 监听配置实时变更
ConfigManager.listen('home_banner_image').listen((event) {
  setState(() => bannerUrl = event.newValue['url']);
});

// 读写用户业务数据
await DataManager.insert('my_table', {'field': 'value'});
final list = await DataManager.select('my_table', orderBy: 'created_at');

// 用户认证
final isAnonymous = AuthManager.isAnonymous;
await AuthManager.linkWithEmail('user@example.com', 'password');

// 上传用户文件
final url = await StorageManager.uploadUserFile(imageFile);
```

---

## Cursor MCP 配置

在 `~/.cursor/mcp.json` 添加：

```json
{
  "mcpServers": {
    "supabase": {
      "command": "npx",
      "args": ["-y", "@supabase/mcp-server-supabase@latest", "--access-token", "YOUR_SUPABASE_ACCESS_TOKEN"]
    },
    "cs-admin": {
      "url": "https://your-cs-admin-mcp.railway.app/mcp"
    }
  }
}
```

---

## 日常运营（无需写代码）

```
换 Banner 图片：
  "帮我把 [app-id] 的 home_banner_image 换成这张图（附件）"

开关功能：
  "把 [app-id] 的 enable_payment 关闭"

查看配置历史：
  "查看 [app-id] 的 home_banner_image 最近 10 次变更"

回滚配置：
  "把 [app-id] 的 home_banner_image 回滚到昨天的版本"

发送推送：
  "给 [app-id] 的用户发送推送：标题'新版本上线'，内容'快来体验新功能'"
```

---

## 接入时间汇总

| 步骤 | 时间 |
|------|------|
| Step 1 注册 App | 1 分钟 |
| Step 2 引入 SDK | 10 分钟 |
| Step 3 初始化 | 5 分钟 |
| Step 4 默认配置 | 10 分钟 |
| Step 5 建业务表（可选）| 15 分钟 |
| Step 6 AI 初始化数据 | 10 分钟 |
| **合计** | **约 50 分钟** |
