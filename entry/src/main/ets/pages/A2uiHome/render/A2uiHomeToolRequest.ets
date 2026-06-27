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

function inferredToolIdForPrompt(prompt: string): string {
  const dynamicToolId = forcedDynamicToolIdForPrompt(prompt);
  if (dynamicToolId.length > 0) {
    return dynamicToolId;
  }
  const gmailToolId = inferredGmailToolIdForPrompt(prompt);
  if (gmailToolId.length > 0) {
    return gmailToolId;
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
  const actionToolId = toolIdForActionId(fallbackActionId);
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
  } else if (toolId.length === 0) {
    toolId = inferredToolIdForPrompt(fallbackPrompt);
    if (toolId.length > 0 && actionId.length === 0) {
      actionId = 'client_intent_fallback';
    }
  }
  let args = mergeArgs(fallbackArgs, request.args === undefined || request.args === null ? null : request.args);
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
