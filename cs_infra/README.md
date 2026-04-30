# cs_infra — 通用 Client-Server 基础架构

零运维、AI 可操作的通用后端基础架构，以 Supabase 为核心，支持任意 Flutter App 快速接入。

## 仓库结构

```
cs_infra/
├── supabase/
│   ├── migrations/
│   │   ├── 001_config_layer.sql        # 配置层：app_configs / devices / 审计日志
│   │   ├── 002_business_layer.sql      # 业务层：business schema / 用户表
│   │   └── 003_new_app_template.sql    # 新 App 接入模板
│   └── functions/
│       └── push-notification/          # FCM 推送 Edge Function
├── mcp-server/                         # cs_admin MCP Server (Railway 部署)
│   └── src/
│       ├── index.ts                    # 服务入口
│       └── tools/                      # MCP 工具实现
│           ├── config-tools.ts         # 配置管理
│           ├── storage-tools.ts        # 图片上传
│           ├── notification-tools.ts   # 推送通知
│           └── audit-tools.ts          # 审计 / 回滚 / App 注册
├── demo/                               # Flutter Demo App（能力验证）
└── docs/
    └── integration-guide.md            # 新项目接入文档
```

## 快速开始

### 1. 初始化 Supabase

1. 登录 [Supabase Dashboard](https://supabase.com) 创建新项目
2. 进入 SQL Editor，依次执行：
   - `supabase/migrations/001_config_layer.sql`
   - `supabase/migrations/002_business_layer.sql`
3. 在 Storage 中创建两个 Bucket：
   - `configs`（Public）
   - `user-uploads`（Private）

### 2. 部署 MCP Server

1. Fork 此仓库到 GitHub
2. 登录 [Railway](https://railway.app)，新建项目 → 从 GitHub 导入
3. 选择 `mcp-server` 目录
4. 设置环境变量（参考 `mcp-server/.env.example`）
5. 部署完成后记录 URL：`https://xxx.railway.app`

### 3. 配置 Cursor MCP

编辑 `~/.cursor/mcp.json`：

```json
{
  "mcpServers": {
    "supabase": {
      "command": "npx",
      "args": ["-y", "@supabase/mcp-server-supabase@latest", "--access-token", "YOUR_TOKEN"]
    },
    "cs-admin": {
      "url": "https://your-cs-admin.railway.app/mcp"
    }
  }
}
```

### 4. 接入业务项目

参见 [docs/integration-guide.md](docs/integration-guide.md)

## 核心能力

| 能力 | 技术实现 |
|------|--------|
| 配置下发 | Supabase `app_configs` 表 + JSONB |
| 三级缓存 | L1 内存 + L2 Hive + L3 Supabase |
| 实时更新 | Supabase Realtime（WebSocket） |
| 图片 CDN | Supabase Storage |
| 推送通知 | FCM HTTP v1 API（Edge Function） |
| 用户认证 | Supabase Auth（匿名 + 邮箱 + 升级） |
| 业务数据 | `business` schema + RLS 用户隔离 |
| 审计回滚 | `config_audit_log` + Trigger |
| AI 运营 | cs_admin MCP Server（Railway） |

## SDK 仓库

Flutter SDK（`cs_framework`）独立仓库：`github.com/your-org/cs_framework`
