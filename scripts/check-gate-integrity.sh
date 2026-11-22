#!/usr/bin/env bash
set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[anti-bypass] 当前目录尚未初始化 Git 仓库，跳过 diff 比对（建议先执行 git init）。"
  exit 0
fi

if git rev-parse --verify origin/main >/dev/null 2>&1; then
  BASE_REF="origin/main"
elif git rev-parse --verify main >/dev/null 2>&1; then
  BASE_REF="main"
elif git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
  BASE_REF="HEAD~1"
else
  echo "[anti-bypass] 初始仓库尚无历史提交，跳过 diff 比对。"
  exit 0
fi

# 仅扫描新增行（以 + 开头且排除 +++ 文件头），排除脚本自身、规则文档与自动生成类型目录
ADDED_LINES=$(git diff -U0 "$BASE_REF" -- \
  ':(exclude)scripts/check-gate-integrity.sh' \
  ':(exclude)AGENTS.md' \
  ':(exclude).agents/**' \
  ':(exclude)docs/**' \
  ':(exclude)**/types/generated/**' \
  | grep -E '^\+[^+]' || true)

if [ -z "$ADDED_LINES" ]; then
  echo "[anti-bypass] 无新增代码变更，检查通过。"
  exit 0
fi

FORBIDDEN_PATTERN='(@ts-ignore|@ts-nocheck|@ts-expect-error|eslint-disable|istanbul ignore|c8 ignore|v8 ignore|# noqa|# type: ignore|\.(only|skip)\(|xit\(|xdescribe\(|@pytest\.mark\.skip)'

MATCHES=$(echo "$ADDED_LINES" | grep -En "$FORBIDDEN_PATTERN" || true)

if [ -n "$MATCHES" ]; then
  echo "❌ [anti-bypass] 检测到疑似绕过门禁的新增代码，已阻断："
  echo "$MATCHES"
  echo ""
  echo "请修复根因（类型错误、Lint 告警或失败用例），禁止使用忽略指令或跳过测试。"
  exit 1
fi

echo "✅ [anti-bypass] 未检测到绕过门禁行为。"
