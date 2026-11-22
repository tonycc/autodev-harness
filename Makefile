SHELL := /usr/bin/env bash
.PHONY: prepare harness-health secret-scan anti-bypass lint typecheck test-unit test-e2e license-check docs-verify gate-harness gate-mvp gate-all

ARTIFACTS_DIR := artifacts
PROJECT_BOOTSTRAPPED := false

-include project.mk

prepare:
	@mkdir -p $(ARTIFACTS_DIR)

# ------------------------------------------------------------------------------
# 语言无关的基座门禁（模板仓库本身及新项目搭骨架前可直接运行）
# ------------------------------------------------------------------------------
harness-health:
	./scripts/check-harness-health.sh

secret-scan:
	@if command -v gitleaks >/dev/null 2>&1; then \
		gitleaks detect --source . --no-banner --redact; \
	else \
		echo "❌ 未检测到 gitleaks，请先安装（macOS: brew install gitleaks / Linux: 安装 gitleaks 二进制）"; \
		exit 1; \
	fi

anti-bypass:
	./scripts/check-gate-integrity.sh

gate-harness: harness-health secret-scan anti-bypass
	@echo "✅ gate-harness 通过"

# ------------------------------------------------------------------------------
# 项目适配钩子（必须在 project.mk 中绑定真实命令；未绑定则显式失败，杜绝假绿灯）
# ------------------------------------------------------------------------------
lint:
	@test -n "$(strip $(CMD_LINT))" || { echo "❌ 请在 project.mk 中定义 CMD_LINT"; exit 1; }
	$(CMD_LINT)

typecheck:
	@test -n "$(strip $(CMD_TYPECHECK))" || { echo "❌ 请在 project.mk 中定义 CMD_TYPECHECK"; exit 1; }
	$(CMD_TYPECHECK)

test-unit: prepare
	@test -n "$(strip $(CMD_TEST_UNIT))" || { echo "❌ 请在 project.mk 中定义 CMD_TEST_UNIT"; exit 1; }
	$(CMD_TEST_UNIT)

test-e2e: prepare
	@test -n "$(strip $(CMD_TEST_E2E))" || { echo "❌ 请在 project.mk 中定义 CMD_TEST_E2E"; exit 1; }
	$(CMD_TEST_E2E)

license-check:
	@if [ -z "$(strip $(CMD_LICENSE_CHECK))" ]; then \
		echo "⚠️ project.mk 未配置 CMD_LICENSE_CHECK，跳过许可证扫描"; \
	else \
		$(CMD_LICENSE_CHECK); \
	fi

docs-verify:
	@if [ -z "$(strip $(CMD_DOCS_VERIFY))" ]; then \
		echo "⚠️ project.mk 未配置 CMD_DOCS_VERIFY，跳过文档可执行性校验"; \
	else \
		$(CMD_DOCS_VERIFY); \
	fi

# ------------------------------------------------------------------------------
# LoopForge SOP 与 CI 统一调用的标准门禁入口
# ------------------------------------------------------------------------------
gate-mvp: gate-harness lint typecheck test-unit
	@echo "✅ gate-mvp 全部通过，证据已输出至 $(ARTIFACTS_DIR)/"

gate-all: gate-mvp license-check test-e2e
	@echo "✅ gate-all 全部通过，证据已输出至 $(ARTIFACTS_DIR)/"
