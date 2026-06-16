#!/usr/bin/env node
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { spawn, spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const outDir = join(rootDir, 'tool-gateway', '.smoke');
mkdirSync(outDir, { recursive: true });

const defaultCases = [
  { query: '你好', expectsTool: false },
  { query: '我明天要从北京去上海，帮我搜索出行方案', expectsTool: true, expectedToolId: 'travel.search' },
  { query: '帮我搜索深圳坂田华为基地附近的奶茶店', expectsTool: true, expectedToolId: 'food.search' }
];

const forbiddenSyntheticMarkers = [
  '高铁 G 字头',
  '动车 D 字头',
  '直飞航班',
  '早晚低峰',
  '附近咖啡优先',
  '安静办公优先',
  '连锁稳定优先',
  '可查选项'
];

const visibleDomainMarkers = [
  '北京',
  '上海',
  '深圳',
  '高铁',
  '航班',
  '高铁 · 12306',
  '飞机 · 飞常准',
  '12306',
  '飞常准',
  '餐饮',
  '咖啡',
  '奶茶',
  '坂田',
  '华为',
  '多展示一些',
  '选最快的'
];

const forbiddenLayoutActionMarkers = [
  '换个时间',
  '换个车站'
];

const finalLayoutBlockingMarkers = [
  'A2UI 流解析失败',
  '模型正在思考',
  '工具供应商调用异常',
  '需要供应商配置',
  '需要配置：',
  '查询失败',
  'Bad Request',
  '暂无可展示数据',
  '暂不支持的组件',
  '把一句话变成可执行界面',
  '告诉 AIPhone 你要安排的事',
  '[',
  ']'
];

const finalLayoutRouteMarkers = [
  '北京',
  '上海'
];

const finalLayoutBlockingPatterns = [
  { name: 'iso-date', pattern: /\b20\d{2}[-/]\d{1,2}[-/]\d{1,2}\b/ },
  { name: 'zh-date', pattern: /\b\d{4}年\d{1,2}月\d{1,2}日\b/ }
];

const argv = process.argv.slice(2);
const cleanData = process.env.AIPHONE_SMOKE_CLEAN_DATA === '1' || argv.includes('--clean-data');
const queryArgs = argv.filter((arg) => arg !== '--clean-data');
const useDefaultCases = queryArgs.length === 0;
const queries = useDefaultCases ? defaultCases.map((testCase) => testCase.query) : queryArgs;
const target = process.env.AIPHONE_HDC_TARGET || firstTarget();
const timeoutMs = Number.parseInt(process.env.AIPHONE_QUERY_TIMEOUT_MS || '90000', 10);

function expectedCaseForQuery(query) {
  if (/^你好$|问候|打招呼/.test(query)) {
    return {
      expectsTool: false,
      expectedToolId: ''
    };
  }
  if (/出行方案|搜索出行|怎么去|比较出行|出行选项|整理可查|可查的出行/.test(query) && /北京|上海|广州|深圳|杭州|成都|重庆|西安|南京|武汉|厦门|青岛|长沙|昆明|海口|三亚/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'travel.search'
    };
  }
  if (/航班|机票|飞机/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'flight.search'
    };
  }
  if (/高铁|火车|车票|12306/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'train.search'
    };
  }
  if (/附近|周边|外卖|咖啡|奶茶|肯德基|餐饮|美食/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'food.search'
    };
  }
  return {
    expectsTool: null,
    expectedToolId: ''
  };
}

function firstTarget() {
  const result = spawnSync('hdc', ['list', 'targets'], { encoding: 'utf8' });
  const lines = result.stdout.split('\n').map((line) => line.trim()).filter(Boolean);
  if (lines.length === 0) {
    throw new Error('No hdc target found. Set AIPHONE_HDC_TARGET.');
  }
  return lines[0];
}

function hdc(args, options = {}) {
  const result = spawnSync('hdc', ['-t', target, ...args], {
    encoding: 'utf8',
    maxBuffer: 20 * 1024 * 1024,
    ...options
  });
  if (result.status !== 0) {
    throw new Error(`hdc ${args.join(' ')} failed:\n${result.stdout}\n${result.stderr}`);
  }
  return result.stdout;
}

function clearHilog() {
  try {
    hdc(['shell', 'hilog', '-r']);
  } catch (error) {
    console.warn(`Could not clear hilog buffer: ${error instanceof Error ? error.message : String(error)}`);
  }
}

