import { http } from '@kit.NetworkKit';
import util from '@ohos.util';
import { A2uiLabelValueData } from './A2uiTypes';
import { DynamicGenericToolResult } from './DynamicToolTypes';

const BILIBILI_SEARCH_URL: string = 'https://search.bilibili.com/video';
const BILIBILI_API_SEARCH_URL: string = 'https://api.bilibili.com/x/web-interface/search/all/v2';
const BILIBILI_SEARCH_MARKER: string = 'http:\\u002F\\u002Fwww.bilibili.com\\u002Fvideo\\u002Fav';

interface BilibiliVideoItem {
  bvid: string;
  title: string;
  cover: string;
}

interface JsonStringValue {
  value: string;
  end: number;
}

interface StringAlias {
  name: string;
  value: string;
}

interface BilibiliSearchResponse {
  code?: number;
  message?: string;
  data?: BilibiliSearchData;
}

interface BilibiliSearchData {
  result?: BilibiliSearchApiEntry[];
}

interface BilibiliSearchApiEntry extends BilibiliSearchApiItem {
  result_type?: string;
  data?: BilibiliSearchApiItem[];
}

interface BilibiliSearchApiItem {
  bvid?: string;
  title?: string;
  pic?: string;
}

interface BilibiliViewResponse {
  code?: number;
  message?: string;
  data?: BilibiliViewData;
}

interface BilibiliViewData {
  bvid?: string;
  aid?: number;
  cid?: number;
}

function textOf(value: Object | string | number | boolean | null | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return JSON.stringify(value);
}

export function bilibiliSearchUrl(query: string): string {
  const params: string[][] = [
    ['keyword', query]
  ];
  return BILIBILI_SEARCH_URL + '?' + params.map((pair: string[]) => encodeURIComponent(pair[0]) + '=' + encodeURIComponent(pair[1])).join('&');
}

export function bilibiliApiSearchUrl(query: string): string {
  const params: string[][] = [
    ['keyword', query]
  ];
  return BILIBILI_API_SEARCH_URL + '?' + params.map((pair: string[]) => encodeURIComponent(pair[0]) + '=' + encodeURIComponent(pair[1])).join('&');
}

function bilibiliViewUrl(bvid: string): string {
  return 'https://api.bilibili.com/x/web-interface/view?bvid=' + encodeURIComponent(bvid.trim());
}

export function bilibiliPlayerUrl(bvid: string): string {
  return 'https://www.bilibili.com/video/' + encodeURIComponent(bvid.trim());
}

function responseText(result: Object | string | number | boolean | ArrayBuffer): string {
  if (typeof result === 'string') {
    return result;
  }
  if (result instanceof ArrayBuffer) {
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(result));
  }
  return textOf(result);
}

function parseJsonStringAt(text: string, quoteIndex: number): JsonStringValue | null {
  if (quoteIndex < 0 || quoteIndex >= text.length || text.charAt(quoteIndex) !== '"') {
    return null;
  }
  let escaped = false;
  for (let index = quoteIndex + 1; index < text.length; index++) {
    const ch = text.charAt(index);
    if (escaped) {
      escaped = false;
    } else if (ch === '\\') {
      escaped = true;
    } else if (ch === '"') {
      return {
        value: JSON.parse(text.substring(quoteIndex, index + 1)) as string,
        end: index
      };
    }
  }
  return null;
}

function nextJsonString(text: string, fromIndex: number): JsonStringValue | null {
  const quoteIndex = text.indexOf('"', fromIndex);
  return parseJsonStringAt(text, quoteIndex);
}

function stripHtmlTags(value: string): string {
  let result = '';
  let inTag = false;
  for (let index = 0; index < value.length; index++) {
    const ch = value.charAt(index);
    if (ch === '<') {
      inTag = true;
    } else if (ch === '>') {
      inTag = false;
    } else if (!inTag) {
      result += ch;
    }
  }
  return result;
}

function normalizeImageUrl(value: string): string {
  const url = value.trim();
  if (url.startsWith('https://') || url.startsWith('http://')) {
    return url;
  }
  if (url.startsWith('//')) {
    return 'https:' + url;
  }
  return '';
}

