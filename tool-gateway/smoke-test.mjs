#!/usr/bin/env node
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const TOOL_GATEWAY_DIR = path.dirname(fileURLToPath(import.meta.url));

const DEFAULT_QUERIES = [
  {
    name: 'travel',
    toolId: 'travel.search',
    prompt: '我明天要从北京去上海，帮我搜索出行方案',
    expect: {
      status: 'ready',
      components: ['TravelOptions'],
      dataPath: '/travelOptions',
      contains: ['高铁 · 12306', '飞机 · 飞常准']
    }
  },
  {
    name: 'flight',
    toolId: 'flight.search',
    prompt: '帮我查明天北京到上海航班',
    expect: {
      status: 'ready',
      components: ['FlightBoard'],
      dataPath: '/flights',
      allowProviderError: {
        status: 'needs_input',
        components: ['ErrorNotice'],
        anyText: ['飞常准返回 HTTP', '飞常准 Key 或参数需要检查', '飞常准查询参数不足']
      }
    }
  },
  {
    name: 'train',
    toolId: 'train.search',
    prompt: '帮我查明天北京到上海高铁票',
    expect: {
      status: 'ready',
      components: ['TrainOptions'],
      dataPath: '/trains',
      contains: ['多展示一些', 'client_show_more']
    }
  },
  {
    name: 'train_cross_border_time',
    toolId: 'train.search',
    prompt: '帮我查询深圳北出发到香港西九龙明天晚上六点之后的高铁',
    expect: {
      status: 'ready',
      components: ['TrainOptions'],
      dataPath: '/trains',
      contains: ['18:00', 'client_sort_fastest']
    }
  },
  {
    name: 'coffee',
    toolId: 'food.search',
    prompt: '帮我查附近咖啡',
    expect: {
      status: 'ready',
      components: ['FoodChoices'],
      dataPath: '/foods'
    }
  }
];

const FORBIDDEN_SYNTHETIC_MARKERS = [
  'local://aiphone-tools',
  '本机工具',
  '本机模式',
  '高铁 G 字头',
  '动车 D 字头',
  '直飞航班',
  '早晚低峰',
  '附近咖啡优先',
  '安静办公优先',
  '连锁稳定优先',
  '可查选项'
];

const args = new Set(process.argv.slice(2));
const useDevice = args.has('--device');
const clearLogs = args.has('--clear-logs');
const outputDir = path.resolve(process.env.AIPHONE_SMOKE_DIR || path.join(TOOL_GATEWAY_DIR, '.smoke'));
const gatewayUrl = (process.env.TOOL_GATEWAY_URL || 'http://127.0.0.1:8787').replace(/\/$/, '');
const endpoint = gatewayUrl.endsWith('/api/aiphone/tool') ? gatewayUrl : `${gatewayUrl}/api/aiphone/tool`;
const healthUrl = endpoint.replace(/\/api\/aiphone\/tool$/, '/health');
const hdcTarget = process.env.AIPHONE_HDC_TARGET || process.env.HDC_TARGET || '';
const gatewayErr = process.env.AIPHONE_GATEWAY_ERR || '/tmp/aiphone-tool-gateway.err';
const gatewayLog = process.env.AIPHONE_GATEWAY_LOG || '/tmp/aiphone-tool-gateway.log';

function textOf(value) {
  if (value === undefined || value === null) {
    return '';
  }
  return typeof value === 'string' ? value : JSON.stringify(value);
}

function shQuote(value) {
  return `'${value.replaceAll("'", "'\\''")}'`;
}

function parseJsonl(text) {
  const envelopes = [];
  const errors = [];
  text.split(/\r?\n/).forEach((line, index) => {
    const trimmed = line.trim();
    if (trimmed.length === 0) {
      return;
    }
    try {
      envelopes.push(JSON.parse(trimmed));
    } catch (error) {
      errors.push(`line ${index + 1}: ${error instanceof Error ? error.message : String(error)}`);
    }
  });
  return { envelopes, errors };
}

