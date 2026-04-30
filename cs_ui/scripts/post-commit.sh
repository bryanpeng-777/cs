#!/bin/bash
# cs_ui post-commit hook
# 监测 UI 框架相关文件变更，自动更新 cs-stack-onboarding 和 cs-stack-checker SKILL.md

ONBOARDING_SKILL="/Users/bryanpeng/.claude/skills/cs-stack-onboarding/SKILL.md"
CHECKER_SKILL="/Users/bryanpeng/.claude/skills/cs-stack-checker/SKILL.md"
WATCH_PATTERNS="pubspec\.yaml|lib/src/components/|lib/src/theme/|lib/src/auth/"

CHANGED=$(git show --name-only --format="" HEAD 2>/dev/null)
RELEVANT=$(echo "$CHANGED" | grep -E "$WATCH_PATTERNS" || true)

if [ -z "$RELEVANT" ]; then
  exit 0
fi

echo "🔄 UI 框架文件变更，正在更新接入技能..."
echo "   变更文件：$(echo $RELEVANT | tr '\n' ' ')"

DIFF_SUMMARY=$(git show HEAD -- $RELEVANT 2>/dev/null)

# 1. 更新 cs-stack-onboarding（如何接入）
claude --print \
  "以下是 cs_ui 仓库的最新代码变更（只包含 UI 框架核心文件）。
请根据变更内容更新 cs-stack-onboarding 的 SKILL.md（路径：$ONBOARDING_SKILL），
重点更新：UI 组件名称、使用方式、CLAUDE.md 生成模板中的 UI 规范部分、新组件的接入步骤。
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
  "以下是 cs_ui 仓库的最新代码变更（只包含 UI 框架核心文件）。
请根据变更内容更新 cs-stack-checker 的 SKILL.md（路径：$CHECKER_SKILL），
重点更新：
- 若新增了 UI 组件（如新的 Cs* Widget），在 F. 登录模块 或 G. UI 组件 中补充对应检查项
- 若修改了组件 API，更新对应检查项的验收标准
- 若废弃了某个组件，将相关检查项标记为已废弃或移除
保持 SKILL.md 整体结构不变，只修改受影响的部分。

变更文件：
$RELEVANT

Diff：
$DIFF_SUMMARY" \
  --allowedTools "Read,Write,Glob,Grep" 2>/dev/null \
  && echo "✅ cs-stack-checker SKILL.md 已更新" \
  || echo "⚠️  cs-stack-checker 更新失败，请在 Cursor 中运行 evolve 技能"
