import {
  DynamicCredentialSpec,
  DynamicMcpTool,
  DynamicToolManifest,
  DynamicToolRegistration,
  DynamicToolStatus,
  DynamicToolTransport,
  DynamicToolTransportType,
  ModelScopeMcpDetail,
  ModelScopeMcpServer,
  ModelScopeMcpServerConfig,
  ModelScopeMcpTool,
  ModelScopeSchemaProperty
} from './DynamicToolTypes';

const BUILT_IN_TOOL_IDS: string[] = [
  'travel.search',
  'flight.search',
  'train.search',
  'food.search'
];

const UNSAFE_TOOL_PATTERNS: string[] = [
  'book',
  'pay',
  'create_order',
  'submit_order',
  'cancel',
  'refund',
  'redeem',
  'grab_ticket',
  'purchase'
];

export function isBuiltInToolId(toolId: string): boolean {
  return BUILT_IN_TOOL_IDS.indexOf(toolId) >= 0;
}

export function isRunnableRemoteTransport(type: string): boolean {
  return type === 'streamable_http' || type === 'sse' || type === 'http_api';
}

export function isUnsafeMcpTool(name: string, description: string): boolean {
  const source = (name + ' ' + description).toLowerCase();
  const underscored = source.replace(/[-\s]+/g, '_');
  const compact = source.replace(/[^a-z0-9]/g, '');
  for (let index = 0; index < UNSAFE_TOOL_PATTERNS.length; index++) {
    const pattern = UNSAFE_TOOL_PATTERNS[index];
    const patternCompact = pattern.replace(/_/g, '');
    if (source.indexOf(pattern) >= 0 ||
      underscored.indexOf(pattern) >= 0 ||
      compact.indexOf(patternCompact) >= 0) {
      return true;
    }
  }
  return false;
}

function textOf(value: string | undefined): string {
  return value === undefined || value === null ? '' : value;
}

function stringRecordFrom(value: Record<string, string> | undefined): Record<string, string> {
  const copy = JSON.parse('{}') as Record<string, string>;
  if (value === undefined || value === null) {
    return copy;
  }
  const keys = Object.keys(value);
  for (let index = 0; index < keys.length; index++) {
    const key = keys[index];
    copy[key] = textOf(value[key]);
  }
  return copy;
}

function isCredentialHeaderKey(key: string): boolean {
  const normalized = key.toLowerCase();
  return normalized === 'authorization' ||
    normalized === 'x-api-key' ||
    normalized.indexOf('token') >= 0 ||
    normalized.indexOf('api-key') >= 0 ||
    normalized.indexOf('apikey') >= 0;
}

function isPlaceholderCredentialValue(value: string): boolean {
  const normalized = value.trim().toLowerCase();
  return normalized.indexOf('your-secret-token') >= 0 ||
    normalized.indexOf('your_secret_token') >= 0 ||
    normalized.indexOf('your-token') >= 0 ||
    normalized.indexOf('your_token') >= 0 ||
    normalized.indexOf('your-api-key') >= 0 ||
    normalized.indexOf('your_api_key') >= 0 ||
    normalized.indexOf('placeholder') >= 0 ||
    normalized.indexOf('replace-me') >= 0 ||
    normalized.indexOf('changeme') >= 0;
}

function headerRecordFrom(value: Record<string, string> | undefined): Record<string, string> {
  const copy = JSON.parse('{}') as Record<string, string>;
  if (value === undefined || value === null) {
    return copy;
  }
  const keys = Object.keys(value);
  for (let index = 0; index < keys.length; index++) {
    const key = keys[index];
    const text = textOf(value[key]);
    if (isCredentialHeaderKey(key) && isPlaceholderCredentialValue(text)) {
      continue;
    }
    copy[key] = text;
  }
  return copy;
}

function cloneTransport(transport: DynamicToolTransport): DynamicToolTransport {
  return {
    type: transport.type,
    url: transport.url,
    command: transport.command,
    args: transport.args.slice(),
    headers: stringRecordFrom(transport.headers),
    env: stringRecordFrom(transport.env),
    method: transport.method,
    credentialPlacement: transport.credentialPlacement,
    credentialParam: transport.credentialParam,
    queryParam: transport.queryParam,
    fixedQuery: transport.fixedQuery,
    forecastQuery: transport.forecastQuery
  };
}

function cloneRegistration(registration: DynamicToolRegistration): DynamicToolRegistration {
  return {
    toolId: registration.toolId,
    manifestId: registration.manifestId,
    displayName: registration.displayName,
    status: registration.status,
    transport: cloneTransport(registration.transport),
    mcpToolName: registration.mcpToolName,
    credentialRef: registration.credentialRef,
    sourceUrl: registration.sourceUrl,
    lastError: registration.lastError
  };
}

function emptyTransport(type: DynamicToolTransportType): DynamicToolTransport {
  return {
    type: type,
    url: '',
    command: '',
    args: [],
    headers: stringRecordFrom(undefined),
    env: stringRecordFrom(undefined)
  };
}