function splitTopLevelValues(value: string): string[] {
  const parts: string[] = [];
  let current = '';
  let depth = 0;
  let quote = '';
  let escaped = false;
  for (let index = 0; index < value.length; index++) {
    const ch = value.charAt(index);
    current += ch;
    if (quote.length > 0) {
      if (escaped) {
        escaped = false;
      } else if (ch === '\\') {
        escaped = true;
      } else if (ch === quote) {
        quote = '';
      }
      continue;
    }
    if (ch === '"' || ch === "'") {
      quote = ch;
    } else if (ch === '(' || ch === '[' || ch === '{') {
      depth++;
    } else if (ch === ')' || ch === ']' || ch === '}') {
      depth--;
    } else if (ch === ',' && depth === 0) {
      parts.push(current.substring(0, current.length - 1).trim());
      current = '';
    }
  }
  if (current.trim().length > 0) {
    parts.push(current.trim());
  }
  return parts;
}

function parseDoubleQuotedString(value: string): string {
  const trimmed = value.trim();
  if (!trimmed.startsWith('"') || !trimmed.endsWith('"')) {
    return '';
  }
  try {
    return JSON.parse(trimmed) as string;
  } catch (_) {
    return '';
  }
}

function piniaScriptFromHtml(html: string): string {
  const marker = 'window.__pinia=';
  const start = html.indexOf(marker);
  if (start < 0) {
    return '';
  }
  const scriptEnd = html.indexOf('</script>', start);
  if (scriptEnd < 0) {
    return '';
  }
  return html.substring(start + marker.length, scriptEnd).trim();
}

function stringAliasesFromPiniaScript(script: string): StringAlias[] {
  const functionStart = script.indexOf('(function(');
  if (functionStart < 0) {
    return [];
  }
  const paramsStart = functionStart + '(function('.length;
  const paramsEnd = script.indexOf(')', paramsStart);
  const argsStart = script.lastIndexOf('}(');
  if (paramsEnd < 0 || argsStart < 0) {
    return [];
  }
  let argsEnd = script.length;
  while (argsEnd > argsStart && script.charAt(argsEnd - 1) === ')') {
    argsEnd--;
  }
  const names = script.substring(paramsStart, paramsEnd).split(',');
  const values = splitTopLevelValues(script.substring(argsStart + 2, argsEnd));
  const aliases: StringAlias[] = [];
  const count = Math.min(names.length, values.length);
  for (let index = 0; index < count; index++) {
    const parsed = parseDoubleQuotedString(values[index]);
    if (parsed.length > 0 || values[index].trim() === '""') {
      aliases.push({ name: names[index].trim(), value: parsed });
    }
  }
  return aliases;
}

function resolveAliasValue(expression: string, aliases: StringAlias[]): string {
  const trimmed = expression.trim();
  const direct = parseDoubleQuotedString(trimmed);
  if (direct.length > 0 || trimmed === '""') {
    return direct;
  }
  for (let index = 0; index < aliases.length; index++) {
    if (aliases[index].name === trimmed) {
      return aliases[index].value;
    }
  }
  return '';
}

function propertyExpression(text: string, property: string, fromIndex: number): string {
  const marker = property + ':';
  const start = text.indexOf(marker, fromIndex);
  if (start < 0) {
    return '';
  }
  let depth = 0;
  let quote = '';
  let escaped = false;
  const valueStart = start + marker.length;
  for (let index = valueStart; index < text.length; index++) {
    const ch = text.charAt(index);
    if (quote.length > 0) {
      if (escaped) {
        escaped = false;
      } else if (ch === '\\') {
        escaped = true;
      } else if (ch === quote) {
        quote = '';
      }
      continue;
    }
    if (ch === '"' || ch === "'") {
      quote = ch;
    } else if (ch === '(' || ch === '[' || ch === '{') {
      depth++;
    } else if (ch === ')' || ch === ']' || ch === '}') {
      if (depth === 0) {
        return text.substring(valueStart, index).trim();
      }
      depth--;
    } else if (ch === ',' && depth === 0) {
      return text.substring(valueStart, index).trim();
    }
  }
  return text.substring(valueStart).trim();
}

function itemFromPiniaScript(script: string, aliases: StringAlias[], bvidIndex: number): BilibiliVideoItem | null {
  const bvid = resolveAliasValue(propertyExpression(script, 'bvid', bvidIndex), aliases).trim();
  if (!bvid.startsWith('BV')) {
    return null;
  }
  const title = resolveAliasValue(propertyExpression(script, 'title', bvidIndex), aliases);
  const cleanTitle = stripHtmlTags(title).trim();
  if (cleanTitle.length === 0) {
    return null;
  }
  const cover = resolveAliasValue(propertyExpression(script, 'pic', bvidIndex), aliases);
  return {
    bvid: bvid,
    title: cleanTitle,
    cover: normalizeImageUrl(cover)
  };
}