function cleanBundleData() {
  try {
    hdc(['shell', 'bm', 'clean', '-n', 'com.example.aiphonedemo', '-d']);
  } catch (error) {
    console.warn(`Could not clean bundle data: ${error instanceof Error ? error.message : String(error)}`);
  }
}

function probeLocalModel() {
  const result = spawnSync('hdc', ['-t', target, 'shell', 'curl', '-sS', '-m', '3', 'http://127.0.0.1:11434/v1/models'], {
    encoding: 'utf8',
    maxBuffer: 2 * 1024 * 1024
  });
  const output = `${result.stdout || ''}${result.stderr || ''}`.trim();
  const listenerReachable = result.status === 0 || /403|Call is not allowed/i.test(output);
  const connectionRefused = /Failed to connect|Couldn.t connect|Connection refused|curl:\s*\(7\)/i.test(output);
  return {
    status: result.status,
    listenerReachable,
    connectionRefused,
    output: output.length > 500 ? `${output.slice(0, 500)}...<truncated>` : output
  };
}

function cleanupHilogProcesses() {
  spawnSync('pkill', ['-f', `hdc -t ${target} hilog`], { encoding: 'utf8' });
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function walk(node, visit) {
  visit(node);
  for (const child of node.children || []) {
    walk(child, visit);
  }
}

function center(bounds) {
  const match = /^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/.exec(bounds || '');
  if (!match) {
    return null;
  }
  const left = Number.parseInt(match[1], 10);
  const top = Number.parseInt(match[2], 10);
  const right = Number.parseInt(match[3], 10);
  const bottom = Number.parseInt(match[4], 10);
  return {
    x: Math.floor((left + right) / 2),
    y: Math.floor((top + bottom) / 2)
  };
}

function dumpLayout(localName = 'latest-layout.json') {
  const remote = '/data/local/tmp/aiphone-smoke-layout.json';
  const local = join(outDir, localName);
  let lastError = null;
  for (let attempt = 0; attempt < 5; attempt += 1) {
    try {
      hdc(['shell', 'uitest', 'dumpLayout', '-p', remote, '-b', 'com.example.aiphonedemo']);
      hdc(['file', 'recv', remote, local]);
      const raw = readFileSync(local, 'utf8').trim();
      if (raw.length === 0) {
        throw new Error('dumpLayout produced an empty file');
      }
      return JSON.parse(raw);
    } catch (error) {
      lastError = error;
      spawnSync('sleep', ['0.5']);
    }
  }
  throw lastError instanceof Error ? lastError : new Error(String(lastError));
}

function captureScreen(localName = 'latest-screen.png') {
  const remote = '/data/local/tmp/aiphone-smoke-screen.png';
  const local = join(outDir, localName);
  hdc(['shell', 'uitest', 'screenCap', '-p', remote]);
  hdc(['file', 'recv', remote, local]);
  return local;
}

function collectLayoutText(layout) {
  const values = [];
  walk(layout, (node) => {
    const attrs = node.attributes || {};
    ['text', 'content', 'description', 'hint'].forEach((key) => {
      const value = attrs[key];
      if (typeof value === 'string' && value.trim().length > 0) {
        values.push(value.trim());
      }
    });
  });
  return [...new Set(values)];
}

function collectInputText(layout) {
  const values = [];
  walk(layout, (node) => {
    const attrs = node.attributes || {};
    if (attrs.type === 'TextInput' || attrs.type === 'TextArea') {
      ['text', 'content', 'description', 'hint'].forEach((key) => {
        const value = attrs[key];
        if (typeof value === 'string' && value.trim().length > 0) {
          values.push(value.trim());
        }
      });
    }
  });
  return values.join('|');
}

function findControls(layout) {
  let input = null;
  let generate = null;
  walk(layout, (node) => {
    const attrs = node.attributes || {};
    if ((attrs.type === 'TextInput' || attrs.type === 'TextArea') && input === null) {
      input = center(attrs.bounds);
    }
    if (attrs.type === 'Button' && attrs.text === '生成') {
      generate = center(attrs.bounds);
    }
  });
  if (input === null) {
    throw new Error('Could not locate AIPhone input control.');
  }
  return { input, generate };
}

async function waitForControls(localName = 'latest-layout.json', attempts = 10) {
  let lastError = null;
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      return findControls(dumpLayout(localName));
    } catch (error) {
      lastError = error;
      await sleep(500);
    }
  }
  throw lastError || new Error('Could not locate AIPhone input/generate controls.');
}

function lineMatchesPid(line, pid) {
  if (pid.length === 0) {
    return true;
  }
  return line.indexOf(` ${pid} `) >= 0;
}

