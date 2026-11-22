# Team AI-Native Harness & Skills Template

团队通用的 **AI 原生研发约束基座**（适配 LoopForge + DeepSeek Harness `dsh` / 异构 Reviewer）。本仓库**不含任何业务代码骨架**，仅固化跨项目统一的工作流红线、领域技能、确定性门禁接口与评审模板。

## 包含资产（15 个核心文件）
- `AGENTS.md`：全局工作流铁律 + 项目专属架构红线占位区
- `Makefile` + `project.mk`：门禁接口与项目命令适配器解耦
- `.agents/skills/`：通用安全/测试技能 + 常用技术栈技能（可按项目裁剪或新增）
- `scripts/check-harness-health.sh`：校验基座完整性、Skill 命名与 `dsh` 8,192 字符截断安全线
- `scripts/check-gate-integrity.sh`：防绕过门禁脚本（拦截 `@ts-ignore`、`eslint-disable`、`.skip` 等）
- `.github/`：需求单模板、AC 证据对照 PR 模板、自适应 CI 门禁
- `docs/architecture/overview.md`：项目架构说明模板

## 基于本模板启动新项目的 3 步流程

1. **点击 GitHub `Use this template` 创建新项目仓库**，克隆后先跑通基座检查：
   ```bash
   make gate-harness
   ```
2. **按业务场景定边界**：
   - 填写 `docs/architecture/overview.md` 与 `AGENTS.md` 下半段的「项目专属架构红线」；
   - 在 `.agents/skills/` 中删除不适用本项目的技能包，或补充新领域技能（单文件严控 `< 7,800` 字符）。
3. **完成 `REQ-000` 骨架搭建**：
   - 搭建具体技术栈骨架与首条健康检查单测；
   - 在 `project.mk` 中填入 `CMD_LINT`、`CMD_TYPECHECK`、`CMD_TEST_UNIT`、`CMD_TEST_E2E` 并设置 `PROJECT_BOOTSTRAPPED := true`；
   - 在 `.github/workflows/ci.yml` 中启用对应的运行时安装步骤；
   - 执行 `make gate-mvp` 全绿后合并至受保护的 `main` 分支，接入 LoopForge 正式开发。
