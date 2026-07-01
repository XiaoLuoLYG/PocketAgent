import { A2uiSurfaceState } from '../../../model/A2uiTypes';
import { toolRequest } from '../../../model/A2uiData';

type ToolRequestArgValue = Object | string | number | boolean | null | undefined;
type ToolRequestArgRecord = Record<string, ToolRequestArgValue>;
type DataModelRecord = Record<string, Object | string | number | boolean | null | undefined>;

interface DraftFormData {
  to?: string[];
  subject?: string;
  body?: string;
  threadId?: string;
  replyMode?: string;
}

interface MediaFallbackArgs {
  sources: string[];
}

interface YouTubeFallbackArgs {
  query: string;
}

export interface A2uiHomeResolvedToolRequest {
  hasTool: boolean;
  toolId: string;
  prompt: string;
  actionId: string;
  args: Object | null;
  modelPromptChars: number;
}

function containsAny(text: string, words: string[]): boolean {
  for (let index = 0; index < words.length; index++) {
    if (text.indexOf(words[index]) >= 0) {
      return true;
    }
  }
  return false;
}

function hasExplicitMapsIntent(prompt: string): boolean {
  const lowerPrompt = prompt.toLowerCase();
  return prompt.indexOf('谷歌地图') >= 0 ||
    lowerPrompt.indexOf('google maps') >= 0 ||
    lowerPrompt.indexOf('google map') >= 0 ||
    lowerPrompt.indexOf('googlemap') >= 0 ||
    lowerPrompt.indexOf('google places') >= 0 ||
    lowerPrompt.indexOf('gmap') >= 0;
}

function hasExplicitYouTubeIntent(prompt: string): boolean {
  return prompt.toLowerCase().indexOf('youtube') >= 0 || prompt.indexOf('油管') >= 0;
}

function hasBilibiliIntent(prompt: string): boolean {
  const lowerPrompt = prompt.toLowerCase();
  return lowerPrompt.indexOf('bilibili') >= 0 ||
    lowerPrompt.indexOf('b站') >= 0 ||
    lowerPrompt.indexOf('b 站') >= 0 ||
    prompt.indexOf('哔哩哔哩') >= 0;
}

function hasMediaSearchVerb(prompt: string): boolean {
  return containsAny(prompt, ['查', '查询', '搜索', '帮我搜']);
}

function hasMediaAggregationIntent(prompt: string): boolean {
  return containsAny(prompt, ['聚合搜索', '聚合视频', '媒体聚合', '多源视频', '多平台视频']) ||
    (prompt.indexOf('聚合') >= 0 && containsAny(prompt, ['视频', '短视频', '媒体']));
}

function mediaArgsForPrompt(prompt: string): Object | null {
  const bilibiliIntent = hasBilibiliIntent(prompt);
  const youtubeIntent = hasExplicitYouTubeIntent(prompt);
  const aggregationIntent = hasMediaAggregationIntent(prompt);
  const genericVideoSearch = hasMediaSearchVerb(prompt) && containsAny(prompt, ['视频', '短视频']);
  if (bilibiliIntent && !youtubeIntent && !aggregationIntent) {
    const args: MediaFallbackArgs = { sources: ['bilibili'] };
    return args;
  }
  if (youtubeIntent && !bilibiliIntent && !aggregationIntent) {
    return null;
  }
  if (aggregationIntent || genericVideoSearch || bilibiliIntent) {
    const args: MediaFallbackArgs = { sources: ['youtube', 'bilibili'] };
    return args;
  }
  return null;
}

