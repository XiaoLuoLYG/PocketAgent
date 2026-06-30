import { callBilibiliVideoSearch } from './BilibiliApiClient';
import { DynamicGenericToolResult } from './DynamicToolTypes';
import { callYouTubeVideoSearch } from './YouTubeApiClient';

type MediaArgValue = Object | string | number | boolean | null | undefined;
type MediaArgRecord = Record<string, MediaArgValue>;

function textOf(value: MediaArgValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return '';
}

function stringArrayFrom(value: MediaArgValue): string[] {
  if (Array.isArray(value)) {
    const values: string[] = [];
    value.forEach((item: Object | string | number | boolean | null) => {
      const text = textOf(item).trim().toLowerCase();
      if (text.length > 0 && values.indexOf(text) < 0) {
        values.push(text);
      }
    });
    return values;
  }
  const text = textOf(value).trim().toLowerCase();
  return text.length > 0 ? [text] : [];
}

function hasMediaCue(prompt: string): boolean {
  const lower = prompt.toLowerCase();
  return lower.indexOf('youtube') >= 0 ||
    lower.indexOf('bilibili') >= 0 ||
    lower.indexOf('b站') >= 0 ||
    lower.indexOf('b 站') >= 0 ||
    prompt.indexOf('油管') >= 0 ||
    prompt.indexOf('哔哩哔哩') >= 0 ||
    prompt.indexOf('视频') >= 0 ||
    prompt.indexOf('媒体') >= 0;
}

function textAfterLast(prompt: string, markers: string[]): string {
  let offset = -1;
  let markerLength = 0;
  markers.forEach((marker: string) => {
    const index = prompt.lastIndexOf(marker);
    if (index >= 0 && index + marker.length < prompt.length && index > offset) {
      offset = index;
      markerLength = marker.length;
    }
  });
  return offset >= 0 ? prompt.substring(offset + markerLength).trim() : '';
}

export function mediaVideoSearchQuery(prompt: string): string {
  const text = prompt.trim();
  if (!hasMediaCue(text)) {
    return text;
  }
  const afterSearch = textAfterLast(text, ['搜索', '帮我搜', '查询', '查']);
  return afterSearch.length > 0 ? afterSearch : text;
}

export function mediaVideoQueryFromArgs(prompt: string, args: Object | null): string {
  if (args !== null) {
    const record = args as MediaArgRecord;
    const query = textOf(record.query).trim();
    if (query.length > 0) {
      return query;
    }
  }
  return mediaVideoSearchQuery(prompt);
}

export function mediaSourcesFromArgs(args: Object | null): string[] {
  if (args === null) {
    return ['youtube', 'bilibili'];
  }
  const record = args as MediaArgRecord;
  const rawSources = stringArrayFrom(record.sources);
  if (rawSources.length === 0) {
    return ['youtube', 'bilibili'];
  }
  const kept: string[] = [];
  rawSources.forEach((source: string) => {
    if ((source === 'youtube' || source === 'bilibili') && kept.indexOf(source) < 0) {
      kept.push(source);
    }
  });
  return kept.length > 0 ? kept : ['youtube', 'bilibili'];
}

export function mergeMediaVideoProviderResults(results: DynamicGenericToolResult[]): DynamicGenericToolResult[] {
  return results.map((result: DynamicGenericToolResult) => {
    const normalized: DynamicGenericToolResult = {
      sourceTag: result.sourceTag,
      toolName: 'media.video.search',
      title: result.title,
      status: result.status,
      summary: result.summary,
      rows: result.rows.slice(),
      rawPreview: result.rawPreview
    };
    return normalized;
  });
}

export async function callMediaVideoSearch(
  prompt: string,
  args: Object | null,
  youtubeApiKey: string
): Promise<DynamicGenericToolResult[]> {
  const query = mediaVideoQueryFromArgs(prompt, args);
  const sources = mediaSourcesFromArgs(args);
  const tasks: Promise<DynamicGenericToolResult[]>[] = [];
  if (sources.indexOf('youtube') >= 0) {
    tasks.push(callYouTubeVideoSearch(query, youtubeApiKey));
  }
  if (sources.indexOf('bilibili') >= 0) {
    tasks.push(callBilibiliVideoSearch(query));
  }
  const providerResults = await Promise.all(tasks);
  const merged: DynamicGenericToolResult[] = [];
  providerResults.forEach((results: DynamicGenericToolResult[]) => {
    results.forEach((result: DynamicGenericToolResult) => merged.push(result));
  });
  return mergeMediaVideoProviderResults(merged);
}
