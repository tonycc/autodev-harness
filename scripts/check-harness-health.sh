#!/usr/bin/env bash
set -euo pipefail

# dsh 工具结果截断阈值为 8192 字符，预留安全余量
MAX_SKILL_CHARS=7800
ERRORS=0

echo "🔍 Running Harness Health Check..."

for req_file in \
  AGENTS.md \
  Makefile \
  project.mk \
  docs/architecture/overview.md \
  scripts/check-gate-integrity.sh; do
  if [ ! -f "$req_file" ]; then
    echo "❌ 缺少必需基座文件: $req_file"
    ERRORS=$((ERRORS + 1))
  fi
done

if [ ! -d ".agents/skills" ]; then
  echo "❌ 缺少技能目录: .agents/skills"
  ERRORS=$((ERRORS + 1))
else
  # dsh 仅扫描一级目录 .agents/skills/<name>/SKILL.md，检测非法深层嵌套
  NESTED=$(find .agents/skills -mindepth 3 -name "SKILL.md" 2>/dev/null || true)
  if [ -n "$NESTED" ]; then
    echo "❌ 检测到多层嵌套的 SKILL.md（仅支持一级 .agents/skills/<kebab-case>/SKILL.md）："
    echo "$NESTED"
    ERRORS=$((ERRORS + 1))
  fi

  SKILL_COUNT=0
  for skill_dir in .agents/skills/*/; do
    [ -d "$skill_dir" ] || continue
    SKILL_COUNT=$((SKILL_COUNT + 1))
    skill_name=$(basename "$skill_dir")
    skill_file="${skill_dir}SKILL.md"

    if ! echo "$skill_name" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; then
      echo "❌ 技能目录名非 kebab-case: $skill_name"
      ERRORS=$((ERRORS + 1))
    fi

    if [ ! -f "$skill_file" ]; then
      echo "❌ 技能目录缺少 SKILL.md: $skill_dir"
      ERRORS=$((ERRORS + 1))
      continue
    fi

    if ! head -n 1 "$skill_file" | grep -q '^---$'; then
      echo "❌ $skill_file 缺少 YAML frontmatter 起始分隔符 (---)"
      ERRORS=$((ERRORS + 1))
    fi

    if ! grep -Eq "^name:[[:space:]]*${skill_name}[[:space:]]*$" "$skill_file"; then
      echo "❌ $skill_file frontmatter 中的 name 与目录名不匹配（期望: $skill_name）"
      ERRORS=$((ERRORS + 1))
    fi

    if ! grep -Eq '^description:[[:space:]]*.+' "$skill_file"; then
      echo "❌ $skill_file frontmatter 缺少 description 字段"
      ERRORS=$((ERRORS + 1))
    fi

    char_count=$(wc -m < "$skill_file" | tr -d ' ')
    if [ "$char_count" -gt "$MAX_SKILL_CHARS" ]; then
      echo "❌ $skill_file 字符数超限 (${char_count} > ${MAX_SKILL_CHARS})，存在被 dsh 截断风险，请拆分细节至 references/"
      ERRORS=$((ERRORS + 1))
    else
      echo "  ✓ skill/$skill_name (${char_count}/${MAX_SKILL_CHARS} chars)"
    fi
  done

  if [ "$SKILL_COUNT" -eq 0 ]; then
    echo "❌ .agents/skills/ 下至少应保留 1 个有效技能（如 security-and-testing）"
    ERRORS=$((ERRORS + 1))
  fi
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "❌ Harness 健康度校验失败（共 ${ERRORS} 项错误）"
  exit 1
fi

echo "✅ Harness 健康度校验通过。"