function summarize(envelopes) {
  const creates = envelopes.filter(item => item.createSurface).map(item => item.createSurface);
  const components = envelopes
    .filter(item => item.updateComponents)
    .flatMap(item => item.updateComponents.components || []);
  const dataUpdates = envelopes
    .filter(item => item.updateDataModel)
    .map(item => item.updateDataModel);
  const lastCreate = creates[creates.length - 1] || {};
  const lastDataByPath = {};
  dataUpdates.forEach(update => {
    lastDataByPath[update.path] = update.value;
  });
  const allText = JSON.stringify(envelopes);

  return {
    title: textOf(lastCreate.title),
    status: textOf(lastCreate.status),
    intent: textOf(lastCreate.intent),
    componentTypes: [...new Set(components.map(component => component.component))],
    dataPaths: [...new Set(dataUpdates.map(update => update.path))],
    dataCounts: Object.fromEntries(Object.entries(lastDataByPath).map(([dataPath, value]) => [
      dataPath,
      Array.isArray(value) ? value.length : (value && typeof value === 'object' ? Object.keys(value).length : textOf(value).length)
    ])),
    allText
  };
}

async function postFromHost(testCase) {
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/a2ui+json'
    },
    body: JSON.stringify({
      toolId: testCase.toolId,
      prompt: testCase.prompt,
      surfaceId: 'surface_smoke',
      actionId: 'smoke',
      stream: true
    }),
    signal: AbortSignal.timeout(45000)
  });
  return {
    httpStatus: response.status,
    text: await response.text()
  };
}

function resolveHdcTarget() {
  if (hdcTarget.length > 0) {
    return hdcTarget;
  }
  const output = spawnSync('hdc', ['list', 'targets'], { encoding: 'utf8' });
  const first = output.stdout.split(/\r?\n/).map(line => line.trim()).find(line => line.length > 0 && !line.includes('[Empty]'));
  return first || '';
}

function runHdc(target, hdcArgs, options = {}) {
  return execFileSync('hdc', ['-t', target, ...hdcArgs], {
    encoding: 'utf8',
    maxBuffer: 8 * 1024 * 1024,
    timeout: options.timeout || 60000
  });
}

function postFromDevice(target, testCase) {
  const body = JSON.stringify({
    toolId: testCase.toolId,
    prompt: testCase.prompt,
    surfaceId: 'surface_device_smoke',
    actionId: 'device_smoke',
    stream: true
  });
  const remote = '/data/local/tmp/aiphone-tool-body.json';
  const shellCommand =
    `printf %s ${shQuote(Buffer.from(body).toString('base64'))} | base64 -d > ${remote} && ` +
    `curl -sS --max-time 45 -H 'Content-Type: application/json' -H 'Accept: application/a2ui+json' --data-binary @${remote} http://127.0.0.1:8787/api/aiphone/tool`;
  return {
    httpStatus: 200,
    text: runHdc(target, ['shell', shellCommand], { timeout: 60000 })
  };
}

