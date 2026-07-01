#!/usr/bin/env node
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { spawn, spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const outDir = join(rootDir, 'tool-gateway', '.smoke');
mkdirSync(outDir, { recursive: true });

const defaultCases = [
  { query: '我明天要从北京去上海，帮我搜索出行方案', expectsTool: true, expectedToolId: 'travel.search' },
  { query: '帮我搜索深圳坂田华为基地附近的咖啡店', expectsTool: true, expectedToolId: 'food.search' },
  { query: '帮我用 Google Maps 搜索伦敦国王十字车站附近的中餐', expectsTool: true, expectedToolId: 'maps.place.search' },
  { query: '帮我查看邮箱里最新的重要邮件', expectsTool: true, expectedToolId: 'mail.search' },
  { query: '帮我查看我Gmail里和我eccv论文相关的邮件', expectsTool: true, expectedToolId: 'gmail.mail.search' },
  { query: '帮我在b站和youtube里搜索qwen max 的官方视频', expectsTool: true, expectedToolId: 'media.video.search' },
  { query: '打开社交消息聚合，看看 Slack、X、企业微信', expectsTool: true, expectedToolId: 'social.feed.search' },
  { query: '帮我查看 X 上 openai 最近的公开 post', expectsTool: true, expectedToolId: 'x.post.search' }
];

const dynamicCases = [
  {
    query: '帮我查明天深圳到珠海的船票',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'none'
  },
  {
    query: '帮我查明天深圳天气',
    expectsTool: true,
    expectedToolId: 'dynamic.search',
    expectedDiscoveredToolId: 'weather.query'
  }
];

const gmailCases = [
  { query: '帮我看 Gmail 里最新的重要邮件', expectsTool: true, expectedToolId: 'gmail.mail.search' },
  { query: '帮我用 Gmail 写一封邮件给 alice@example.com 说我收到了', expectsTool: true, expectedToolId: 'gmail.draft.create' },
  { query: '帮我查看我Gmail里和我eccv论文相关的邮件', expectsTool: true, expectedToolId: 'gmail.mail.search' }
];

const mailCases = [
  { query: '帮我看邮箱里最新的重要邮件', expectsTool: true, expectedToolId: 'mail.search' },
  { query: '帮我看 QQ 邮箱里最新邮件', expectsTool: true, expectedToolId: 'mail.search' }
];

const googleAppCases = [
  { query: '帮我在 YouTube 搜索 qwen max 官方介绍视频', expectsTool: true, expectedToolId: 'youtube.video.search' },
  { query: '帮我查看我的 YouTube 播放列表', expectsTool: true, expectedToolId: 'youtube.mine.playlists' },
  { query: '帮我看今天的 Google Calendar 日程', expectsTool: true, expectedToolId: 'calendar.events.search' },
  { query: '帮我在 2026年6月30日下午3点创建一个标题为 AIPhoneDemo smoke 的30分钟日程', expectsTool: true, expectedToolId: 'calendar.event.create' },
  { query: '帮我用 Google Maps 搜索深圳坂田华为基地附近的咖啡店', expectsTool: true, expectedToolId: 'maps.place.search' }
];

const fullRegressionCases = [
  { query: '你好', expectsTool: false },
  ...defaultCases,
  { query: '帮我查明天北京到上海航班', expectsTool: true, expectedToolId: 'flight.search' },
  { query: '帮我查询深圳北出发到香港西九龙明天晚上六点之后的高铁', expectsTool: true, expectedToolId: 'train.search' },
  { query: '帮我查附近咖啡', expectsTool: true, expectedToolId: 'food.search' },
  { query: '帮我查深圳坂田附近麦当劳门店和菜单', expectsTool: true, expectedToolId: 'food.search' },
  ...dynamicCases,
  ...mailCases,
  ...gmailCases,
  ...googleAppCases
];

const forbiddenSocialHubLegacyMarkers = [
  'SocialInbox',
  'social.reply.send',
  '微信消息收件箱',
  '通知中心桥接',
  '辅助捕获'
];

const forbiddenSyntheticMarkers = [
  '高铁 G 字头',
  '动车 D 字头',
  '直飞航班',
  '早晚低峰',
  '附近咖啡优先',
  '安静办公优先',
  '连锁稳定优先',
  '可查选项',
  ...forbiddenSocialHubLegacyMarkers
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
  '接入工具',
  'dynamic.search',
  'ferry.ticket.search',
  'weather.query',
  'statistics.search',
  'ppt.generate',
  'Gmail',
  'mail.search',
  'Mailbox',
  'QQ Mail',
  'AI 回复草稿',
  'YouTube',
  'youtube.video.search',
  'youtube.mine.playlists',
  'YOUTUBE_API_KEY',
  'Google Calendar',
  'calendar.events.search',
  'calendar.event.create',
  'Google OAuth',
  'Google Places',
  'Google Maps',
  'maps.place.search',
  'GOOGLE_MAPS_API_KEY',
  'Gmail Web',
  'google.gmail',
  'gmail.mail.search',
  'gmail.draft.create',
  'gmail.open.web',
  'gmail.message.send',
  'Google Workspace MCP OAuth',
  '授权 Gmail',
  'UnsafeActionBlocked',
  '不会模拟 Gmail 邮件',
  '不会自动发送 Gmail',
  'AMAP_MAPS_API_KEY',
  'Authorization',
  'API_KEY',
  '歌者PPT',
  '多展示一些',
  '选最快的',
  'SocialHub',
  '社交工作台',
  'social.feed.search',
  'x.post.search',
  '生成草稿',
  'Slack',
  '企业微信'
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
  'Google Places API 调用失败',
  'Gmail 调用失败',
  'Gmail API 调用失败',
  'Gmail MCP 调用失败',
  'QQ 邮箱调用失败',
  'QQ IMAP timeout',
  'Operation timeout',
  '2300028',
  'MCP 工具调用失败',
  'Internal error',
  '2300999',
  'Bad Request',
  '暂无可展示数据',
  '暂不支持的组件',
  '把一句话变成可执行界面',
  '告诉 AIPhone 你要安排的事',
  '[object Object]',
  '{"version"'
];

const finalLayoutRouteMarkers = [
  '北京',
  '上海'
];

const finalLayoutBlockingPatterns = [
  { name: 'iso-date', pattern: /\b20\d{2}[-/]\d{1,2}[-/]\d{1,2}\b/ },
  { name: 'zh-date', pattern: /\b\d{4}年\d{1,2}月\d{1,2}日\b/ }
];

const forbiddenGmailSendSuccessPatterns = [
  { name: 'gmail-send-success-en', pattern: /sent successfully|message sent/i },
  { name: 'gmail-send-success-zh', pattern: /发送成功|已发送成功|邮件已发送/ }
];

const retryableProviderLayoutMarkers = [
  'Google Places API 调用失败',
  'Gmail 调用失败',
  'Gmail API 调用失败',
  'QQ 邮箱调用失败',
  'QQ IMAP timeout',
  'Operation timeout',
  '2300028'
];

const socialHubTruthfulBlockingMarkers = [
  '需要供应商配置',
  '需要配置：',
  '查询失败',
  'Operation timeout',
  '2300028',
  'MCP 工具调用失败',
  'Internal error',
  '2300999',
  'Bad Request'
];

const argv = process.argv.slice(2);
const cleanData = process.env.AIPHONE_SMOKE_CLEAN_DATA === '1' || argv.includes('--clean-data');
const runDynamicCases = argv.includes('--dynamic-tools');
const runGoogleApps = argv.includes('--google-apps');
const runFullRegression = argv.includes('--full-regression');
const queryArgs = argv.filter((arg) => arg !== '--clean-data' && arg !== '--dynamic-tools' && arg !== '--google-apps' && arg !== '--full-regression');
const selectedDefaultCases = runFullRegression ? fullRegressionCases : (runGoogleApps ? defaultCases.concat(googleAppCases) : (runDynamicCases ? defaultCases.concat(dynamicCases) : defaultCases));
const useDefaultCases = queryArgs.length === 0;
const queries = useDefaultCases ? selectedDefaultCases.map((testCase) => testCase.query) : queryArgs;
const target = process.env.AIPHONE_HDC_TARGET || firstTarget();
const timeoutMs = Number.parseInt(process.env.AIPHONE_QUERY_TIMEOUT_MS || '90000', 10);
const queryRetryLimit = Number.parseInt(process.env.AIPHONE_QUERY_RETRY_LIMIT || '2', 10);

function expectedCaseForQuery(query) {
  if (/^你好$|问候|打招呼/.test(query)) {
    return {
      expectsTool: false,
      expectedToolId: ''
    };
  }
  if (/船票|轮渡|客船|渡轮|码头/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'dynamic.search',
      expectedDiscoveredToolId: 'none'
    };
  }
  if (/天气|气温|下雨|降雨/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'dynamic.search',
      expectedDiscoveredToolId: 'weather.query'
    };
  }
  if (/统计局|GDP|CPI|人口|经济数据/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'dynamic.search',
      expectedDiscoveredToolId: 'statistics.search'
    };
  }
  if (/PPT|ppt|幻灯片|演示文稿/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'dynamic.search',
      expectedDiscoveredToolId: 'ppt.generate'
    };
  }
  if (isXPostSearchQuery(query) && (!isSocialFeedQuery(query) || /公开\s*posts?\b|public\s+posts?\b|x\.com/i.test(query))) {
    return {
      expectsTool: true,
      expectedToolId: 'x.post.search'
    };
  }
  if (isSocialFeedQuery(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'social.feed.search'
    };
  }
  if (/邮箱|邮件|收件箱/.test(query) && isMailAggregationQuery(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'mail.search'
    };
  }
  if (/邮箱|邮件|收件箱/.test(query) && !/Gmail|谷歌邮箱|谷歌邮件/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: /写一封|写邮件|起草|草稿|回复|撰写/.test(query) ? 'mail.draft.create' : 'mail.search'
    };
  }
  if (/Gmail|谷歌邮箱|谷歌邮件/.test(query) && /打开|网页版|网页/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'gmail.open.web'
    };
  }
  if (/Gmail|谷歌邮箱|谷歌邮件/.test(query) && /直接发送|立刻发送|马上发送|不确认直接发/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'gmail.message.send'
    };
  }
  if (/Gmail|谷歌邮箱|谷歌邮件/.test(query) && /写一封|写邮件|起草|草稿|回复|撰写/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'gmail.draft.create'
    };
  }
  if (/Gmail|谷歌邮箱|谷歌邮件/.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'gmail.mail.search'
    };
  }
  if (/YouTube|油管/i.test(query) && /播放列表|playlist/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'youtube.mine.playlists'
    };
  }
  if (/YouTube|油管/i.test(query) && /订阅|subscriptions?/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'youtube.mine.subscriptions'
    };
  }
  if (isYouTubeBilibiliQuery(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'media.video.search'
    };
  }
  if (/YouTube|油管/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'youtube.video.search'
    };
  }
  if (/B站|B 站|Bilibili|哔哩哔哩/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: 'media.video.search'
    };
  }
  if (/Google\s*Calendar|谷歌日历/i.test(query) || /日程|会议|约会/.test(query)) {
    if (/创建|新建|添加|安排|预约/.test(query)) {
      return {
        expectsTool: true,
        expectedToolId: 'calendar.event.create'
      };
    }
    if (/更新|修改|改到|改为|调整/.test(query)) {
      return {
        expectsTool: true,
        expectedToolId: 'calendar.event.update'
      };
    }
    return {
      expectsTool: true,
      expectedToolId: 'calendar.events.search'
    };
  }
  if (/Google\s*Maps?|Google\s*Places|GMap|谷歌地图/i.test(query)) {
    return {
      expectsTool: true,
      expectedToolId: /详情|placeId|地点 ID|地点ID/i.test(query) ? 'maps.place.details' : 'maps.place.search'
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
  if (/附近|周边|外卖|咖啡|奶茶|肯德基|麦当劳|瑞幸|汉堡|餐饮|美食/.test(query)) {
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
  const result = spawnSync('hdc', ['list', 'targets'], { encoding: 'utf8', timeout: 12000 });
  const output = `${result.stdout || ''}${result.stderr || ''}`.trim();
  if (result.error !== undefined) {
    throw new Error(`hdc list targets failed before finding a device: ${result.error.message}`);
  }
  if (result.status !== 0 || /Connect server failed/i.test(output)) {
    throw new Error(`hdc list targets failed before finding a device: ${output}`);
  }
  const lines = output.split('\n').map((line) => line.trim()).filter((line) => line.length > 0 && !/list of targets/i.test(line));
  if (lines.length === 0) {
    throw new Error(`No hdc target found. Set AIPHONE_HDC_TARGET. hdc output: ${output}`);
  }
  return lines[0];
}

function hdc(args, options = {}) {
  const result = spawnSync('hdc', ['-t', target, ...args], {
    encoding: 'utf8',
    maxBuffer: 20 * 1024 * 1024,
    ...options
  });
  const output = `${result.stdout || ''}${result.stderr || ''}`;
  if (result.status !== 0 || /Connect server failed/i.test(output)) {
    throw new Error(`hdc ${args.join(' ')} failed:\n${result.stdout}\n${result.stderr}`);
  }
  return result.stdout;
}

function appWindowRect() {
  const output = hdc(['shell', 'hidumper', '-s', 'WindowManagerService', '-a', '-a']);
  const line = output.split('\n').find((value) => value.includes('aiphonedemo'));
  if (line === undefined) {
    return null;
  }
  const match = /\[\s*(-?\d+)\s+(-?\d+)\s+(\d+)\s+(\d+)\s+\]/.exec(line);
  if (match === null) {
    return null;
  }
  return {
    x: Number.parseInt(match[1], 10),
    y: Number.parseInt(match[2], 10),
    width: Number.parseInt(match[3], 10),
    height: Number.parseInt(match[4], 10)
  };
}

function moveAppWindowIntoScreenshot() {
  const rect = appWindowRect();
  if (rect === null || rect.y >= 0 && rect.y <= 220) {
    return;
  }
  const x = Math.max(80, Math.floor(rect.x + rect.width / 2));
  const fromY = Math.max(40, rect.y + 40);
  hdc(['shell', 'uitest', 'uiInput', 'drag', String(x), String(fromY), String(x), '120', '2000']);
  spawnSync('sleep', ['1']);
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
  const hdcUnavailable = /Connect server failed/i.test(output);
  const connectionRefused = hdcUnavailable || /Failed to connect|Couldn.t connect|Connection refused|curl:\s*\(7\)/i.test(output);
  const listenerReachable = !connectionRefused && (
    /403|Call is not allowed/i.test(output) ||
    (result.status === 0 && output.length > 0 && !/curl:\s*\(\d+\)/i.test(output))
  );
  return {
    status: result.status,
    hdcUnavailable,
    listenerReachable,
    connectionRefused,
    output: output.length > 500 ? `${output.slice(0, 500)}...<truncated>` : output
  };
}

function startModelFoundation() {
  const result = spawnSync('hdc', ['-t', target, 'shell', 'aa', 'start', '-b', 'com.huawei.hmos.hmmodelfoundation', '-a', 'EntryAbility'], {
    encoding: 'utf8',
    maxBuffer: 2 * 1024 * 1024
  });
  return {
    status: result.status,
    output: `${result.stdout || ''}${result.stderr || ''}`.trim()
  };
}

async function ensureLocalModel() {
  const initial = probeLocalModel();
  if (initial.hdcUnavailable) {
    throw new Error(`hdc unavailable before local model probe: ${initial.output}`);
  }
  if (!initial.connectionRefused) {
    return initial;
  }
  const recovery = startModelFoundation();
  await sleep(3000);
  const afterStart = probeLocalModel();
  if (afterStart.hdcUnavailable) {
    throw new Error(`hdc unavailable after model foundation recovery attempt: ${afterStart.output}`);
  }
  return {
    ...afterStart,
    recovery
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

function parseBounds(bounds) {
  const match = /^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/.exec(bounds || '');
  if (!match) {
    return null;
  }
  const left = Number.parseInt(match[1], 10);
  const top = Number.parseInt(match[2], 10);
  const right = Number.parseInt(match[3], 10);
  const bottom = Number.parseInt(match[4], 10);
  return {
    left,
    top,
    right,
    bottom,
    width: right - left,
    height: bottom - top,
    x: Math.floor((left + right) / 2),
    y: Math.floor((top + bottom) / 2)
  };
}

function center(bounds) {
  const parsed = parseBounds(bounds);
  if (parsed === null) {
    return null;
  }
  return {
    x: parsed.x,
    y: parsed.y
  };
}

function verticallyOverlaps(a, b) {
  return a.top <= b.bottom && b.top <= a.bottom;
}

function attrIsTrue(value) {
  return value === true || value === 'true';
}

function attrIsFalse(value) {
  return value === false || value === 'false';
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
  moveAppWindowIntoScreenshot();
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

function findTextCenter(layout, marker) {
  const matches = findTextMatches(layout, marker);
  if (matches.length === 0) {
    return null;
  }
  return {
    x: matches[0].bounds.x,
    y: matches[0].bounds.y
  };
}

function findTextCenters(layout, marker) {
  return findTextMatches(layout, marker).map((match) => ({ x: match.bounds.x, y: match.bounds.y }));
}

function findTextMatches(layout, marker) {
  const matches = [];
  walk(layout, (node) => {
    const attrs = node.attributes || {};
    const bounds = parseBounds(attrs.bounds);
    if (bounds === null) {
      return;
    }
    const text = ['text', 'content', 'description', 'hint']
      .map((key) => attrs[key])
      .filter((value) => typeof value === 'string' && value.includes(marker))
      .join('|');
    if (text.length > 0) {
      matches.push({
        text,
        bounds
      });
    }
  });
  matches.sort((a, b) => a.bounds.top - b.bounds.top || a.bounds.left - b.bounds.left);
  return matches;
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
  let inputBounds = null;
  let generate = null;
  const clickable = [];
  walk(layout, (node) => {
    const attrs = node.attributes || {};
    const bounds = parseBounds(attrs.bounds);
    if ((attrs.type === 'TextInput' || attrs.type === 'TextArea') && input === null && bounds !== null) {
      inputBounds = bounds;
      input = {
        x: bounds.x,
        y: bounds.y
      };
    }
    if (bounds !== null && attrIsTrue(attrs.clickable) && !attrIsFalse(attrs.enabled)) {
      clickable.push({
        type: attrs.type || '',
        text: attrs.text || '',
        bounds
      });
    }
    if (attrs.type === 'Button' && attrs.text === '生成' && bounds !== null) {
      generate = {
        x: bounds.x,
        y: bounds.y
      };
    }
  });
  if (input === null) {
    throw new Error('Could not locate AIPhone input control.');
  }
  if (generate === null && inputBounds !== null) {
    const sendCandidate = clickable
      .filter((item) => item.bounds.left >= inputBounds.right - 4 &&
        item.bounds.left <= inputBounds.right + 360 &&
        verticallyOverlaps(item.bounds, inputBounds) &&
        item.bounds.width >= 24 &&
        item.bounds.width <= 180 &&
        item.bounds.height >= 24 &&
        item.bounds.height <= 180)
      .sort((a, b) => b.bounds.x - a.bounds.x)[0];
    if (sendCandidate) {
      generate = {
        x: sendCandidate.bounds.x,
        y: sendCandidate.bounds.y
      };
    }
  }
  if (generate === null) {
    throw new Error('Could not locate AIPhone send control.');
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
    let doneAt = 0;
    while (Date.now() - started < timeoutMs) {
      await sleep(500);
      const text = logs.join('\n');
      const done = /\[AIPhone\]\[(ToolResult|A2uiHomeToolResult)\] ok=/.test(text) ||
        /\[AIPhone\]\[(ToolRequest|A2uiHomeToolRequest)\] none/.test(text);
      const hasQueryHtmlDocument = /\[AIPhone\]\[HtmlHomeDocument\][^\n]*source=(?!welcome\b)[^ \n]+[^\n]*chars=\d+[^\n]*blocks=\d+/.test(text);
      if (done && doneAt === 0) {
        doneAt = Date.now();
      }
      if (done && (hasQueryHtmlDocument || Date.now() - doneAt > 3000)) {
        break;
      }
      const modelFailed = /\[AIPhone\]\[(ModelResult|A2uiHomeModelResult)\] ok=false/.test(text);
      const hasToolRequest = /\[AIPhone\]\[(ToolRequest|A2uiHomeToolRequest|A2uiHomeToolRequestFromModel)\][^\n]*toolId=/.test(text);
      if (modelFailed && !hasToolRequest && Date.now() - started > 5000) {
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

function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function htmlHomeDocumentEvidence(logs) {
  const documents = [];
  for (const line of logs) {
    const match = /\[AIPhone\]\[HtmlHomeDocument\][^\n]*source=([^ \n]+)[^\n]*kind=([^ \n]+)[^\n]*chars=(\d+)[^\n]*blocks=(\d+)/.exec(line);
    if (match === null) {
      continue;
    }
    documents.push({
      source: match[1],
      kind: match[2],
      chars: Number.parseInt(match[3], 10),
      blocks: Number.parseInt(match[4], 10)
    });
  }
  const queryDocuments = documents.filter((document) => document.source !== 'welcome');
  return {
    count: documents.length,
    queryCount: queryDocuments.length,
    maxChars: documents.reduce((max, document) => Math.max(max, document.chars), 0),
    maxBlocks: documents.reduce((max, document) => Math.max(max, document.blocks), 0),
    ok: queryDocuments.some((document) => document.chars > 0 && document.blocks > 0)
  };
}

function htmlHomeSurfaceLoadEvidence(logs) {
  const loads = [];
  for (const line of logs) {
    const match = /\[AIPhone\]\[HtmlHomeSurfaceLoad\][^\n]*chars=(\d+)[^\n]*renderTick=(\d+)/.exec(line);
    if (match === null) {
      continue;
    }
    loads.push({
      chars: Number.parseInt(match[1], 10),
      renderTick: Number.parseInt(match[2], 10)
    });
  }
  return {
    count: loads.length,
    maxChars: loads.reduce((max, load) => Math.max(max, load.chars), 0),
    ok: loads.some((load) => load.chars > 0)
  };
}

function analyze(query, logs, expectedTool, expectedToolId = '', expectedDiscoveredToolId = '') {
  const text = logs.join('\n');
  const htmlHomeDocument = htmlHomeDocumentEvidence(logs);
  const htmlHomeSurfaceLoad = htmlHomeSurfaceLoadEvidence(logs);
  const escapedToolId = escapeRegExp(expectedToolId);
  const toolIdPattern = expectedToolId.length > 0 ?
    new RegExp(`\\[AIPhone\\]\\[(ToolRequest|A2uiHomeToolRequest|A2uiHomeToolRequestFromModel)\\][^\\n]*toolId=${escapedToolId}`) :
    null;
  const hasExpectedToolId = toolIdPattern === null ? true : toolIdPattern.test(text);
  const discoveryPattern = expectedDiscoveredToolId.length > 0 ?
    new RegExp(`\\[AIPhone\\]\\[DynamicToolDiscovery\\][^\\n]*selectedToolId=${expectedDiscoveredToolId.replace('.', '\\.')}`) :
    null;
  const hasExpectedDiscoveredToolId = discoveryPattern === null ? true : discoveryPattern.test(text);
  const missingConfig = /\[AIPhone\]\[LocalToolMissingConfig\]/.test(text);
  const modelSelectedExpectedToolId = expectedToolId.length === 0 ||
    new RegExp(`"toolId":"${escapedToolId}"`).test(text) ||
    new RegExp(`toolId=${escapedToolId}`).test(text);
  const result = {
    query,
    expectedTool,
    expectedToolId,
    expectedDiscoveredToolId,
    hasExpectedToolId,
    hasExpectedDiscoveredToolId,
    htmlHomeDocument,
    htmlHomeSurfaceLoad,
    htmlLoadError: /\[AIPhone\]\[HtmlHomeSurfaceLoadError\]/.test(text),
    modelSelectedExpectedToolId,
    directIntent: /\[AIPhone\]\[(ToolRequestByIntent|A2uiHomeToolRequestByIntent)\] toolId=/.test(text),
    localToolRequest: /\[AIPhone\]\[LocalToolRequest\] endpoint=local:\/\/aiphone-tools toolId=/.test(text),
    model200: /\[AIPhone\]\[(ModelStreamResponse|ModelRawResponse)\] code=200/.test(text) || /response_code":200[\s\S]*dst_port":11434/.test(text),
    modelOk: /\[AIPhone\]\[(ModelResult|A2uiHomeModelResult)\] ok=true/.test(text),
    toolRequested: /\[AIPhone\]\[(ToolRequest|A2uiHomeToolRequest|A2uiHomeToolRequestFromModel)\][^\n]*toolId=/.test(text),
    toolOk: /\[AIPhone\]\[(ToolResult|A2uiHomeToolResult)\] ok=true/.test(text),
    failedConnect: /failed to connect|Could not connect|Couldn.t connect|ECONNREFUSED|server is not running|CURLcode result 7|curl_code":7|os_errno":111/i.test(text),
    providerFailed: /\[AIPhone\]\[LocalTool12306Endpoint\][^\n]*code=[45]\d\d/.test(text) ||
      /\[AIPhone\]\[LocalToolException\]/.test(text) ||
      /Google Calendar API 调用失败/.test(text) ||
      (missingConfig && expectedToolId !== 'travel.search'),
    modelFailed: /\[AIPhone\]\[(ModelResult|A2uiHomeModelResult)\] ok=false/.test(text),
    toolNone: /\[AIPhone\]\[(ToolRequest|A2uiHomeToolRequest)\] none/.test(text),
    gmailWebOpened: /\[AIPhone\]\[A2uiHomeOpenUrl\] ok=true url=https:\/\/mail\.google\.com/.test(text),
    syntheticFallback: forbiddenSyntheticMarkers.some((marker) => text.includes(marker))
  };
  const modelFallbackOnlyAfterSameToolSelection = result.modelFailed && result.directIntent && result.modelSelectedExpectedToolId;
  const modelPassed = modelFallbackOnlyAfterSameToolSelection || (result.model200 && result.modelOk && !result.modelFailed);
  const htmlDocumentPassed = result.htmlHomeDocument.ok ||
    (isSocialHubExpectedToolId(expectedToolId) && result.htmlHomeDocument.count > 0);
  const baseWithoutTransport = !result.htmlLoadError &&
    result.htmlHomeSurfaceLoad.ok &&
    !result.syntheticFallback &&
    (!result.directIntent || modelFallbackOnlyAfterSameToolSelection) &&
    htmlDocumentPassed;
  result.modelPassed = modelPassed;
  result.transportPassed = !result.failedConnect && !result.providerFailed;
  result.basePassedWithoutTransport = baseWithoutTransport;
  const basePassed = result.transportPassed && baseWithoutTransport;
  if (expectedTool === true) {
    result.ok = basePassed && modelPassed && result.toolRequested && result.localToolRequest && result.toolOk && result.hasExpectedToolId && result.hasExpectedDiscoveredToolId;
  } else if (expectedTool === false) {
    result.ok = basePassed && modelPassed && result.toolNone && !result.toolRequested && !result.localToolRequest;
  } else {
    result.ok = basePassed && modelPassed &&
      (result.toolRequested ? (result.localToolRequest && result.toolOk) : (result.toolNone && !result.localToolRequest));
  }
  return result;
}

function isGmailWebQuery(query) {
  return /Gmail|谷歌邮箱|谷歌邮件/.test(query) && /打开|网页版|网页/.test(query);
}

function isGmailEccvQuery(query) {
  return /Gmail|谷歌邮箱|谷歌邮件/.test(query) && /eccv/i.test(query);
}

function isQqMailQuery(query) {
  return /QQ\s*邮箱|QQ邮箱/i.test(query);
}

function isMailAggregationQuery(query) {
  return /Gmail|谷歌邮箱|谷歌邮件/.test(query) && isQqMailQuery(query);
}

function isYouTubeBilibiliQuery(query) {
  return /YouTube|油管/i.test(query) && /B站|B 站|Bilibili|哔哩哔哩/i.test(query);
}

function isSocialFeedQuery(query) {
  return /社交|消息聚合|多平台消息|Slack|企业微信/i.test(query);
}

function isSocialHubExpectedToolId(expectedToolId) {
  return expectedToolId === 'social.feed.search' || expectedToolId === 'x.post.search';
}

function hasStandaloneXMarker(query) {
  return /(^|[^A-Za-z0-9_])X(?=$|[^A-Za-z0-9_])/i.test(query.replace(/Xcode/gi, ''));
}

function isXPostSearchQuery(query) {
  const text = query.replace(/Xcode/gi, '');
  if (/posts?\s*[- ]?\s*processing/i.test(text)) {
    return false;
  }
  const hasPlatform = /Twitter|推文|x\.com/i.test(text) ||
    (hasStandaloneXMarker(text) && /上|平台|推文|公开\s*posts?\b|public\s+posts?\b/i.test(text));
  return hasPlatform && /读|看|查看|查|查询|搜索|搜|最近|公开|read|search|find|recent|latest|public/i.test(text);
}

function hasTruthfulSocialHubState(text) {
  return /SocialHub/.test(text) &&
    /社交工作台/.test(text) &&
    /待授权|等待授权接入|异常|受限|已连接|未配置|Social bridge unavailable|HTTP|scope|rate|token|configured|真实数据接入前|还没有真实消息/i.test(text);
}

function hasVisibleSocialHubOutput(text, expectedToolId) {
  if (!hasTruthfulSocialHubState(text)) {
    return false;
  }
  if (expectedToolId === 'x.post.search') {
    return /\bX\b/.test(text);
  }
  if (expectedToolId === 'social.feed.search') {
    return /\bX\b/.test(text) && /Slack/.test(text) && /企业微信/.test(text);
  }
  return false;
}

function isCalendarQuery(query) {
  return /Google\s*Calendar|谷歌日历/i.test(query) || /日程|会议|约会/.test(query);
}

function layoutExpectationsForQuery(query) {
  if (/^你好$|问候|打招呼/.test(query)) {
    return ['你好'];
  }
  if (/船票|轮渡|客船|渡轮|码头/.test(query)) {
    return ['接入工具', 'dynamic.search', '没有找到'];
  }
  if (/天气|气温|下雨|降雨/.test(query)) {
    return ['接入工具', 'weather.query', 'AMAP_MAPS_API_KEY', '高德天气预报', '预报日期'];
  }
  if (/统计局|GDP|CPI|人口|经济数据/.test(query)) {
    return ['接入工具', 'statistics.search', 'Authorization', '中国国家统计局'];
  }
  if (/PPT|ppt|幻灯片|演示文稿/.test(query)) {
    return ['接入工具', 'ppt.generate', 'API_KEY', 'unsupported_transport', '歌者PPT'];
  }
  if (isXPostSearchQuery(query) && (!isSocialFeedQuery(query) || /公开\s*posts?\b|public\s+posts?\b|x\.com/i.test(query))) {
    return ['SocialHub', '公开 post', 'x.post.search', 'X'];
  }
  if (isSocialFeedQuery(query)) {
    return ['SocialHub', '社交工作台', 'Slack', '企业微信', 'social.feed.search'];
  }
  if (isMailAggregationQuery(query)) {
    return ['mail.search', 'Gmail', 'QQ Mail', '不会模拟'];
  }
  if (isQqMailQuery(query)) {
    return ['mail.search', 'QQ Mail', '不会模拟'];
  }
  if (/邮箱|邮件|收件箱/.test(query) && !/Gmail|谷歌邮箱|谷歌邮件/.test(query)) {
    return ['mail.search', 'Gmail', 'QQ Mail', '不会模拟'];
  }
  if (isGmailWebQuery(query)) {
    return ['Gmail Web', 'gmail.open.web', 'https://mail.google.com'];
  }
  if (/Gmail|谷歌邮箱|谷歌邮件/.test(query) && /直接发送|立刻发送|马上发送|不确认直接发/.test(query)) {
    return ['UnsafeActionBlocked', '不会自动发送 Gmail', 'gmail.message.send'];
  }
  if (/Gmail|谷歌邮箱|谷歌邮件/.test(query) && /写一封|写邮件|起草|草稿|回复|撰写/.test(query)) {
    return ['gmail.draft.create', 'Google Workspace MCP OAuth', '授权 Gmail', 'Draft saved', 'Saved in Gmail', 'ready_to_apply', '不会模拟 Gmail 邮件'];
  }
  if (isGmailEccvQuery(query)) {
    return ['Gmail', 'gmail.mail.search', 'eccv', 'ECCV', '不会模拟 Gmail 邮件'];
  }
  if (/Gmail|谷歌邮箱|谷歌邮件/.test(query)) {
    return ['Gmail', 'gmail.mail.search', 'Google Workspace MCP OAuth', '授权 Gmail', '不会模拟 Gmail 邮件', '没有找到匹配邮件'];
  }
  if (/YouTube|油管/i.test(query) && /播放列表|playlist/i.test(query)) {
    return ['YouTube', 'youtube.mine.playlists', 'OAuth', '不会模拟播放列表'];
  }
  if (/YouTube|油管/i.test(query) && /订阅|subscriptions?/i.test(query)) {
    return ['YouTube', 'youtube.mine.subscriptions', 'OAuth', '不会模拟播放列表'];
  }
  if (isYouTubeBilibiliQuery(query)) {
    return ['YouTube', 'YouTube Data API', '哔哩哔哩', 'Bilibili'];
  }
  if (/YouTube|油管/i.test(query)) {
    return ['YouTube', 'youtube.video.search', 'YouTube Data API', 'YOUTUBE_API_KEY'];
  }
  if (/B站|B 站|Bilibili|哔哩哔哩/i.test(query)) {
    return ['哔哩哔哩', 'media.video.search', '跳转'];
  }
  if (isCalendarQuery(query)) {
    return /创建|新建|添加|安排|预约/.test(query)
      ? ['Google Calendar API', '天', '周', '月', '日视图', '已写入', '一对一会议', '16:30', '17:00']
      : ['Google Calendar API', '天', '周', '月', '日视图'];
  }
  if (/Google\s*Maps?|Google\s*Places|GMap|谷歌地图/i.test(query)) {
    return ['Google Places', 'Google Maps', 'GOOGLE_MAPS_API_KEY', 'maps.place.search'];
  }
  if (/出行方案|搜索出行|怎么去|比较出行|出行选项|整理可查|可查的出行/.test(query)) {
    return ['北京', '上海'];
  }
  if (/航班|机票|飞机/.test(query)) {
    return ['航班', '飞常准', 'flight.search', '来源状态'];
  }
  if (/高铁|火车|车票|12306/.test(query)) {
    return ['高铁', '12306', 'train.search'];
  }
  if (/附近|周边|外卖|咖啡|奶茶|肯德基|麦当劳|瑞幸|汉堡|餐饮|美食/.test(query)) {
    return ['奶茶', '餐饮', '高德', '腾讯地图', '百度地图', '美团', '淘宝闪购'];
  }
  return [];
}

function swipeResultsUp() {
  hdc(['shell', 'uitest', 'uiInput', 'swipe', '650', '2200', '650', '950', '600']);
}

function requiredScrolledMarkersForQuery(query, expectedToolId) {
  if (expectedToolId === 'mail.search') {
    if (isQqMailQuery(query)) {
      return ['QQ Mail'];
    }
    return ['Gmail', 'QQ Mail'];
  }
  if (expectedToolId === 'gmail.mail.search' && isGmailEccvQuery(query)) {
    return ['ECCV'];
  }
  return [];
}

async function collectScrolledLayoutEvidence(initialLayout, initialText, index, requiredMarkers) {
  const texts = [initialText];
  const layoutPaths = [join(outDir, `query-${index + 1}-final-layout.json`)];
  const textPaths = [join(outDir, `query-${index + 1}-final-layout-text.txt`)];
  const screenPaths = [];
  let currentLayout = initialLayout;
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const combinedText = texts.join('\n');
    if (requiredMarkers.every((marker) => combinedText.includes(marker))) {
      break;
    }
    swipeResultsUp();
    await sleep(900);
    currentLayout = dumpLayout(`query-${index + 1}-scroll-${attempt + 1}-layout.json`);
    const scrolledText = collectLayoutText(currentLayout).join('\n');
    const scrolledTextPath = join(outDir, `query-${index + 1}-scroll-${attempt + 1}-layout-text.txt`);
    writeFileSync(scrolledTextPath, scrolledText + '\n');
    const scrolledScreenPath = captureScreen(`query-${index + 1}-scroll-${attempt + 1}-screen.png`);
    texts.push(scrolledText);
    layoutPaths.push(join(outDir, `query-${index + 1}-scroll-${attempt + 1}-layout.json`));
    textPaths.push(scrolledTextPath);
    screenPaths.push(scrolledScreenPath);
  }
  const uniqueText = [...new Set(texts.join('\n').split('\n').filter((line) => line.trim().length > 0))].join('\n');
  const combinedTextPath = join(outDir, `query-${index + 1}-scrolled-layout-text.txt`);
  writeFileSync(combinedTextPath, uniqueText + '\n');
  return {
    text: uniqueText,
    currentLayout,
    combinedTextPath,
    layoutPaths,
    textPaths,
    screenPaths,
    requiredMarkers,
    foundMarkers: requiredMarkers.filter((marker) => uniqueText.includes(marker))
  };
}

function expandMatchesForTarget(layout, targetMarker) {
  const expands = findTextMatches(layout, '展开')
    .filter((item) => item.bounds.y > 400 && item.bounds.y < 2450);
  if (targetMarker.length === 0) {
    return expands;
  }
  const targets = findTextMatches(layout, targetMarker);
  if (targets.length === 0) {
    return [];
  }
  return expands
    .filter((expand) => targets.some((target) =>
      Math.abs(expand.bounds.y - target.bounds.y) < 360 ||
      verticallyOverlaps(expand.bounds, target.bounds)))
    .sort((left, right) => {
      const leftDistance = Math.min(...targets.map((target) => Math.abs(left.bounds.y - target.bounds.y)));
      const rightDistance = Math.min(...targets.map((target) => Math.abs(right.bounds.y - target.bounds.y)));
      return leftDistance - rightDistance;
    });
}

async function findVisibleReplyDraftAction(layout, index) {
  let currentLayout = layout;
  let actionText = collectLayoutText(currentLayout).join('\n');
  let actionLayoutPath = '';
  let actionTextPath = '';
  let actionScreenPath = '';
  for (let attempt = 0; attempt < 4; attempt += 1) {
    actionLayoutPath = join(outDir, `query-${index + 1}-mail-action-${attempt + 1}-layout.json`);
    actionTextPath = join(outDir, `query-${index + 1}-mail-action-${attempt + 1}-layout-text.txt`);
    writeFileSync(actionLayoutPath, JSON.stringify(currentLayout, null, 2));
    writeFileSync(actionTextPath, actionText + '\n');
    actionScreenPath = captureScreen(`query-${index + 1}-mail-action-${attempt + 1}-screen.png`);
    if (actionText.includes('AI 回复草稿')) {
      return {
        layout: currentLayout,
        text: actionText,
        layoutPath: actionLayoutPath,
        textPath: actionTextPath,
        screenPath: actionScreenPath
      };
    }
    swipeResultsUp();
    await sleep(800);
    currentLayout = dumpLayout(`query-${index + 1}-mail-action-${attempt + 2}-layout.json`);
    actionLayoutPath = join(outDir, `query-${index + 1}-mail-action-${attempt + 2}-layout.json`);
    actionText = collectLayoutText(currentLayout).join('\n');
  }
  return {
    layout: currentLayout,
    text: actionText,
    layoutPath: actionLayoutPath,
    textPath: actionTextPath,
    screenPath: actionScreenPath
  };
}

async function verifyMailExpandedActions(layout, index, appPid, targetMarker = '') {
  let currentLayout = layout;
  let lastExpandedText = '';
  let lastExpandedTextPath = '';
  let lastExpandedLayoutPath = '';
  let lastExpandedScreenPath = '';
  for (let page = 0; page < 6; page += 1) {
    const matches = expandMatchesForTarget(currentLayout, targetMarker);
    for (let matchIndex = 0; matchIndex < matches.length; matchIndex += 1) {
      const clickTarget = matches[matchIndex].bounds;
      hdc(['shell', 'uitest', 'uiInput', 'click', String(clickTarget.x), String(clickTarget.y)]);
      await sleep(900);
      currentLayout = dumpLayout(`query-${index + 1}-mail-expanded-layout.json`);
      lastExpandedLayoutPath = join(outDir, `query-${index + 1}-mail-expanded-layout.json`);
      lastExpandedText = collectLayoutText(currentLayout).join('\n');
      lastExpandedTextPath = join(outDir, `query-${index + 1}-mail-expanded-layout-text.txt`);
      writeFileSync(lastExpandedTextPath, lastExpandedText + '\n');
      lastExpandedScreenPath = captureScreen(`query-${index + 1}-mail-expanded-screen.png`);
      const actionEvidence = await findVisibleReplyDraftAction(currentLayout, index);
      lastExpandedText = actionEvidence.text;
      lastExpandedTextPath = actionEvidence.textPath;
      lastExpandedLayoutPath = actionEvidence.layoutPath;
      lastExpandedScreenPath = actionEvidence.screenPath;
      currentLayout = actionEvidence.layout;
      if (!actionEvidence.text.includes('AI 回复草稿')) {
        continue;
      }
      const draftCenter = findTextCenter(actionEvidence.layout, 'AI 回复草稿');
      if (draftCenter === null) {
        return {
          clicked: true,
          actionVisible: true,
          draftClicked: false,
          draftToolRequested: false,
          draftToolOk: false,
          draftVisible: false,
          targetMarker,
          reason: 'AI 回复草稿 was visible but no clickable center was found.',
          layoutPath: lastExpandedLayoutPath,
          layoutTextPath: lastExpandedTextPath,
          screenPath: lastExpandedScreenPath
        };
      }
      clearHilog();
      await sleep(300);
      const draftLogs = await captureWhile(appPid, async () => {
        hdc(['shell', 'uitest', 'uiInput', 'click', String(draftCenter.x), String(draftCenter.y)]);
      });
      const draftLogPath = join(outDir, `query-${index + 1}-mail-draft.log`);
      writeFileSync(draftLogPath, draftLogs.join('\n') + '\n');
      const draftLogText = draftLogs.join('\n');
      const draftLayout = dumpLayout(`query-${index + 1}-mail-draft-layout.json`);
      const draftLayoutPath = join(outDir, `query-${index + 1}-mail-draft-layout.json`);
      const draftText = collectLayoutText(draftLayout).join('\n');
      const draftTextPath = join(outDir, `query-${index + 1}-mail-draft-layout-text.txt`);
      writeFileSync(draftTextPath, draftText + '\n');
      const draftScreenPath = captureScreen(`query-${index + 1}-mail-draft-screen.png`);
      const draftToolRequested = /\[AIPhone\]\[(ToolRequest|A2uiHomeToolRequest|A2uiHomeToolRequestFromModel)\][^\n]*toolId=(gmail|mail)\.draft\.create/.test(draftLogText) ||
        /\[AIPhone\]\[LocalToolRequest\][^\n]*toolId=(gmail|mail)\.draft\.create/.test(draftLogText) ||
        /\b(gmail|mail)\.draft\.create\b/.test(draftText);
      const draftToolOk = draftToolRequested &&
        /\[AIPhone\]\[(ToolResult|A2uiHomeToolResult)\][^\n]*ok=true/.test(draftLogText) &&
        !/failed to connect|Could not connect|Couldn.t connect|ECONNREFUSED|CURLcode result 7|curl_code":7|os_errno":111/i.test(draftLogText);
      const draftVisible = /\b(gmail|mail)\.draft\.create\b|Draft saved|Saved in Gmail|Mail Draft Preview|草稿|跳转到Gmail/.test(draftText);
      const draftModelFailed = /\[AIPhone\]\[ModelException\]|\[AIPhone\]\[(ModelResult|A2uiHomeModelResult)\][^\n]*ok=false/.test(draftLogText);
      const draftProviderFailed = /Operation timeout|2300028|2300056|Failed to receive data from the peer|QQ IMAP timeout|Gmail 调用失败|QQ 邮箱调用失败/i.test(draftLogText);
      return {
        clicked: true,
        actionVisible: true,
        draftClicked: true,
        draftToolRequested,
        draftToolOk,
        draftVisible,
        draftModelFailed,
        draftProviderFailed,
        targetMarker,
        layoutPath: lastExpandedLayoutPath,
        layoutTextPath: lastExpandedTextPath,
        screenPath: lastExpandedScreenPath,
        draftLogPath,
        draftLayoutPath,
        draftTextPath,
        draftScreenPath
      };
    }
    swipeResultsUp();
    await sleep(800);
    currentLayout = dumpLayout(`query-${index + 1}-mail-search-scroll-${page + 1}-layout.json`);
  }
  if (lastExpandedText.length === 0) {
    return {
      clicked: false,
      actionVisible: false,
      draftClicked: false,
      draftToolRequested: false,
      draftToolOk: false,
      draftVisible: false,
      targetMarker,
      reason: 'Could not locate a visible mail result expand button.'
    };
  }
  return {
    clicked: true,
    actionVisible: false,
    draftClicked: false,
    draftToolRequested: false,
    draftToolOk: false,
    draftVisible: false,
    targetMarker,
    layoutPath: lastExpandedLayoutPath,
    layoutTextPath: lastExpandedTextPath,
    screenPath: lastExpandedScreenPath
  };
}

async function runQuery(query, index, expectedTool) {
  clearHilog();
  hdc(['shell', 'aa', 'force-stop', 'com.example.aiphonedemo']);
  if (cleanData) {
    cleanBundleData();
  }
  hdc(['shell', 'aa', 'start', '-a', 'EntryAbility', '-b', 'com.example.aiphonedemo']);
  await sleep(3000);
  moveAppWindowIntoScreenshot();
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
    const submitControls = await waitForControls(`query-${index + 1}-submit-layout.json`, 2);
    hdc(['shell', 'uitest', 'uiInput', 'click', String(submitControls.generate.x), String(submitControls.generate.y)]);
  });
  const logPath = join(outDir, `query-${index + 1}.log`);
  writeFileSync(logPath, logs.join('\n') + '\n');
  const expectedCase = useDefaultCases ? selectedDefaultCases[index] : expectedCaseForQuery(query);
  const expectedToolId = expectedCase.expectedToolId || '';
  const expectedDiscoveredToolId = expectedCase.expectedDiscoveredToolId || '';
  const summary = analyze(query, logs, expectedTool, expectedToolId, expectedDiscoveredToolId);
  summary.logPath = logPath;
  const layout = dumpLayout(`query-${index + 1}-final-layout.json`);
  const layoutTextValues = collectLayoutText(layout);
  const layoutText = layoutTextValues.join('\n');
  const layoutTextPath = join(outDir, `query-${index + 1}-final-layout-text.txt`);
  writeFileSync(layoutTextPath, layoutText + '\n');
  const expectedMarkers = layoutExpectationsForQuery(query);
  const scrollEvidence = await collectScrolledLayoutEvidence(
    layout,
    layoutText,
    index,
    requiredScrolledMarkersForQuery(query, expectedToolId)
  );
  const evidenceText = scrollEvidence.text;
  const evidenceLayout = scrollEvidence.currentLayout;
  const expectedHits = expectedMarkers.filter((marker) => evidenceText.includes(marker));
  const expectedMisses = expectedMarkers.filter((marker) => !evidenceText.includes(marker));
  const calendarMarkersOk = !isCalendarQuery(query) || expectedMisses.length === 0;
  const forbiddenSocialHubLegacyHits = forbiddenSocialHubLegacyMarkers.filter((marker) => evidenceText.includes(marker));
  const isSocialHubCase = isSocialHubExpectedToolId(expectedToolId);
  const socialHubVisibleOutput = isSocialHubCase && hasVisibleSocialHubOutput(evidenceText, expectedToolId);
  const allowsSocialHubTruthfulState = socialHubVisibleOutput && hasTruthfulSocialHubState(evidenceText);
  const allowsExternalGmailWeb = isGmailWebQuery(query) && summary.gmailWebOpened === true;
  const allowsPartialTravelSourceFailure = expectedToolId === 'travel.search' &&
    summary.toolOk === true &&
    (evidenceText.includes('来源状态') || evidenceText.includes('飞常准')) &&
    (evidenceText.includes('耗时') || /\bG\d+\b/.test(evidenceText) || evidenceText.includes('高铁 · 12306'));
  const layoutBlockingHits = finalLayoutBlockingMarkers.filter((marker) => {
    if (allowsPartialTravelSourceFailure && marker === '查询失败') {
      return false;
    }
    if (allowsSocialHubTruthfulState && socialHubTruthfulBlockingMarkers.includes(marker)) {
      return false;
    }
    return evidenceText.includes(marker);
  });
  if (expectedToolId === 'gmail.message.send') {
    for (const blockingPattern of forbiddenGmailSendSuccessPatterns) {
      if (blockingPattern.pattern.test(evidenceText)) {
        layoutBlockingHits.push(blockingPattern.name);
      }
    }
  }
  const providerLayoutFailed = retryableProviderLayoutMarkers.some((marker) => evidenceText.includes(marker));
  summary.providerFailed = summary.providerFailed || (providerLayoutFailed && !allowsSocialHubTruthfulState);
  summary.layoutPath = join(outDir, `query-${index + 1}-final-layout.json`);
  summary.layoutTextPath = layoutTextPath;
  summary.layoutScrolledTextPath = scrollEvidence.combinedTextPath;
  summary.layoutScrolledRequiredMarkers = scrollEvidence.requiredMarkers;
  summary.layoutScrolledFoundMarkers = scrollEvidence.foundMarkers;
  summary.layoutScrollTextPaths = scrollEvidence.textPaths;
  summary.layoutScrollScreenPaths = scrollEvidence.screenPaths;
  summary.screenPath = captureScreen(`query-${index + 1}-final-screen.png`);
  summary.layoutExpectedHits = expectedHits;
  summary.layoutExpectedMisses = expectedMisses;
  summary.socialHubVisibleOutput = socialHubVisibleOutput;
  summary.layoutForbiddenSocialHubLegacyHits = forbiddenSocialHubLegacyHits;
  summary.layoutBlockingHits = layoutBlockingHits;
  summary.gmailEccvKeywordVisible = !isGmailEccvQuery(query) || /eccv/i.test(evidenceText);
  summary.layoutTextExposed = isSocialHubCase ?
    socialHubVisibleOutput :
    (expectedMarkers.length === 0 || expectedHits.length > 0) &&
    calendarMarkersOk &&
    summary.gmailEccvKeywordVisible;
  summary.mailAggregateVisible = expectedToolId !== 'mail.search' ||
    (isMailAggregationQuery(query) ? (/Gmail/.test(evidenceText) && /QQ Mail/.test(evidenceText)) :
      (isQqMailQuery(query) ? /QQ Mail/.test(evidenceText) : (/Gmail/.test(evidenceText) && /QQ Mail/.test(evidenceText))));
  const expectsMailDraftAction = (expectedToolId === 'mail.search' && summary.mailAggregateVisible) ||
    (expectedToolId === 'gmail.mail.search' && isGmailEccvQuery(query));
  summary.mailExpandedActions = expectsMailDraftAction
    ? await verifyMailExpandedActions(evidenceLayout, index, appPid, isGmailEccvQuery(query) ? 'ECCV' : '')
    : {
      clicked: false,
      actionVisible: true,
      draftClicked: false,
      draftToolRequested: true,
      draftToolOk: true,
      draftVisible: true
    };
  summary.modelFailed = summary.modelFailed || summary.mailExpandedActions.draftModelFailed === true;
  summary.providerFailed = summary.providerFailed || summary.mailExpandedActions.draftProviderFailed === true;
  summary.layoutTextExposed = summary.layoutTextExposed &&
    summary.mailAggregateVisible &&
    summary.mailExpandedActions.actionVisible &&
    summary.mailExpandedActions.draftClicked &&
    summary.mailExpandedActions.draftToolRequested &&
    summary.mailExpandedActions.draftToolOk &&
    summary.mailExpandedActions.draftVisible;
  const allowsHtmlDocumentOnly = !isSocialHubCase && !expectsMailDraftAction && expectedToolId !== 'mail.search' && summary.htmlHomeDocument.ok;
  summary.layoutOk = layoutBlockingHits.length === 0 &&
    forbiddenSocialHubLegacyHits.length === 0 &&
    (isSocialHubCase ? socialHubVisibleOutput : (allowsExternalGmailWeb || summary.layoutTextExposed || allowsHtmlDocumentOnly));
  if (isSocialHubCase) {
    summary.ok = summary.basePassedWithoutTransport === true &&
      summary.modelPassed === true &&
      summary.toolRequested &&
      summary.localToolRequest &&
      summary.toolOk &&
      summary.hasExpectedToolId &&
      summary.hasExpectedDiscoveredToolId &&
      (summary.transportPassed === true || allowsSocialHubTruthfulState) &&
      summary.layoutOk;
  } else {
    summary.ok = summary.ok && summary.layoutOk;
  }
  return summary;
}

const modelHealth = await ensureLocalModel();
console.log(`modelHealth: ${JSON.stringify(modelHealth, null, 2)}`);
console.log(`cleanData: ${cleanData ? 'true' : 'false'}`);

const summaries = [];
for (let index = 0; index < queries.length; index += 1) {
  const query = queries[index];
  console.log(`\n[${index + 1}/${queries.length}] ${query}`);
  const inferredCase = useDefaultCases ? selectedDefaultCases[index] : expectedCaseForQuery(query);
  const expectedTool = inferredCase.expectsTool;
  let summary = null;
  for (let attempt = 0; attempt <= queryRetryLimit; attempt += 1) {
    summary = await runQuery(query, index, expectedTool);
    summary.attempt = attempt + 1;
    summary.retryLimit = queryRetryLimit;
    const missingScrolledMarkers = Array.isArray(summary.layoutScrolledRequiredMarkers) &&
      Array.isArray(summary.layoutScrolledFoundMarkers) &&
      summary.layoutScrolledRequiredMarkers.some((marker) => !summary.layoutScrolledFoundMarkers.includes(marker));
    const retryableFailure = summary.providerFailed || summary.modelFailed || missingScrolledMarkers;
    if (summary.ok || !retryableFailure || attempt === queryRetryLimit) {
      break;
    }
    console.warn(`retryable failure for query ${index + 1}, retrying attempt ${attempt + 2}/${queryRetryLimit + 1}`);
  }
  if (summary === null) {
    throw new Error(`No summary produced for query: ${query}`);
  }
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
const finalAllowsExternalGmailWeb = isGmailWebQuery(finalQuery) &&
  finalSummary !== null &&
  finalSummary.gmailWebOpened === true;
const finalAllowsSocialHubTruthfulState =
  finalSummary !== null &&
  isSocialHubExpectedToolId(finalSummary.expectedToolId) &&
  hasVisibleSocialHubOutput(finalLayoutText, finalSummary.expectedToolId);
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
  if (finalAllowsSocialHubTruthfulState && socialHubTruthfulBlockingMarkers.includes(marker)) {
    return false;
  }
  return finalLayoutText.includes(marker);
});
for (const blockingPattern of finalLayoutBlockingPatterns) {
  if (finalSummary !== null && finalSummary.expectedToolId.startsWith('calendar.')) {
    continue;
  }
  if (finalSummary !== null &&
    finalSummary.expectedToolId === 'dynamic.search' &&
    finalSummary.expectedDiscoveredToolId === 'weather.query' &&
    finalLayoutText.includes('高德天气')) {
    continue;
  }
  if (blockingPattern.pattern.test(finalLayoutText)) {
    finalLayoutBlockingHits.push(blockingPattern.name);
  }
}
if (finalSummary !== null && finalSummary.expectedToolId === 'gmail.message.send') {
  for (const blockingPattern of forbiddenGmailSendSuccessPatterns) {
    if (blockingPattern.pattern.test(finalLayoutText)) {
      finalLayoutBlockingHits.push(blockingPattern.name);
    }
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
  ok: (finalAllowsSocialHubTruthfulState || finalAllowsExternalGmailWeb || finalLayoutDomainHits.length > 0 ||
    (finalSummary !== null &&
      !isSocialHubExpectedToolId(finalSummary.expectedToolId) &&
      finalSummary.htmlHomeDocument !== undefined &&
      finalSummary.htmlHomeDocument.ok === true)) &&
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