function forcedDynamicToolIdForPrompt(prompt: string): string {
  if (prompt.length === 0) {
    return '';
  }
  if (containsAny(prompt, ['船票', '轮渡', '客船', '渡轮', '码头']) &&
    containsAny(prompt, ['查', '查询', '搜索', '帮我搜', '票', '余票', '班次'])) {
    return 'dynamic.search';
  }
  if (containsAny(prompt, ['天气', '气温', '下雨', '降雨']) &&
    containsAny(prompt, ['查', '查询', '搜索', '帮我搜', '今天', '明天'])) {
    return 'dynamic.search';
  }
  if (containsAny(prompt, ['统计局', 'GDP', 'CPI', '人口', '经济数据']) &&
    containsAny(prompt, ['查', '查询', '搜索', '帮我搜'])) {
    return 'dynamic.search';
  }
  if (containsAny(prompt, ['PPT', 'ppt', '幻灯片', '演示文稿']) &&
    containsAny(prompt, ['生成', '做', '制作', '创建'])) {
    return 'dynamic.search';
  }
  return '';
}

function forcedGmailToolIdForPrompt(prompt: string): string {
  if (!containsAny(prompt, ['Gmail', '谷歌邮箱', '谷歌邮件'])) {
    return '';
  }
  if (containsAny(prompt, ['直接发送', '立刻发送', '马上发送', '不用确认', '不确认直接发', '直接发'])) {
    return 'gmail.message.send';
  }
  if (containsAny(prompt, ['打开', '网页版', '网页'])) {
    return 'gmail.open.web';
  }
  return '';
}

function inferredGmailToolIdForPrompt(prompt: string): string {
  const forcedToolId = forcedGmailToolIdForPrompt(prompt);
  if (forcedToolId.length > 0) {
    return forcedToolId;
  }
  if (!containsAny(prompt, ['Gmail', '谷歌邮箱', '谷歌邮件'])) {
    return '';
  }
  if (containsAny(prompt, ['写一封', '写邮件', '起草', '草稿', '回复', '撰写'])) {
    return 'gmail.draft.create';
  }
  if (containsAny(prompt, ['看', '查看', '查', '查询', '搜索', '最新', '重要', '邮件'])) {
    return 'gmail.mail.search';
  }
  return '';
}

function inferredMailToolIdForPrompt(prompt: string): string {
  const hasGmail = containsAny(prompt, ['Gmail', '谷歌邮箱', '谷歌邮件']);
  const hasQqMail = containsAny(prompt, ['QQ邮箱', 'QQ 邮箱', 'QQ邮件', 'QQ 邮件']);
  if ((hasGmail && !hasQqMail) ||
    !containsAny(prompt, ['邮箱', '邮件', '收件箱', 'QQ邮箱', 'QQ 邮箱'])) {
    return '';
  }
  if (containsAny(prompt, ['直接发送', '立刻发送', '马上发送', '不用确认', '不确认直接发', '直接发'])) {
    return '';
  }
  if (containsAny(prompt, ['写一封', '写邮件', '起草', '草稿', '回复', '撰写'])) {
    return 'mail.draft.create';
  }
  if (containsAny(prompt, ['看', '查看', '查', '查询', '搜索', '最新', '重要', '邮件', '收件箱'])) {
    return 'mail.search';
  }
  return '';
}

function inferredCalendarToolIdForPrompt(prompt: string): string {
  if (!containsAny(prompt, ['Google Calendar', '谷歌日历', '日程'])) {
    return '';
  }
  if (containsAny(prompt, ['创建', '新建', '添加', '新增', '安排'])) {
    return 'calendar.event.create';
  }
  if (containsAny(prompt, ['修改', '改到', '更新', '调整'])) {
    return 'calendar.event.update';
  }
  return 'calendar.events.search';
}

function inferredMapsToolIdForPrompt(prompt: string): string {
  if (!hasExplicitMapsIntent(prompt)) {
    return '';
  }
  if (containsAny(prompt, ['详情', '详细', 'placeId', 'Place ID'])) {
    return 'maps.place.details';
  }
  return 'maps.place.search';
}

function inferredMediaToolIdForPrompt(prompt: string): string {
  return mediaArgsForPrompt(prompt) === null ? '' : 'media.video.search';
}