function checkExpectation(testCase, result) {
  const failures = [];
  if (result.httpStatus < 200 || result.httpStatus >= 300) {
    failures.push(`HTTP ${result.httpStatus}`);
  }
  if (result.parseErrors.length > 0) {
    failures.push(`JSONL parse errors: ${result.parseErrors.join('; ')}`);
  }
  if (testCase.expect.status && result.summary.status !== testCase.expect.status) {
    failures.push(`status expected ${testCase.expect.status}, got ${result.summary.status || '<empty>'}`);
  }
  (testCase.expect.components || []).forEach(component => {
    if (!result.summary.componentTypes.includes(component)) {
      failures.push(`missing component ${component}`);
    }
  });
  if (testCase.expect.dataPath && !result.summary.dataPaths.includes(testCase.expect.dataPath)) {
    failures.push(`missing data path ${testCase.expect.dataPath}`);
  }
  if (testCase.expect.dataPath && (result.summary.dataCounts[testCase.expect.dataPath] || 0) === 0) {
    failures.push(`empty data path ${testCase.expect.dataPath}`);
  }
  (testCase.expect.contains || []).forEach(token => {
    if (!result.summary.allText.includes(token)) {
      failures.push(`missing text ${token}`);
    }
  });
  FORBIDDEN_SYNTHETIC_MARKERS.forEach(token => {
    if (result.summary.allText.includes(token) || result.raw.includes(token)) {
      failures.push(`forbidden synthetic marker ${token}`);
    }
  });
  if (/failed to connect|Cannot write headers after they are sent|ERR_HTTP_HEADERS_SENT/i.test(result.raw)) {
    failures.push('raw response contains connection/header failure text');
  }
  if (matchesAllowedProviderError(testCase, result)) {
    const hardFailures = failures.filter(failure =>
      failure.startsWith('HTTP ') ||
      failure.startsWith('JSONL parse errors:') ||
      failure.startsWith('forbidden synthetic marker ') ||
      failure === 'raw response contains connection/header failure text'
    );
    return hardFailures;
  }
  return failures;
}

function matchesAllowedProviderError(testCase, result) {
  const allowed = testCase.expect.allowProviderError;
  if (!allowed) {
    return false;
  }
  if (allowed.status && result.summary.status !== allowed.status) {
    return false;
  }
  const requiredComponents = allowed.components || [];
  if (!requiredComponents.every(component => result.summary.componentTypes.includes(component))) {
    return false;
  }
  const anyText = allowed.anyText || [];
  if (anyText.length > 0 && !anyText.some(token => result.summary.allText.includes(token) || result.raw.includes(token))) {
    return false;
  }
  return result.httpStatus >= 200 && result.httpStatus < 300 && result.parseErrors.length === 0;
}

function fileSizeIfExists(filePath) {
  try {
    return fs.existsSync(filePath) ? fs.statSync(filePath).size : 0;
  } catch (_error) {
    return 0;
  }
}

function readTextFromOffset(filePath, offset) {
  try {
    if (!fs.existsSync(filePath)) {
      return '';
    }
    const size = fs.statSync(filePath).size;
    const start = Math.min(offset, size);
    const buffer = Buffer.alloc(size - start);
    const fd = fs.openSync(filePath, 'r');
    try {
      fs.readSync(fd, buffer, 0, buffer.length, start);
    } finally {
      fs.closeSync(fd);
    }
    return buffer.toString('utf8');
  } catch (error) {
    return `failed to read ${filePath}: ${error instanceof Error ? error.message : String(error)}`;
  }
}

function captureHilog(target, label) {
  if (!target) {
    return '';
  }
  if (clearLogs) {
    spawnSync('hdc', ['-t', target, 'hilog', '-r'], { encoding: 'utf8', timeout: 5000 });
  }
  const output = spawnSync('hdc', ['-t', target, 'hilog', '-x', '-z', '500', '-T', 'AIPhone', '-v', 'time', '-v', 'year', '-v', 'msec'], {
    encoding: 'utf8',
    timeout: 5000,
    maxBuffer: 4 * 1024 * 1024
  });
  const text = `${output.stdout || ''}${output.stderr || ''}`;
  const logPath = path.join(outputDir, `${label}-hilog.log`);
  fs.writeFileSync(logPath, text);
  return text;
}