function itemFromSearchHtml(text: string, markerIndex: number): BilibiliVideoItem | null {
  const bvidStart = text.indexOf('","', markerIndex);
  if (bvidStart < 0) {
    return null;
  }
  const bvid = parseJsonStringAt(text, bvidStart + 2);
  if (bvid === null || !bvid.value.startsWith('BV')) {
    return null;
  }
  const title = nextJsonString(text, bvid.end + 1);
  if (title === null) {
    return null;
  }
  const description = nextJsonString(text, title.end + 1);
  if (description === null) {
    return null;
  }
  const cover = nextJsonString(text, description.end + 1);
  return {
    bvid: bvid.value,
    title: stripHtmlTags(title.value).trim(),
    cover: cover === null ? '' : normalizeImageUrl(cover.value)
  };
}

function resultFromItem(item: BilibiliVideoItem, query: string): DynamicGenericToolResult {
  const rows: A2uiLabelValueData[] = [
    { label: 'Source', value: 'Bilibili' },
    { label: 'BVID', value: item.bvid },
    { label: 'Playback URL', value: bilibiliPlayerUrl(item.bvid) }
  ];
  if (item.cover.length > 0) {
    rows.push({ label: 'Thumbnail', value: item.cover });
  }
  return {
    sourceTag: '哔哩哔哩',
    toolName: 'media.video.search',
    title: item.title.length > 0 ? item.title : item.bvid,
    status: 'success',
    summary: 'B 站视频搜索结果：' + query,
    rows: rows,
    rawPreview: 'bvid=' + item.bvid
  };
}

function rowValue(result: DynamicGenericToolResult, label: string): string {
  for (let index = 0; index < result.rows.length; index++) {
    if (result.rows[index].label === label) {
      return result.rows[index].value.trim();
    }
  }
  return '';
}

function appendRowIfMissing(rows: A2uiLabelValueData[], label: string, value: string): void {
  const trimmed = value.trim();
  if (trimmed.length === 0) {
    return;
  }
  for (let index = 0; index < rows.length; index++) {
    if (rows[index].label === label) {
      return;
    }
  }
  rows.push({ label: label, value: trimmed });
}

async function hydrateBilibiliViewRows(results: DynamicGenericToolResult[]): Promise<DynamicGenericToolResult[]> {
  for (let index = 0; index < results.length; index++) {
    const result = results[index];
    if (result.status !== 'success') {
      continue;
    }
    const bvid = rowValue(result, 'BVID');
    if (!bvid.startsWith('BV')) {
      continue;
    }
    const request = http.createHttp();
    try {
      const response = await request.request(bilibiliViewUrl(bvid), {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'application/json, text/plain, */*',
          'Referer': 'https://www.bilibili.com/',
          'User-Agent': 'Mozilla/5.0 AIPhoneDemo/0.1'
        },
        usingProtocol: http.HttpProtocol.HTTP1_1,
        connectTimeout: 8000,
        readTimeout: 10000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        continue;
      }
      const payload = JSON.parse(responseText(response.result)) as BilibiliViewResponse;
      if (payload.code !== undefined && payload.code !== 0 || payload.data === undefined) {
        continue;
      }
      appendRowIfMissing(result.rows, 'AID', textOf(payload.data.aid));
      appendRowIfMissing(result.rows, 'CID', textOf(payload.data.cid));
    } catch (_) {
    } finally {
      request.destroy();
    }
  }
  return results;
}

function bilibiliVideoResultsFromPiniaHtml(html: string, query: string): DynamicGenericToolResult[] {
  const script = piniaScriptFromHtml(html);
  if (script.length === 0) {
    return [];
  }
  const aliases = stringAliasesFromPiniaScript(script);
  const results: DynamicGenericToolResult[] = [];
  const seen: string[] = [];
  let cursor = 0;
  while (results.length < 10) {
    const bvidIndex = script.indexOf('bvid:', cursor);
    if (bvidIndex < 0) {
      break;
    }
    cursor = bvidIndex + 'bvid:'.length;
    const item = itemFromPiniaScript(script, aliases, bvidIndex);
    if (item === null || seen.indexOf(item.bvid) >= 0) {
      continue;
    }
    seen.push(item.bvid);
    results.push(resultFromItem(item, query));
  }
  return results;
}

function bilibiliErrorResult(title: string, summary: string, query: string): DynamicGenericToolResult[] {
  return [{
    sourceTag: '哔哩哔哩',
    toolName: 'media.video.search',
    title: title,
    status: 'error',
    summary: summary,
    rows: [{ label: 'Query', value: query }],
    rawPreview: 'bilibili error'
  }];
}