function hasSocialHubContext(prompt: string): boolean {
  const lowerPrompt = prompt.toLowerCase();
  return containsAny(prompt, ['Slack', '企业微信', '社交', '消息聚合', '多平台消息', '社交消息']) ||
    lowerPrompt.indexOf('slack') >= 0;
}

function hasSocialDraftIntent(prompt: string): boolean {
  const lowerPrompt = prompt.toLowerCase();
  return containsAny(prompt, ['草稿', '回复', '起草']) ||
    lowerPrompt.indexOf('draft') >= 0 ||
    lowerPrompt.indexOf('reply') >= 0;
}

function isAsciiAlphaNumeric(char: string): boolean {
  return (char >= 'A' && char <= 'Z') ||
    (char >= 'a' && char <= 'z') ||
    (char >= '0' && char <= '9') ||
    char === '_';
}

function hasStandaloneXMarker(prompt: string): boolean {
  for (let index = 0; index < prompt.length; index++) {
    const char = prompt.charAt(index);
    if (char !== 'X' && char !== 'x') {
      continue;
    }
    const previous = index === 0 ? '' : prompt.charAt(index - 1);
    const next = index + 1 >= prompt.length ? '' : prompt.charAt(index + 1);
    if ((previous.length === 0 || !isAsciiAlphaNumeric(previous)) &&
      (next.length === 0 || !isAsciiAlphaNumeric(next))) {
      return true;
    }
  }
  return false;
}

function hasXPostContext(prompt: string): boolean {
  const lowerPrompt = prompt.toLowerCase();
  return containsAny(prompt, ['Twitter', '推文', '公开 post']) ||
    hasStandaloneXMarker(prompt) ||
    lowerPrompt.indexOf('twitter') >= 0 ||
    lowerPrompt.indexOf('x.com') >= 0 ||
    lowerPrompt.indexOf('public post') >= 0;
}

function hasSocialReadIntent(prompt: string): boolean {
  const lowerPrompt = prompt.toLowerCase();
  return containsAny(prompt, ['读', '看', '查看', '查', '查询', '搜索', '搜', '最近', '公开']) ||
    lowerPrompt.indexOf('read') >= 0 ||
    lowerPrompt.indexOf('search') >= 0;
}

function allowsXPostSearchPrompt(prompt: string): boolean {
  return hasXPostContext(prompt) && hasSocialReadIntent(prompt);
}

function inferredSocialHubToolIdForPrompt(prompt: string): string {
  const socialContext = hasSocialHubContext(prompt);
  if (socialContext && hasSocialDraftIntent(prompt)) {
    return 'social.reply.draft';
  }
  if (allowsXPostSearchPrompt(prompt) &&
    (!socialContext || containsAny(prompt, ['公开 post']) || prompt.toLowerCase().indexOf('x.com') >= 0 || prompt.toLowerCase().indexOf('public post') >= 0)) {
    return 'x.post.search';
  }
  if (socialContext) {
    return 'social.feed.search';
  }
  return '';
}

function youtubeArgsForPrompt(prompt: string): Object | null {
  if (hasExplicitYouTubeIntent(prompt) &&
    !hasBilibiliIntent(prompt) &&
    !hasMediaAggregationIntent(prompt) &&
    (hasMediaSearchVerb(prompt) || containsAny(prompt, ['视频']))) {
    const args: YouTubeFallbackArgs = { query: prompt.trim() };
    return args;
  }
  return null;
}

function inferredYouTubeToolIdForPrompt(prompt: string): string {
  return youtubeArgsForPrompt(prompt) === null ? '' : 'youtube.video.search';
}

