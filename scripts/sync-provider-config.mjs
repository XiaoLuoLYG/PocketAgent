#!/usr/bin/env node
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const envPath = join(rootDir, 'tool-gateway', '.env.local');
const outPath = join(rootDir, 'entry', 'src', 'main', 'resources', 'rawfile', 'aiphone_provider_config.json');

const providerKeys = [
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
  'TAOBAO_API_URL'
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
  'FLIGHT_MCP_KEY',
  'VARIFLIGHT_API_KEY',
  'AMAP_KEY',
  'TENCENT_MAP_KEY',
  'BAIDU_MAP_AK',
  'AMAP_DEFAULT_LOCATION',
  'MEITUAN_UNION_APP_KEY',
  'TAOBAO_APP_KEY',
  'TAOBAO_FLASH_PID'
]));