function analyzeLogs(...texts) {
  const source = texts.join('\n');
  const patterns = [
    ['connection', /failed to connect|Could not connect|ECONNREFUSED|server is not running/i],
    ['headers-sent', /Cannot write headers after they are sent|ERR_HTTP_HEADERS_SENT/i],
    ['tool-request', /\[AIPhone\]\[ToolGatewayRequest\]/],
    ['tool-result-failed', /\[AIPhone\]\[ToolResult\] ok=false/],
    ['model-result-failed', /\[AIPhone\]\[ModelResult\] ok=false/],
    ['parse-error', /\[AIPhone\]\[(ToolGatewayParseError|ToolGatewayApplyError|ModelA2UIParseError|ModelA2UIApplyError)\]/]
  ];
  return patterns
    .filter(([, pattern]) => pattern.test(source))
    .map(([name]) => name);
}

async function main() {
  fs.mkdirSync(outputDir, { recursive: true });
  const target = useDevice ? resolveHdcTarget() : '';
  const gatewayErrOffset = fileSizeIfExists(gatewayErr);
  const gatewayLogOffset = fileSizeIfExists(gatewayLog);

  if (useDevice && target.length === 0) {
    throw new Error('No HDC target found. Set AIPHONE_HDC_TARGET or connect a device.');
  }
  if (useDevice) {
    try {
      runHdc(target, ['rport', 'tcp:8787', 'tcp:8787'], { timeout: 10000 });
    } catch (error) {
      console.log(`WARN device/rport ${error instanceof Error ? error.message.split('\n')[0] : String(error)}`);
    }
  }

  const healthResponse = await fetch(healthUrl, { signal: AbortSignal.timeout(5000) });
  const health = await healthResponse.text();
  if (!healthResponse.ok) {
    throw new Error(`Gateway health failed: HTTP ${healthResponse.status} ${health}`);
  }

  const beforeLogs = useDevice ? captureHilog(target, 'before') : '';
  const suites = [
    ['host', postFromHost]
  ];
  if (useDevice) {
    suites.push(['device', testCase => postFromDevice(target, testCase)]);
  }

  const results = [];
  for (const [suiteName, runner] of suites) {
    for (const testCase of DEFAULT_QUERIES) {
      const started = Date.now();
      const response = await runner(testCase);
      const parsed = parseJsonl(response.text);
      const summary = summarize(parsed.envelopes);
      const result = {
        suite: suiteName,
        name: testCase.name,
        prompt: testCase.prompt,
        ms: Date.now() - started,
        httpStatus: response.httpStatus,
        parseErrors: parsed.errors,
        summary,
        raw: response.text.slice(0, 2000)
      };
      result.failures = checkExpectation(testCase, result);
      results.push(result);
      const mark = result.failures.length === 0 ? 'PASS' : 'FAIL';
      console.log(`${mark} ${suiteName}/${testCase.name} ${summary.title || '<no title>'} status=${summary.status || '<empty>'} components=${summary.componentTypes.join(',') || '<none>'} ms=${result.ms}`);
      result.failures.forEach(failure => console.log(`  - ${failure}`));
    }
  }

  const afterLogs = useDevice ? captureHilog(target, 'after') : '';
  const gatewayErrText = readTextFromOffset(gatewayErr, gatewayErrOffset);
  const gatewayLogText = readTextFromOffset(gatewayLog, gatewayLogOffset);
  const diagnostics = analyzeLogs(beforeLogs, afterLogs, gatewayErrText, gatewayLogText, JSON.stringify(results));
  const report = {
    generatedAt: new Date().toISOString(),
    host: os.hostname(),
    endpoint,
    useDevice,
    hdcTarget: target,
    health: JSON.parse(health),
    diagnostics,
    results
  };
  const reportPath = path.join(outputDir, `smoke-${new Date().toISOString().replaceAll(':', '-')}.json`);
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
  console.log(`report=${reportPath}`);
  if (diagnostics.length > 0) {
    console.log(`diagnostics=${diagnostics.join(',')}`);
  }

  const failed = results.filter(result => result.failures.length > 0);
  if (failed.length > 0) {
    process.exitCode = 1;
  }
}

main().catch(error => {
  console.error(error instanceof Error ? error.stack || error.message : String(error));
  process.exitCode = 1;
});
