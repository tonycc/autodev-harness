import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = path.resolve(__dirname, '..');
const CONFIG_PATH = path.join(ROOT_DIR, 'harness.config.json');

function loadConfig() {
  if (!fs.existsSync(CONFIG_PATH)) {
    console.error('❌ 缺少基座配置文件: harness.config.json');
    process.exit(1);
  }
  try {
    return JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  } catch (err) {
    console.error(`❌ harness.config.json 解析失败: ${err.message}`);
    process.exit(1);
  }
}

class GateFailure extends Error {
  constructor(code) {
    super(`exit ${code}`);
    this.code = code || 1;
  }
}

function ensureArtifactsDir(config) {
  fs.mkdirSync(path.join(ROOT_DIR, config.artifactsDir || 'artifacts'), {
    recursive: true,
  });
}

function runNodeScript(scriptName, extraArgs = []) {
  const res = spawnSync(
    process.execPath,
    [path.join(__dirname, scriptName), ...extraArgs],
    { cwd: ROOT_DIR, stdio: 'inherit' },
  );
  if (res.status !== 0) throw new GateFailure(res.status ?? 1);
}

// 密钥扫描仅提示、不阻断：未安装或发现疑似泄露都只输出告警，由人工在合并前确认
function runSecretScan(config) {
  ensureArtifactsDir(config);
  const reportPath = path.join(config.artifactsDir || 'artifacts', 'gitleaks-report.json');
  const res = spawnSync(
    'gitleaks',
    ['detect', '--source', '.', '--no-banner', '--redact', '--report-path', reportPath],
    { cwd: ROOT_DIR, stdio: 'inherit' },
  );
  if (res.error && res.error.code === 'ENOENT') {
    console.log('⚠️ [secret-scan] 未检测到 gitleaks，已跳过密钥扫描。');
    return;
  }
  if (res.status !== 0) {
    console.log(
      `⚠️ [secret-scan] gitleaks 发现疑似密钥泄露（不阻断门禁），详情见 ${reportPath}，请在合并前人工确认。`,
    );
  }
}

function runConfiguredCommand(config, key, { optional = false } = {}) {
  const cmd = (config.commands?.[key] ?? '').trim();
  if (!cmd) {
    if (optional) {
      console.log(`⚠️ harness.config.json 未配置 commands.${key}，已跳过`);
      return;
    }
    console.error(`❌ 请先在 harness.config.json 的 commands.${key} 中绑定真实命令`);
    throw new GateFailure(1);
  }
  console.log(`\n▶ [${key}] ${cmd}`);
  const res = spawnSync(cmd, { cwd: ROOT_DIR, stdio: 'inherit', shell: true });
  if (res.status !== 0) throw new GateFailure(res.status ?? 1);
}

// 组合门禁：逐项执行全部步骤，最后统一汇总失败项，便于 Agent 一轮修完所有问题
function runAll(name, steps) {
  const failed = [];
  for (const step of steps) {
    try {
      TARGETS[step]();
    } catch (err) {
      if (!(err instanceof GateFailure)) throw err;
      failed.push(step);
      console.error(`\n✖ [${step}] 未通过（退出码 ${err.code}），继续执行后续检查...`);
    }
  }
  if (failed.length > 0) {
    console.error(`\n❌ ${name} 未通过，失败项: ${failed.join(', ')}`);
    throw new GateFailure(1);
  }
}

const config = loadConfig();
const target = process.argv[2];
const extraArgs = process.argv.slice(3);

// gate-harness：维护基座 / 未建骨架时使用；gate-mvp：Developer 日常门禁（不含 Skill 格式检查）
const HARNESS_STEPS = ['harness-health', 'secret-scan', 'anti-bypass'];
const MVP_STEPS = ['secret-scan', 'anti-bypass', 'lint', 'typecheck', 'test-unit'];
const ALL_STEPS = [...MVP_STEPS, 'license-check', 'test-e2e'];

const TARGETS = {
  'harness-health': () => runNodeScript('check-harness-health.mjs'),
  'secret-scan': () => runSecretScan(config),
  'anti-bypass': () => runNodeScript('check-gate-integrity.mjs'),
  'check-review': () => runNodeScript('check-review.mjs', extraArgs),
  'gate-harness': () => {
    runAll('gate-harness', HARNESS_STEPS);
    console.log('\n✅ gate-harness 全部通过');
  },
  lint: () => runConfiguredCommand(config, 'lint'),
  typecheck: () => runConfiguredCommand(config, 'typecheck'),
  'test-unit': () => {
    ensureArtifactsDir(config);
    runConfiguredCommand(config, 'testUnit');
  },
  'test-e2e': () => {
    ensureArtifactsDir(config);
    runConfiguredCommand(config, 'testE2e');
  },
  'license-check': () =>
    runConfiguredCommand(config, 'licenseCheck', { optional: true }),
  'gate-mvp': () => {
    runAll('gate-mvp', MVP_STEPS);
    console.log(`\n✅ gate-mvp 全部通过，证据已输出至 ${config.artifactsDir || 'artifacts'}/`);
  },
  'gate-all': () => {
    runAll('gate-all', ALL_STEPS);
    console.log(`\n✅ gate-all 全部通过，证据已输出至 ${config.artifactsDir || 'artifacts'}/`);
  },
};

if (!target || !Object.hasOwn(TARGETS, target)) {
  console.error('用法: node scripts/gate.mjs <target>\n可用: ' + Object.keys(TARGETS).join(', '));
  process.exit(1);
}

try {
  TARGETS[target]();
} catch (err) {
  if (err instanceof GateFailure) process.exit(err.code);
  throw err;
}