function inferredToolIdForPrompt(prompt: string): string {
  const dynamicToolId = forcedDynamicToolIdForPrompt(prompt);
  if (dynamicToolId.length > 0) {
    return dynamicToolId;
  }
  const mailToolId = inferredMailToolIdForPrompt(prompt);
  if (mailToolId.length > 0) {
    return mailToolId;
  }
  const gmailToolId = inferredGmailToolIdForPrompt(prompt);
  if (gmailToolId.length > 0) {
    return gmailToolId;
  }
  const calendarToolId = inferredCalendarToolIdForPrompt(prompt);
  if (calendarToolId.length > 0) {
    return calendarToolId;
  }
  const mapsToolId = inferredMapsToolIdForPrompt(prompt);
  if (mapsToolId.length > 0) {
    return mapsToolId;
  }
  const youtubeToolId = inferredYouTubeToolIdForPrompt(prompt);
  if (youtubeToolId.length > 0) {
    return youtubeToolId;
  }
  const mediaToolId = inferredMediaToolIdForPrompt(prompt);
  if (mediaToolId.length > 0) {
    return mediaToolId;
  }
  const socialHubToolId = inferredSocialHubToolIdForPrompt(prompt);
  if (socialHubToolId.length > 0) {
    return socialHubToolId;
  }
  if (containsAny(prompt, ['附近', '周边', '外卖', '咖啡', '奶茶', '餐饮', '美食', '肯德基']) &&
    containsAny(prompt, ['查', '查询', '搜索', '帮我搜', '附近', '周边'])) {
    return 'food.search';
  }
  if (containsAny(prompt, ['出行方案', '搜索出行', '怎么去', '比较出行', '出行选项', '可查的出行'])) {
    return 'travel.search';
  }
  if (containsAny(prompt, ['航班', '机票', '飞机'])) {
    return 'flight.search';
  }
  if (containsAny(prompt, ['高铁', '火车', '车票', '12306'])) {
    return 'train.search';
  }
  return '';
}

function toolIdForActionId(actionId: string): string {
  if (actionId === 'gmail.ai.reply.draft') {
    return 'gmail.draft.create';
  }
  return '';
}

function mergeArgs(base: Object | null, override: Object | null): Object | null {
  if (base === null) {
    return override;
  }
  if (override === null) {
    return base;
  }
  const merged: ToolRequestArgRecord = {};
  const baseRecord = base as ToolRequestArgRecord;
  Object.keys(baseRecord).forEach((key: string) => {
    merged[key] = baseRecord[key];
  });
  const overrideRecord = override as ToolRequestArgRecord;
  Object.keys(overrideRecord).forEach((key: string) => {
    merged[key] = overrideRecord[key];
  });
  return merged;
}