function normalizeSupportedType(type: string | undefined, fallbackType: DynamicToolTransportType): DynamicToolTransportType {
  const normalized = textOf(type).toLowerCase();
  if (normalized === 'streamable_http' || normalized === 'streamable-http') {
    return 'streamable_http';
  }
  if (normalized === 'sse') {
    return 'sse';
  }
  if (normalized === 'stdio') {
    return 'stdio';
  }
  if (normalized === 'http_api' || normalized === 'http-api' || normalized === 'rest' || normalized === 'rest_api') {
    return 'http_api';
  }
  return fallbackType;
}

function normalizeTransport(server: ModelScopeMcpServer, fallbackType: DynamicToolTransportType): DynamicToolTransport {
  const type = server.command !== undefined && server.command.length > 0
    ? 'stdio'
    : normalizeSupportedType(server.type, fallbackType);
  return {
    type: type,
    url: textOf(server.url).trim(),
    command: textOf(server.command),
    args: Array.isArray(server.args) ? server.args : [],
    headers: headerRecordFrom(server.headers),
    env: stringRecordFrom(server.env)
  };
}

function appendTransportsFromConfig(
  target: DynamicToolTransport[],
  configs: ModelScopeMcpServerConfig[] | null | undefined,
  fallbackType: DynamicToolTransportType
): void {
  if (configs === undefined || configs === null) {
    return;
  }
  for (let configIndex = 0; configIndex < configs.length; configIndex++) {
    const servers = configs[configIndex].mcpServers;
    if (servers === undefined || servers === null) {
      continue;
    }
    const names = Object.keys(servers);
    for (let nameIndex = 0; nameIndex < names.length; nameIndex++) {
      const name = names[nameIndex];
      const server = servers[name];
      target.push(normalizeTransport(server, fallbackType));
    }
  }
}

function credentialSchemeFor(name: string): string {
  const upper = name.toUpperCase();
  if (upper.indexOf('TOKEN') >= 0 || upper.indexOf('AUTH') >= 0) {
    return 'bearer';
  }
  if (upper.indexOf('KEY') >= 0) {
    return 'api_key';
  }
  return 'secret';
}

function normalizeCredentials(detail: ModelScopeMcpDetail): DynamicCredentialSpec[] {
  const credentials: DynamicCredentialSpec[] = [];
  const envSchema = detail.EnvSchema;
  if (envSchema === undefined || envSchema === null || envSchema.properties === undefined || envSchema.properties === null) {
    return credentials;
  }

  const required = Array.isArray(envSchema.required) ? envSchema.required : [];
  const names = Object.keys(envSchema.properties);
  for (let index = 0; index < names.length; index++) {
    const name = names[index];
    const property: ModelScopeSchemaProperty = envSchema.properties[name];
    credentials.push({
      name: name,
      description: textOf(property.description),
      required: required.indexOf(name) >= 0,
      placement: 'env',
      scheme: credentialSchemeFor(name),
      testValue: textOf(property.test_value)
    });
  }
  return credentials;
}

function normalizeTools(detail: ModelScopeMcpDetail): DynamicMcpTool[] {
  const tools: DynamicMcpTool[] = [];
  if (detail.Tools === undefined || detail.Tools === null) {
    return tools;
  }
  for (let index = 0; index < detail.Tools.length; index++) {
    const source: ModelScopeMcpTool = detail.Tools[index];
    const name = textOf(source.name);
    if (name.length === 0) {
      continue;
    }
    tools.push({
      name: name,
      description: textOf(source.description),
      inputSchema: source.inputSchema === undefined || source.inputSchema === null ? new Object() : source.inputSchema
    });
  }
  return tools;
}

function normalizeCapabilities(detail: ModelScopeMcpDetail): string[] {
  const capabilities: string[] = [];
  if (detail.Category !== undefined && detail.Category !== null) {
    for (let index = 0; index < detail.Category.length; index++) {
      capabilities.push(detail.Category[index]);
    }
  }
  if (detail.SupportedDeployTransportType !== undefined && detail.SupportedDeployTransportType !== null) {
    for (let index = 0; index < detail.SupportedDeployTransportType.length; index++) {
      capabilities.push('transport:' + detail.SupportedDeployTransportType[index]);
    }
  }
  return capabilities;
}