async function captureWhile(appPid, runAction) {
  const logs = [];
  const child = spawn('hdc', ['-t', target, 'hilog'], {
    stdio: ['ignore', 'pipe', 'pipe']
  });
  child.stdout.setEncoding('utf8');
  child.stderr.setEncoding('utf8');
  let buffer = '';
  const onData = (chunk) => {
    buffer += chunk;
    const parts = buffer.split('\n');
    buffer = parts.pop() || '';
    for (const line of parts) {
      if (lineMatchesPid(line, appPid) && (line.includes('AIPhone') || line.includes('aiphonedemo') || line.includes('NETSTACK') || line.includes('11434'))) {
        logs.push(line);
      }
    }
  };
  child.stdout.on('data', onData);
  child.stderr.on('data', onData);

  let actionError = null;
  try {
    await sleep(800);
    await runAction();

    const started = Date.now();
    while (Date.now() - started < timeoutMs) {
      await sleep(500);
      const text = logs.join('\n');
      if (/\[AIPhone\]\[(ToolResult|A2uiHomeToolResult)\] ok=/.test(text) ||
        /\[AIPhone\]\[(ToolRequest|A2uiHomeToolRequest)\] none/.test(text) ||
        /\[AIPhone\]\[(ModelResult|A2uiHomeModelResult)\] ok=false/.test(text)) {
        break;
      }
    }
  } catch (error) {
    actionError = error;
  } finally {
    child.kill('SIGTERM');
    await waitForProcessExit(child, 1500);
    if (child.exitCode === null) {
      child.kill('SIGKILL');
      await waitForProcessExit(child, 1500);
    }
    cleanupHilogProcesses();
  }
  if (actionError !== null) {
    throw actionError;
  }
  return logs;
}

function waitForProcessExit(child, timeoutMs) {
  return new Promise((resolve) => {
    let resolved = false;
    const finish = () => {
      if (!resolved) {
        resolved = true;
        resolve();
      }
    };
    child.once('exit', finish);
    setTimeout(finish, timeoutMs);
  });
}

function activeHilogProcesses() {
  const result = spawnSync('ps', ['-axo', 'pid=,command='], { encoding: 'utf8' });
  return result.stdout
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.includes('hdc') && line.includes('hilog'));
}

function analyze(query, logs, expectedTool, expectedToolId = '') {
  const text = logs.join('\n');
  const escapedToolId = expectedToolId.replace('.', '\\.');
  const toolIdPattern = expectedToolId.length > 0 ?
    new RegExp(`\\[AIPhone\\]\\[(ToolRequest|A2uiHomeToolRequest|A2uiHomeToolRequestFromModel)\\][^\\n]*toolId=${escapedToolId}`) :
    null;
  const hasExpectedToolId = toolIdPattern === null ? true : toolIdPattern.test(text);
  const missingConfig = /\[AIPhone\]\[LocalToolMissingConfig\]/.test(text);
  const result = {
    query,
    expectedTool,
    expectedToolId,
    hasExpectedToolId,
    directIntent: /\[AIPhone\]\[ToolRequestByIntent\] toolId=/.test(text),
    localToolRequest: /\[AIPhone\]\[LocalToolRequest\] endpoint=local:\/\/aiphone-tools toolId=/.test(text),
    model200: /\[AIPhone\]\[ModelStreamResponse\] code=200/.test(text) || /response_code":200[\s\S]*dst_port":11434/.test(text),
    modelOk: /\[AIPhone\]\[(ModelResult|A2uiHomeModelResult)\] ok=true/.test(text),
    toolRequested: /\[AIPhone\]\[(ToolRequest|A2uiHomeToolRequest|A2uiHomeToolRequestFromModel)\][^\n]*toolId=/.test(text),
    toolOk: /\[AIPhone\]\[(ToolResult|A2uiHomeToolResult)\] ok=true/.test(text),
    failedConnect: /failed to connect|Could not connect|Couldn.t connect|ECONNREFUSED|server is not running|CURLcode result 7|curl_code":7|os_errno":111/i.test(text),
    providerFailed: /\[AIPhone\]\[LocalTool12306Endpoint\][^\n]*code=[45]\d\d/.test(text) || /\[AIPhone\]\[LocalToolException\]/.test(text) || (missingConfig && expectedToolId !== 'travel.search'),
    modelFailed: /\[AIPhone\]\[(ModelResult|A2uiHomeModelResult)\] ok=false/.test(text),
    toolNone: /\[AIPhone\]\[(ToolRequest|A2uiHomeToolRequest)\] none/.test(text),
    syntheticFallback: forbiddenSyntheticMarkers.some((marker) => text.includes(marker))
  };
  const modelPassed = result.model200 && result.modelOk && !result.modelFailed;
  const basePassed = !result.failedConnect &&
    !result.providerFailed &&
    !result.syntheticFallback &&
    !result.directIntent;
  if (expectedTool === true) {
    result.ok = basePassed && modelPassed && result.toolRequested && result.localToolRequest && result.toolOk && result.hasExpectedToolId;
  } else if (expectedTool === false) {
    result.ok = basePassed && modelPassed && result.toolNone && !result.toolRequested && !result.localToolRequest;
  } else {
    result.ok = basePassed && modelPassed &&
      (result.toolRequested ? (result.localToolRequest && result.toolOk) : (result.toolNone && !result.localToolRequest));
  }
  return result;
}

