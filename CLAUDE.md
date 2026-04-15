# CS 大仓开发规范

本仓库是 cs 框架基础建设大仓，包含三个 git submodule：
- `cs_framework`：后台框架（Supabase 认证、数据、推送、配置下发）
- `cs_ui`：UI 组件库（shadcn_ui 封装）
- `cs_infra`：基础设施脚本与配置

## 开发环境自检（每次开始工作时必须执行）

**在此项目中开始任何工作前，必须先检查 git hooks 是否已安装：**

```bash
git -C cs_framework config core.hooksPath
git -C cs_ui config core.hooksPath
git -C cs_infra config core.hooksPath
```

处理规则：
- 任一命令**无输出** → 立即在该仓库执行 `make install-hooks`，告知用户「已为 <仓库名> 自动安装 hooks」
- 全部**有输出** → 静默跳过，不打扰用户

## 子仓日常工作规范

### clone 后初始化
```bash
git clone --recurse-submodules https://github.com/bryanpeng-777/cs.git
cd cs
# hooks 会由 AI 自动检测并安装，无需手动操作
```

### 更新子仓到最新
```bash
git submodule update --remote --merge
```

### 子仓开发流程
```bash
cd cs_framework       # 进入子仓
git checkout main     # 切换到分支（clone 后默认 detached HEAD）
# 正常开发、commit
# post-commit hook 自动检测框架文件变更并更新 cs-stack-onboarding SKILL.md
```

### 根仓同步子仓 commit 指针
```bash
# 子仓有新 commit 后，在根仓更新指针
cd /path/to/cs
git add cs_framework  # 或 cs_ui / cs_infra
git commit -m "chore: 更新 cs_framework 到最新 commit"
git push
```

## post-commit Hook 说明

每个子仓在以下文件变更时会自动触发 cs-stack-onboarding SKILL.md 更新：

| 子仓 | 监控文件 |
|------|---------|
| cs_framework | pubspec.yaml / lib/network/ / lib/storage/ / lib/utils/app_logger / main.dart |
| cs_ui | pubspec.yaml / lib/src/components/ / lib/src/theme/ |
| cs_infra | pubspec.yaml / SKILL.md / scripts/ |

Hook 脚本位于各子仓的 `scripts/post-commit.sh`，通过 `make install-hooks` 安装后生效。