function manifestIdFor(detail: ModelScopeMcpDetail): string {
  const path = textOf(detail.Path).replace(/\//g, '.');
  const name = textOf(detail.Name).replace(/\//g, '.');
  const suffix = path.length > 0 && name.length > 0
    ? path + '.' + name
    : (name.length > 0 ? name : path);
  return 'modelscope.' + suffix;
}

export function normalizeModelScopeMcpDetail(detail: ModelScopeMcpDetail, sourceUrl: string): DynamicToolManifest {
  const transports: DynamicToolTransport[] = [];
  appendTransportsFromConfig(transports, detail.ServerConfig, 'stdio');
  appendTransportsFromConfig(transports, detail.SSEServerConfig, 'sse');
  appendTransportsFromConfig(transports, detail.StreamableHTTPServerConfig, 'streamable_http');

  return {
    id: manifestIdFor(detail),
    displayName: textOf(detail.ChineseName).length > 0 ? textOf(detail.ChineseName) : textOf(detail.Name),
    sourceUrl: sourceUrl,
    hosted: detail.Hosted === true,
    fromSiteUrl: textOf(detail.FromSiteUrl),
    capabilities: normalizeCapabilities(detail),
    requiredCredentials: normalizeCredentials(detail),
    transports: transports,
    tools: normalizeTools(detail)
  };
}

function hasRemoteEndpoint(transport: DynamicToolTransport): boolean {
  return transport.url.trim().length > 0;
}

export function selectBestRemoteTransport(manifest: DynamicToolManifest): DynamicToolTransport | null {
  for (let index = 0; index < manifest.transports.length; index++) {
    const transport = manifest.transports[index];
    if (transport.type === 'streamable_http' && hasRemoteEndpoint(transport)) {
      return transport;
    }
  }
  for (let index = 0; index < manifest.transports.length; index++) {
    const transport = manifest.transports[index];
    if (transport.type === 'sse' && hasRemoteEndpoint(transport)) {
      return transport;
    }
  }
  for (let index = 0; index < manifest.transports.length; index++) {
    const transport = manifest.transports[index];
    if (transport.type === 'http_api' && hasRemoteEndpoint(transport)) {
      return transport;
    }
  }
  return null;
}

function toolDescriptionFor(manifest: DynamicToolManifest, mcpToolName: string): string {
  for (let index = 0; index < manifest.tools.length; index++) {
    const tool = manifest.tools[index];
    if (tool.name === mcpToolName) {
      return tool.description;
    }
  }
  return '';
}

function hasMissingRequiredCredential(manifest: DynamicToolManifest, credentialRef: string): boolean {
  if (credentialRef.length > 0) {
    return false;
  }
  for (let index = 0; index < manifest.requiredCredentials.length; index++) {
    if (manifest.requiredCredentials[index].required) {
      return true;
    }
  }
  return false;
}

function statusForRegistration(manifest: DynamicToolManifest, mcpToolName: string, credentialRef: string, transport: DynamicToolTransport | null): DynamicToolStatus {
  if (isUnsafeMcpTool(mcpToolName, toolDescriptionFor(manifest, mcpToolName))) {
    return 'unsafe_action_blocked';
  }
  if (transport === null) {
    return 'unsupported_transport';
  }
  if (hasMissingRequiredCredential(manifest, credentialRef)) {
    return 'needs_auth';
  }
  return 'candidate';
}

export class DynamicToolRegistry {
  private registrations: DynamicToolRegistration[] = [];

  enableAlias(toolId: string, manifest: DynamicToolManifest, mcpToolName: string, credentialRef: string): DynamicToolRegistration {
    const transport = selectBestRemoteTransport(manifest);
    const fallbackTransport = manifest.transports.length > 0 ? manifest.transports[0] : emptyTransport('unsupported');
    const status = statusForRegistration(manifest, mcpToolName, credentialRef, transport);
    const registration: DynamicToolRegistration = {
      toolId: toolId,
      manifestId: manifest.id,
      displayName: manifest.displayName,
      status: status,
      transport: transport === null ? fallbackTransport : transport,
      mcpToolName: mcpToolName,
      credentialRef: credentialRef,
      sourceUrl: manifest.sourceUrl,
      lastError: status === 'unsupported_transport' ? 'No HAP-runnable remote transport is available.' : ''
    };

    this.removeAlias(toolId);
    this.registrations.push(cloneRegistration(registration));
    return cloneRegistration(registration);
  }

  setRegistration(registration: DynamicToolRegistration): void {
    this.removeAlias(registration.toolId);
    this.registrations.push(cloneRegistration(registration));
  }

  canHandleToolId(toolId: string): boolean {
    const registration = this.registrationForToolId(toolId);
    return registration !== null && registration.status === 'enabled';
  }

  registrationForToolId(toolId: string): DynamicToolRegistration | null {
    for (let index = 0; index < this.registrations.length; index++) {
      const registration = this.registrations[index];
      if (registration.toolId === toolId) {
        return cloneRegistration(registration);
      }
    }
    return null;
  }

  removeAlias(toolId: string): void {
    const next: DynamicToolRegistration[] = [];
    for (let index = 0; index < this.registrations.length; index++) {
      const registration = this.registrations[index];
      if (registration.toolId !== toolId) {
        next.push(registration);
      }
    }
    this.registrations = next;
  }

  allRegistrations(): DynamicToolRegistration[] {
    const copy: DynamicToolRegistration[] = [];
    for (let index = 0; index < this.registrations.length; index++) {
      copy.push(cloneRegistration(this.registrations[index]));
    }
    return copy;
  }
}
