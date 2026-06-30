export type ToolRiskLevel = 'read' | 'draft' | 'confirm_required' | 'blocked';
export type ToolBackendType = 'local_adapter' | 'oauth_api' | 'imap' | 'workspace_mcp' | 'web_session' | 'system_intent' | 'mcp_remote';
export type ToolAuthMode = 'none' | 'provider_key' | 'oauth' | 'imap_auth' | 'web_session' | 'mcp_auth' | 'system';

export interface ToolDefinition {
  toolId: string;
  domain: string;
  intent: string;
  riskLevel: ToolRiskLevel;
  backendPriority: ToolBackendType[];
  authModes: ToolAuthMode[];
  inputSchema: string;
  outputSchema: string;
  a2uiComponent: string;
  actions: string[];
}

export interface BackendAvailability {
  backend: ToolBackendType;
  available: boolean;
  reason: string;
  accountHint: string;
}

export interface BackendResolution {
  ok: boolean;
  toolId: string;
  backend: ToolBackendType;
  reason: string;
  accountHint: string;
}

export function cloneToolDefinition(definition: ToolDefinition): ToolDefinition {
  return {
    toolId: definition.toolId,
    domain: definition.domain,
    intent: definition.intent,
    riskLevel: definition.riskLevel,
    backendPriority: definition.backendPriority.slice(),
    authModes: definition.authModes.slice(),
    inputSchema: definition.inputSchema,
    outputSchema: definition.outputSchema,
    a2uiComponent: definition.a2uiComponent,
    actions: definition.actions.slice()
  };
}
