import { A2uiSurfaceState } from '../../model/A2uiTypes';
import { toolRequest } from '../../model/A2uiData';

export interface A2uiHomeResolvedToolRequest {
  hasTool: boolean;
  toolId: string;
  prompt: string;
  actionId: string;
  modelPromptChars: number;
}

export function resolveA2uiHomeToolRequest(
  surface: A2uiSurfaceState,
  fallbackPrompt: string,
  fallbackActionId: string
): A2uiHomeResolvedToolRequest {
  const request = toolRequest(surface);
  const toolId = request.toolId;
  const prompt = request.prompt.length > 0 ? request.prompt : fallbackPrompt;
  const actionId = request.actionId.length > 0 ? request.actionId : fallbackActionId;
  return {
    hasTool: toolId.length > 0,
    toolId: toolId,
    prompt: prompt,
    actionId: actionId,
    modelPromptChars: request.prompt.length
  };
}
