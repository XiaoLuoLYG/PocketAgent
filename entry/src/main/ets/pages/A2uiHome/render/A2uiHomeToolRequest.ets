import { A2uiSurfaceState } from '../../../model/A2uiTypes';
import { toolRequest } from '../../../model/A2uiData';

export interface A2uiHomeResolvedToolRequest {
  hasTool: boolean;
  toolId: string;
  prompt: string;
  actionId: string;
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

function inferredToolIdForPrompt(prompt: string): string {
  if (prompt.length === 0) {
    return '';
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

export function resolveA2uiHomeToolRequest(
  surface: A2uiSurfaceState,
  fallbackPrompt: string,
  fallbackActionId: string
): A2uiHomeResolvedToolRequest {
  const request = toolRequest(surface);
  let toolId = request.toolId;
  const prompt = request.prompt.length > 0 ? request.prompt : fallbackPrompt;
  let actionId = request.actionId.length > 0 ? request.actionId : fallbackActionId;
  if (toolId.length === 0) {
    toolId = inferredToolIdForPrompt(fallbackPrompt);
    if (toolId.length > 0 && actionId.length === 0) {
      actionId = 'client_intent_fallback';
    }
  }
  return {
    hasTool: toolId.length > 0,
    toolId: toolId,
    prompt: prompt,
    actionId: actionId,
    modelPromptChars: request.prompt.length
  };
}