export function bilibiliVideoResultsFromSearchPayload(rawJson: string, query: string): DynamicGenericToolResult[] {
  const payload = JSON.parse(rawJson) as BilibiliSearchResponse;
  if (payload.code !== undefined && payload.code !== 0) {
    return bilibiliErrorResult('B 站搜索调用失败', textOf(payload.message), query);
  }
  const entries = payload.data === undefined || !Array.isArray(payload.data.result) ? [] : payload.data.result;
  const items: BilibiliSearchApiItem[] = [];
  entries.forEach((entry: BilibiliSearchApiEntry) => {
    if (textOf(entry.bvid).length > 0) {
      items.push(entry);
    } else if (textOf(entry.result_type) === 'video' && Array.isArray(entry.data)) {
      entry.data.forEach((item: BilibiliSearchApiItem) => items.push(item));
    }
  });
  const results: DynamicGenericToolResult[] = [];
  const seen: string[] = [];
  for (let index = 0; index < items.length && results.length < 10; index++) {
    const item = items[index];
    const bvid = textOf(item.bvid).trim();
    const title = stripHtmlTags(textOf(item.title)).trim();
    if (!bvid.startsWith('BV') || title.length === 0 || seen.indexOf(bvid) >= 0) {
      continue;
    }
    seen.push(bvid);
    results.push(resultFromItem({
      bvid: bvid,
      title: title,
      cover: normalizeImageUrl(textOf(item.pic))
    }, query));
  }
  if (results.length > 0) {
    return results;
  }
  return [{
    sourceTag: '哔哩哔哩',
    toolName: 'media.video.search',
    title: '没有找到 B 站视频',
    status: 'success',
    summary: 'B 站搜索接口没有返回可展示视频。',
    rows: [{ label: 'Query', value: query }],
    rawPreview: 'query=' + query
  }];
}

export function bilibiliVideoResultsFromSearchHtml(html: string, query: string): DynamicGenericToolResult[] {
  const piniaResults = bilibiliVideoResultsFromPiniaHtml(html, query);
  if (piniaResults.length > 0) {
    return piniaResults;
  }
  const results: DynamicGenericToolResult[] = [];
  const seen: string[] = [];
  let cursor = 0;
  while (results.length < 10) {
    const markerIndex = html.indexOf(BILIBILI_SEARCH_MARKER, cursor);
    if (markerIndex < 0) {
      break;
    }
    cursor = markerIndex + BILIBILI_SEARCH_MARKER.length;
    const item = itemFromSearchHtml(html, markerIndex);
    if (item === null || seen.indexOf(item.bvid) >= 0) {
      continue;
    }
    seen.push(item.bvid);
    results.push(resultFromItem(item, query));
  }
  if (results.length > 0) {
    return results;
  }
  return [{
    sourceTag: '哔哩哔哩',
    toolName: 'media.video.search',
    title: '没有找到 B 站视频',
    status: 'success',
    summary: 'B 站搜索页没有返回可展示视频。',
    rows: [{ label: 'Query', value: query }],
    rawPreview: 'query=' + query
  }];
}

export async function callBilibiliVideoSearch(query: string): Promise<DynamicGenericToolResult[]> {
  const request = http.createHttp();
  let lastError = '';
  try {
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const response = await request.request(bilibiliApiSearchUrl(query), {
          method: http.RequestMethod.GET,
          header: {
            'Accept': 'application/json, text/plain, */*',
            'Referer': 'https://search.bilibili.com/',
            'Origin': 'https://search.bilibili.com',
            'User-Agent': 'Mozilla/5.0 AIPhoneDemo/0.1'
          },
          usingProtocol: http.HttpProtocol.HTTP1_1,
          connectTimeout: 10000,
          readTimeout: 30000
        });
        const text = responseText(response.result);
        if (response.responseCode < 200 || response.responseCode >= 300) {
          throw new Error('HTTP ' + response.responseCode.toString() + ': ' + text.substring(0, 240));
        }
        return await hydrateBilibiliViewRows(bilibiliVideoResultsFromSearchPayload(text, query));
      } catch (error) {
        lastError = error instanceof Error ? error.message : JSON.stringify(error);
      }
    }
    return bilibiliErrorResult('B 站搜索调用失败', lastError, query);
  } catch (_) {
    return bilibiliErrorResult('B 站搜索调用失败', lastError, query);
  } finally {
    request.destroy();
  }
}
