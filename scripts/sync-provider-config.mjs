#!/usr/bin/env node
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const envPath = join(rootDir, 'tool-gateway', '.env.local');
const outPath = join(rootDir, 'entry', 'src', 'main', 'resources', 'rawfile', 'aiphone_provider_config.json');

const providerKeys = [
  'TOOL_GATEWAY_API_KEY',
  'DASHSCOPE_API_KEY',
  'FLIGHT_MCP_KEY',
  'VARIFLIGHT_API_KEY',
  'X_VARIFLIGHT_KEY',
  'FLIGHT_API_KEY',
  'VARIFLIGHT_API_URL',
  'FLIGHT_VARIFLIGHT_URL',
  'AMAP_KEY',
  'AMAP_DEFAULT_LOCATION',
  'FOOD_DEFAULT_LOCATION',
  'AMAP_RADIUS',
  'TENCENT_MAP_KEY',
  'TENCENT_MAP_API_URL',
  'BAIDU_MAP_AK',
  'BAIDU_MAP_API_URL',
  'MEITUAN_UNION_APP_KEY',
  'MEITUAN_UNION_APP_SECRET',
  'MEITUAN_UNION_API_URL',
  'TAOBAO_APP_KEY',
  'TAOBAO_APP_SECRET',
  'TAOBAO_FLASH_PID',
  'TAOBAO_API_URL',
  'MCD_MCP_TOKEN',
  'MCD_MCP_URL',
  'LUCKIN_MCP_TOKEN',
  'LUCKIN_MCP_URL',
  'GOOGLE_MAPS_API_KEY',
  'GOOGLE_OAUTH_CLIENT_ID',
  'GOOGLE_OAUTH_CLIENT_SECRET',
  'GOOGLE_OAUTH_REDIRECT_URI',
  'GMAIL_AUTH_URL',
  'GMAIL_OAUTH_CLIENT_ID',
  'GMAIL_OAUTH_CLIENT_SECRET',
  'GMAIL_OAUTH_REDIRECT_URI',
  'YOUTUBE_API_KEY',
  'GMAIL_MCP_USER_PROJECT',
  'QQ_MAIL_ADDRESS',
  'QQ_MAIL_AUTH_CODE',
  'QQ_MAIL_IMAP_HOST',
  'QQ_MAIL_IMAP_PORT',
  'QQ_MAIL_DRAFTS_MAILBOX',
  'GOOGLE_CLOUD_PROJECT'
];

function unquote(value) {
  const trimmed = value.trim();
  if ((trimmed.startsWith('"') && trimmed.endsWith('"')) || (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
    return trimmed.slice(1, -1);
  }
  return trimmed;
}

function loadEnv(path) {
  const env = {};
  const lines = readFileSync(path, 'utf8').split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed.length === 0 || trimmed.startsWith('#')) {
      continue;
    }
    const eq = trimmed.indexOf('=');
    if (eq <= 0) {
      continue;
    }
    const key = trimmed.slice(0, eq).trim();
    const value = unquote(trimmed.slice(eq + 1));
    if (value.length > 0) {
      env[key] = value;
    }
  }
  return env;
}

function maskedStatus(config, keys) {
  return keys.map((key) => {
    const value = config[key] || '';
    return `${key}=${value.length > 0 ? `present(${value.length})` : 'missing'}`;
  }).join(' ');
}

if (!existsSync(envPath)) {
  console.error(`Missing ${envPath}. Copy tool-gateway/.env.example to .env.local and fill provider keys first.`);
  process.exit(1);
}

const env = loadEnv(envPath);
const config = {};
for (const key of providerKeys) {
  if (env[key]) {
    config[key] = env[key];
  }
}

mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, JSON.stringify(config, null, 2) + '\n');

console.log(`Wrote ${outPath}`);
console.log(maskedStatus(config, [
  'TOOL_GATEWAY_API_KEY',
  'DASHSCOPE_API_KEY',
  'FLIGHT_MCP_KEY',
  'VARIFLIGHT_API_KEY',
  'AMAP_KEY',
  'TENCENT_MAP_KEY',
  'BAIDU_MAP_AK',
  'AMAP_DEFAULT_LOCATION',
  'MEITUAN_UNION_APP_KEY',
  'TAOBAO_APP_KEY',
  'TAOBAO_FLASH_PID',
  'MCD_MCP_TOKEN',
  'LUCKIN_MCP_TOKEN',
  'GOOGLE_MAPS_API_KEY',
  'GOOGLE_OAUTH_CLIENT_ID',
  'GOOGLE_OAUTH_CLIENT_SECRET',
  'GMAIL_AUTH_URL',
  'GMAIL_OAUTH_CLIENT_ID',
  'GMAIL_OAUTH_CLIENT_SECRET',
  'YOUTUBE_API_KEY',
  'GMAIL_MCP_USER_PROJECT',
  'QQ_MAIL_ADDRESS',
  'QQ_MAIL_AUTH_CODE',
  'GOOGLE_CLOUD_PROJECT'
]));