function layoutExpectationsForQuery(query) {
  if (/^你好$|问候|打招呼/.test(query)) {
    return ['你好'];
  }
  if (/出行方案|搜索出行|怎么去|比较出行|出行选项|整理可查|可查的出行/.test(query)) {
    return ['北京', '上海'];
  }
  if (/附近|周边|外卖|咖啡|奶茶|肯德基|餐饮|美食/.test(query)) {
    return ['奶茶', '餐饮', '高德', '腾讯地图', '百度地图', '美团', '淘宝闪购'];
  }
  return [];
}

async function runQuery(query, index, expectedTool) {
  clearHilog();
  hdc(['shell', 'aa', 'force-stop', 'com.example.aiphonedemo']);
  if (cleanData) {
    cleanBundleData();
  }
  hdc(['shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.example.aiphonedemo']);
  await sleep(3000);
  const appPid = hdc(['shell', 'pidof', 'com.example.aiphonedemo']).trim().split(/\s+/)[0] || '';
  const controls = await waitForControls();
  const logs = await captureWhile(appPid, async () => {
    let typed = false;
    for (let attempt = 0; attempt < 3; attempt += 1) {
      hdc(['shell', 'uitest', 'uiInput', 'click', String(controls.input.x), String(controls.input.y)]);
      hdc(['shell', 'uitest', 'uiInput', 'keyEvent', '2072', '2017']);
      hdc(['shell', 'uitest', 'uiInput', 'keyEvent', '2055']);
      hdc(['shell', 'uitest', 'uiInput', 'text', query]);
      await sleep(1200);
      const inputText = collectInputText(dumpLayout(`query-${index + 1}-input-attempt-${attempt + 1}.json`));
      if (inputText.includes(query)) {
        typed = true;
        break;
      }
    }
    if (!typed) {
      throw new Error(`Could not type full query into AIPhone input: ${query}`);
    }
    hdc(['shell', 'uitest', 'uiInput', 'keyEvent', '2054']);
  });
  const logPath = join(outDir, `query-${index + 1}.log`);
  writeFileSync(logPath, logs.join('\n') + '\n');
  const expectedToolId = useDefaultCases ? (defaultCases[index].expectedToolId || '') : expectedCaseForQuery(query).expectedToolId;
  const summary = analyze(query, logs, expectedTool, expectedToolId);
  summary.logPath = logPath;
  const layout = dumpLayout(`query-${index + 1}-final-layout.json`);
  const layoutTextValues = collectLayoutText(layout);
  const layoutText = layoutTextValues.join('\n');
  const layoutTextPath = join(outDir, `query-${index + 1}-final-layout-text.txt`);
  writeFileSync(layoutTextPath, layoutText + '\n');
  const expectedMarkers = layoutExpectationsForQuery(query);
  const expectedHits = expectedMarkers.filter((marker) => layoutText.includes(marker));
  const allowsPartialTravelSourceFailure = expectedToolId === 'travel.search' &&
    summary.toolOk === true &&
    (layoutText.includes('来源状态') || layoutText.includes('飞常准')) &&
    (layoutText.includes('耗时') || /\bG\d+\b/.test(layoutText) || layoutText.includes('高铁 · 12306'));
  const layoutBlockingHits = finalLayoutBlockingMarkers.filter((marker) => {
    if (allowsPartialTravelSourceFailure && marker === '查询失败') {
      return false;
    }
    return layoutText.includes(marker);
  });
  summary.layoutPath = join(outDir, `query-${index + 1}-final-layout.json`);
  summary.layoutTextPath = layoutTextPath;
  summary.screenPath = captureScreen(`query-${index + 1}-final-screen.png`);
  summary.layoutExpectedHits = expectedHits;
  summary.layoutBlockingHits = layoutBlockingHits;
  summary.layoutOk = layoutBlockingHits.length === 0 && (expectedMarkers.length === 0 || expectedHits.length > 0);
  summary.ok = summary.ok && summary.layoutOk;
  return summary;
}