function argText(args: Object | null, key: string): string {
  if (args === null) {
    return '';
  }
  const value = (args as ToolRequestArgRecord)[key];
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

function textOf(value: ToolRequestArgValue): string {
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

function stringArrayFrom(value: ToolRequestArgValue): string[] {
  if (value === undefined || value === null) {
    return [];
  }
  if (Array.isArray(value)) {
    const values: string[] = [];
    value.forEach((item: Object | string | number | boolean | null) => {
      const text = textOf(item);
      if (text.length > 0) {
        values.push(text);
      }
    });
    return values;
  }
  const text = textOf(value);
  return text.length > 0 ? [text] : [];
}

function draftFormArgs(surface: A2uiSurfaceState): Object | null {
  try {
    const model = JSON.parse(surface.dataModelJson) as DataModelRecord;
    const formValue = model.form;
    if (formValue === undefined || formValue === null ||
      typeof formValue === 'string' || typeof formValue === 'number' || typeof formValue === 'boolean') {
      return null;
    }
    const form = formValue as DraftFormData;
    const args: ToolRequestArgRecord = {};
    const to = stringArrayFrom(form.to);
    if (to.length > 0) {
      args.to = to;
    }
    const subject = textOf(form.subject);
    if (subject.length > 0) {
      args.subject = subject;
    }
    const body = textOf(form.body);
    if (body.length > 0) {
      args.body = body;
    }
    const threadId = textOf(form.threadId);
    if (threadId.length > 0) {
      args.threadId = threadId;
    }
    const replyMode = textOf(form.replyMode);
    if (replyMode.length > 0) {
      args.replyMode = replyMode;
    }
    return Object.keys(args).length > 0 ? args : null;
  } catch (_error) {
    return null;
  }
}

export function resolveA2uiHomeToolRequest(
  surface: A2uiSurfaceState,
  fallbackPrompt: string,
  fallbackActionId: string,
  fallbackArgs: Object | null = null
): A2uiHomeResolvedToolRequest {
  const request = toolRequest(surface);
  let toolId = request.toolId;
  const prompt = request.prompt.length > 0 ? request.prompt : fallbackPrompt;
  let actionId = request.actionId.length > 0 ? request.actionId : fallbackActionId;
  const forcedDynamicToolId = forcedDynamicToolIdForPrompt(prompt);
  const forcedGmailToolId = forcedGmailToolIdForPrompt(fallbackPrompt.length > 0 ? fallbackPrompt : prompt);
  const forcedMapsToolId = inferredMapsToolIdForPrompt(prompt);
  const forcedMediaToolId = inferredMediaToolIdForPrompt(prompt);
  const actionToolId = toolIdForActionId(fallbackActionId);
  const originalPrompt = fallbackPrompt.length > 0 ? fallbackPrompt : prompt;
  if (forcedDynamicToolId.length > 0) {
    toolId = forcedDynamicToolId;
    if (actionId.length === 0) {
      actionId = request.toolId.length > 0 ? 'client_dynamic_reroute' : 'client_intent_fallback';
    }
  } else if (forcedGmailToolId.length > 0) {
    if (request.toolId.length > 0 && request.toolId !== forcedGmailToolId) {
      actionId = 'client_gmail_safety_reroute';
    } else if (actionId.length === 0) {
      actionId = 'client_intent_fallback';
    }
    toolId = forcedGmailToolId;
  } else if (actionToolId.length > 0) {
    if (actionId.length === 0) {
      actionId = 'client_action_fallback';
    }
    toolId = actionToolId;
  } else if (forcedMapsToolId.length > 0 && toolId !== forcedMapsToolId) {
    actionId = request.toolId.length > 0 ? 'client_maps_explicit_reroute' : 'client_intent_fallback';
    toolId = forcedMapsToolId;
  } else if (forcedMediaToolId.length > 0 && toolId !== forcedMediaToolId) {
    actionId = request.toolId.length > 0 ? 'client_media_explicit_reroute' : 'client_intent_fallback';
    toolId = forcedMediaToolId;
  } else if (request.toolId === 'x.post.search' && !allowsXPostSearchPrompt(originalPrompt)) {
    toolId = inferredToolIdForPrompt(originalPrompt);
    actionId = toolId.length > 0 ? 'client_x_post_safety_reroute' : '';
  } else if ((toolId === 'maps.place.search' || toolId === 'maps.place.details') && !hasExplicitMapsIntent(prompt)) {
    toolId = inferredToolIdForPrompt(prompt);
    actionId = 'client_maps_safety_reroute';
  } else if (toolId.length === 0) {
    toolId = inferredToolIdForPrompt(fallbackPrompt);
    if (toolId.length > 0 && actionId.length === 0) {
      actionId = 'client_intent_fallback';
    }
  }
  let args = mergeArgs(fallbackArgs, request.args === undefined || request.args === null ? null : request.args);
  if (toolId === 'media.video.search') {
    args = mergeArgs(mediaArgsForPrompt(prompt), args);
  }
  if (toolId === 'youtube.video.search') {
    args = mergeArgs(youtubeArgsForPrompt(prompt), args);
  }
  if (toolId === 'gmail.draft.create') {
    args = mergeArgs(draftFormArgs(surface), args);
  }
  if (fallbackActionId === 'gmail.ai.reply.draft' && toolId === 'gmail.draft.create' && argText(args, 'body').trim().length === 0) {
    toolId = '';
  }
  return {
    hasTool: toolId.length > 0,
    toolId: toolId,
    prompt: prompt,
    actionId: actionId,
    args: args,
    modelPromptChars: request.prompt.length
  };
}
