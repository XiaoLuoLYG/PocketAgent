import { A2uiLabelValueData } from './A2uiTypes';

export type DynamicToolTransportType = 'streamable_http' | 'sse' | 'stdio' | 'http_api' | 'unsupported';
export type DynamicToolStatus = 'candidate' | 'enabled' | 'needs_auth' | 'preflight_failed' | 'unsupported_transport' | 'unsafe_action_blocked';

export interface DynamicCredentialSpec {
  name: string;
  description: string;
  required: boolean;
  placement: string;
  scheme: string;
  testValue: string;
}

export interface DynamicToolTransport {
  type: DynamicToolTransportType;
  url: string;
  command: string;
  args: string[];
  headers: Record<string, string>;
  env: Record<string, string>;
  method?: string;
  credentialPlacement?: string;
  credentialParam?: string;
  queryParam?: string;
  fixedQuery?: string;
  forecastQuery?: string;
}

export interface DynamicMcpTool {
  name: string;
  description: string;
  inputSchema: Object;
}

export interface DynamicToolManifest {
  id: string;
  displayName: string;
  sourceUrl: string;
  hosted: boolean;
  fromSiteUrl: string;
  capabilities: string[];
  requiredCredentials: DynamicCredentialSpec[];
  transports: DynamicToolTransport[];
  tools: DynamicMcpTool[];
}

export interface DynamicToolRegistration {
  toolId: string;
  manifestId: string;
  displayName: string;
  status: DynamicToolStatus;
  transport: DynamicToolTransport;
  mcpToolName: string;
  credentialRef: string;
  sourceUrl: string;
  lastError: string;
}

export interface DynamicPreflightResult {
  ok: boolean;
  status: DynamicToolStatus;
  httpStatus: number;
  message: string;
  inferredCredential: DynamicCredentialSpec | null;
  tools: DynamicMcpTool[];
}

export interface DynamicGenericToolResult {
  sourceTag: string;
  toolName: string;
  title: string;
  status: string;
  summary: string;
  rows: A2uiLabelValueData[];
  rawPreview: string;
}

export interface ModelScopeSchemaProperty {
  type?: string;
  description?: string;
  placeholder?: string;
  test_value?: string;
}

export interface ModelScopeEnvSchema {
  type?: string;
  required?: string[];
  properties?: Record<string, ModelScopeSchemaProperty>;
}

export interface ModelScopeMcpTool {
  name?: string;
  description?: string;
  inputSchema?: Object;
}

export interface ModelScopeMcpServer {
  type?: string;
  url?: string;
  command?: string;
  args?: string[];
  env?: Record<string, string>;
  headers?: Record<string, string>;
}

export interface ModelScopeMcpServerConfig {
  mcpServers?: Record<string, ModelScopeMcpServer>;
}

export interface ModelScopeMcpDetail {
  ChineseName?: string;
  Name?: string;
  Path?: string;
  Hosted?: boolean;
  FromSiteUrl?: string;
  Category?: string[];
  EnvSchema?: ModelScopeEnvSchema;
  ServerConfig?: ModelScopeMcpServerConfig[] | null;
  SSEServerConfig?: ModelScopeMcpServerConfig[] | null;
  StreamableHTTPServerConfig?: ModelScopeMcpServerConfig[] | null;
  SupportedDeployTransportType?: string[];
  Tools?: ModelScopeMcpTool[];
}