const modelHealth = probeLocalModel();
console.log(`modelHealth: ${JSON.stringify(modelHealth, null, 2)}`);
console.log(`cleanData: ${cleanData ? 'true' : 'false'}`);

const summaries = [];
for (let index = 0; index < queries.length; index += 1) {
  const query = queries[index];
  console.log(`\n[${index + 1}/${queries.length}] ${query}`);
  const inferredCase = useDefaultCases ? defaultCases[index] : expectedCaseForQuery(query);
  const expectedTool = inferredCase.expectsTool;
  const summary = await runQuery(query, index, expectedTool);
  summaries.push(summary);
  console.log(JSON.stringify(summary, null, 2));
}

const finalLayout = dumpLayout('final-layout.json');
const finalScreenPath = captureScreen('final-screen.png');
const finalLayoutTextValues = collectLayoutText(finalLayout);
const finalLayoutText = finalLayoutTextValues.join('\n');
const finalLayoutTextPath = join(outDir, 'final-layout-text.txt');
writeFileSync(finalLayoutTextPath, finalLayoutText + '\n');
const finalLayoutDomainHits = visibleDomainMarkers.filter((marker) => finalLayoutText.includes(marker));
const finalLayoutSyntheticHits = forbiddenSyntheticMarkers.filter((marker) => finalLayoutText.includes(marker));
const finalLayoutForbiddenActionHits = forbiddenLayoutActionMarkers.filter((marker) => finalLayoutText.includes(marker));
const finalQuery = queries.length > 0 ? queries[queries.length - 1] : '';
const finalAllowsPartialTravel = /出行方案|搜索出行|怎么去|比较出行|出行选项|整理可查|可查的出行/.test(finalQuery);
const finalSummary = summaries.length > 0 ? summaries[summaries.length - 1] : null;
const finalAllowsSourceFailure =
  finalAllowsPartialTravel &&
  finalSummary !== null &&
  finalSummary.expectedToolId === 'travel.search' &&
  finalSummary.toolOk === true &&
  (finalLayoutText.includes('来源状态') || finalLayoutText.includes('飞常准')) &&
  finalLayoutText.includes('耗时');
const finalLayoutBlockingHits = finalLayoutBlockingMarkers.filter((marker) => {
  if (finalAllowsPartialTravel && (marker === '需要供应商配置' || marker === '需要配置：')) {
    return false;
  }
  if (finalAllowsSourceFailure && marker === '查询失败') {
    return false;
  }
  return finalLayoutText.includes(marker);
});
for (const blockingPattern of finalLayoutBlockingPatterns) {
  if (blockingPattern.pattern.test(finalLayoutText)) {
    finalLayoutBlockingHits.push(blockingPattern.name);
  }
}
const finalLayoutRouteHits = finalLayoutRouteMarkers.filter((marker) => finalLayoutText.includes(marker));
const hilogProcesses = activeHilogProcesses();
const visibleOutput = {
  layoutPath: join(outDir, 'final-layout.json'),
  screenPath: finalScreenPath,
  textPath: finalLayoutTextPath,
  domainHits: finalLayoutDomainHits,
  routeHits: finalLayoutRouteHits,
  syntheticHits: finalLayoutSyntheticHits,
  forbiddenActionHits: finalLayoutForbiddenActionHits,
  blockingHits: finalLayoutBlockingHits,
  ok: finalLayoutDomainHits.length > 0 &&
    finalLayoutSyntheticHits.length === 0 &&
    finalLayoutForbiddenActionHits.length === 0 &&
    finalLayoutBlockingHits.length === 0
};
const processCleanup = {
  activeHilogProcesses: hilogProcesses,
  ok: hilogProcesses.length === 0
};

const summaryPath = join(outDir, 'summary.json');
writeFileSync(summaryPath, JSON.stringify({ target, timeoutMs, cleanData, modelHealth, summaries, visibleOutput, processCleanup }, null, 2));
console.log(`\nsummary: ${summaryPath}`);
console.log(`visibleOutput: ${JSON.stringify(visibleOutput, null, 2)}`);
console.log(`processCleanup: ${JSON.stringify(processCleanup, null, 2)}`);
const failed = summaries.filter((summary) => !summary.ok);
process.exitCode = failed.length === 0 && visibleOutput.ok && processCleanup.ok ? 0 : 1;
