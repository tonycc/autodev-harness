# ==============================================================================
# 项目门禁适配器（由具体项目在 REQ-000 搭建骨架时填写）
#
# 说明：
# - 保持 PROJECT_BOOTSTRAPPED := false 时，GitHub CI 仅运行 `make gate-harness`
# - 搭建完骨架并填好下方命令后，改为 PROJECT_BOOTSTRAPPED := true，CI 将自动切换为 `make gate-mvp`
# - 无论标志位为何值，显式执行 `make gate-mvp` 时未填写的命令都会报错退出，防止空门禁假绿灯
# ==============================================================================

PROJECT_BOOTSTRAPPED := false

CMD_LINT          :=
CMD_TYPECHECK     :=
CMD_TEST_UNIT     :=
CMD_TEST_E2E      :=
CMD_LICENSE_CHECK :=
CMD_DOCS_VERIFY   :=

# --- 示例：TypeScript 全栈 Monorepo (Vue 3 + Element Plus + NestJS) ---
# PROJECT_BOOTSTRAPPED := true
# CMD_LINT          := pnpm -r lint
# CMD_TYPECHECK     := pnpm --filter @repo/shared build && pnpm -r typecheck
# CMD_TEST_UNIT     := pnpm --filter @repo/api test:cov -- --coverageReporters=json-summary --coverageDirectory=../../artifacts/cov-api && pnpm --filter @repo/web test:unit -- --run --reporter=json --outputFile=../../artifacts/web-unit-report.json
# CMD_TEST_E2E      := docker compose -f deploy/compose.test.yaml up -d --wait && pnpm --filter @repo/api test:e2e -- --json --outputFile=../../artifacts/api-e2e-report.json; status=$$?; docker compose -f deploy/compose.test.yaml down -v; exit $$status
# CMD_LICENSE_CHECK := npx --yes license-checker-rseidelsohn --production --failOn "AGPL;GPL-3.0"
