#!/bin/bash
# cs_framework post-commit hook
# 监测框架核心文件变更，自动更新 cs-stack-onboarding 和 cs-stack-checker SKILL.md

ONBOARDING_SKILL="/Users/bryanpeng/.claude/skills/cs-stack-onboarding/SKILL.md"
CHECKER_SKILL="/Users/bryanpeng/.claude/skills/cs-stack-checker/SKILL.md"
WATCH_PATTERNS="pubspec\.yaml|lib/network/|lib/storage/|lib/utils/app_logger|lib/src/auth/|main\.dart"

# 获取本次 commit 变更的文件列表
CHANGED=$(git show --name-only --format="" HEAD 2>/dev/null)
RELEVANT=$(echo "$CHANGED" | grep -E "$WATCH_PATTERNS" || true)

if [ -z "$RELEVANT" ]; then
  exit 0
fi

echo "🔄 框架文件变更，正在更新接入技能..."
echo "   变更文件：$(echo $RELEVANT | tr '\n' ' ')"

# 收集 diff 摘要
DIFF_SUMMARY=$(git show HEAD -- $RELEVANT 2>/dev/null)

# 1. 更新 cs-stack-onboarding（如何接入）
claude --print \
  "以下是 cs_framework 仓库的最新代码变更（只包含框架核心文件）。
请根据变更内容更新 cs-stack-onboarding 的 SKILL.md（路径：$ONBOARDING_SKILL），
重点更新：版本号、代码模板、CLAUDE.md 生成模板中的代码示例、新模块的接入步骤。
保持 SKILL.md 整体结构不变，只修改受影响的部分。

变更文件：
$RELEVANT

Diff：
$DIFF_SUMMARY" \
  --allowedTools "Read,Write,Glob,Grep" 2>/dev/null \
  && echo "✅ cs-stack-onboarding SKILL.md 已更新" \
  || echo "⚠️  cs-stack-onboarding 更新失败，请在 Cursor 中运行 evolve 技能"

# 2. 更新 cs-stack-checker（如何检查接入完整性）
claude --print \
  "以下是 cs_framework 仓库的最新代码变更（只包含框架核心文件）。
请根据变更内容更新 cs-stack-checker 的 SKILL.md（路径：$CHECKER_SKILL），
重点更新：
- 若新增了框架模块（如新的 Manager 类），在对应检查类别（E. 后台接入 或新增类别）中补充检查项
- 若修改了 API 或初始化方式，更新对应检查项的验收标准和检查命令
- 若废弃了某个 API，将相关检查项标记为已废弃或移除
保持 SKILL.md 整体结构不变，只修改受影响的部分。

变更文件：
$RELEVANT

Diff：
$DIFF_SUMMARY" \
  --allowedTools "Read,Write,Glob,Grep" 2>/dev/null \
  && echo "✅ cs-stack-checker SKILL.md 已更新" \
  || echo "⚠️  cs-stack-checker 更新失败，请在 Cursor 中运行 evolve 技能"
