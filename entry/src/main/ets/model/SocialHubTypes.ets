export type SocialHubPlatform = 'x' | 'slack' | 'wecom' | 'unknown';
export type SocialHubItemKind = 'message' | 'mention' | 'post' | 'connection';
export type SocialHubConnectionStatus = 'connected' | 'needs_auth' | 'limited' | 'error' | 'disabled';
export type SocialHubDraftStatus = 'empty' | 'draft' | 'error';

export interface SocialHubItemData {
  id: string;
  platform: SocialHubPlatform;
  kind: SocialHubItemKind;
  author: string;
  handle: string;
  text: string;
  timestamp: string;
  url: string;
  channel: string;
  threadId: string;
  unread: boolean;
}

export interface SocialHubDraftData {
  itemId: string;
  platform: SocialHubPlatform;
  text: string;
  status: SocialHubDraftStatus;
  error: string;
  localOnly: boolean;
  sent: boolean;
}

export interface SocialHubConnectionData {
  platform: SocialHubPlatform;
  status: SocialHubConnectionStatus;
  displayName: string;
  accountId: string;
  message: string;
}

export interface SocialHubData {
  items: SocialHubItemData[];
  selected: SocialHubItemData;
  draft: SocialHubDraftData;
  connections: SocialHubConnectionData[];
}

interface LooseSocialHubItemData {
  id?: Object | string | number | boolean | null;
  platform?: Object | string | number | boolean | null;
  kind?: Object | string | number | boolean | null;
  author?: Object | string | number | boolean | null;
  handle?: Object | string | number | boolean | null;
  text?: Object | string | number | boolean | null;
  timestamp?: Object | string | number | boolean | null;
  url?: Object | string | number | boolean | null;
  channel?: Object | string | number | boolean | null;
  threadId?: Object | string | number | boolean | null;
  unread?: boolean;
}

interface LooseSocialHubDraftData {
  itemId?: Object | string | number | boolean | null;
  platform?: Object | string | number | boolean | null;
  text?: Object | string | number | boolean | null;
  status?: Object | string | number | boolean | null;
  error?: Object | string | number | boolean | null;
  sent?: boolean;
}

interface LooseSocialHubConnectionData {
  platform?: Object | string | number | boolean | null;
  status?: Object | string | number | boolean | null;
  displayName?: Object | string | number | boolean | null;
  accountId?: Object | string | number | boolean | null;
  message?: Object | string | number | boolean | null;
}

interface LooseSocialHubData {
  items?: Object[];
  selected?: Object;
  draft?: Object;
  connections?: Object[];
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

function normalizePlatform(value: Object | string | number | boolean | null | undefined): SocialHubPlatform {
  const text = textOf(value).toLowerCase();
  if (text === 'x' || text === 'twitter') {
    return 'x';
  }
  if (text === 'slack') {
    return 'slack';
  }
  if (text === 'wecom' || text === 'wework' || text === '企业微信') {
    return 'wecom';
  }
  return 'unknown';
}

function normalizeKind(value: Object | string | number | boolean | null | undefined): SocialHubItemKind {
  const text = textOf(value);
  if (text === 'message' || text === 'mention' || text === 'post' || text === 'connection') {
    return text as SocialHubItemKind;
  }
  return 'message';
}

function normalizeConnectionStatus(value: Object | string | number | boolean | null | undefined): SocialHubConnectionStatus {
  const text = textOf(value);
  if (text === 'connected' || text === 'needs_auth' || text === 'limited' || text === 'error' || text === 'disabled') {
    return text as SocialHubConnectionStatus;
  }
  return 'disabled';
}

function normalizeDraftStatus(value: Object | string | number | boolean | null | undefined): SocialHubDraftStatus {
  const text = textOf(value);
  if (text === 'empty' || text === 'draft' || text === 'error') {
    return text as SocialHubDraftStatus;
  }
  return 'empty';
}

export function emptySocialHubItem(): SocialHubItemData {
  return {
    id: '',
    platform: 'unknown',
    kind: 'message',
    author: '',
    handle: '',
    text: '',
    timestamp: '',
    url: '',
    channel: '',
    threadId: '',
    unread: false
  };
}

export function emptySocialHubDraft(): SocialHubDraftData {
  return {
    itemId: '',
    platform: 'unknown',
    text: '',
    status: 'empty',
    error: '',
    localOnly: true,
    sent: false
  };
}

export function emptySocialHub(): SocialHubData {
  return {
    items: [],
    selected: emptySocialHubItem(),
    draft: emptySocialHubDraft(),
    connections: []
  };
}

export function normalizeSocialHubItem(value: Object | SocialHubItemData | null | undefined): SocialHubItemData {
  if (value === undefined || value === null) {
    return emptySocialHubItem();
  }
  const source = value as LooseSocialHubItemData;
  return {
    id: textOf(source.id),
    platform: normalizePlatform(source.platform),
    kind: normalizeKind(source.kind),
    author: textOf(source.author),
    handle: textOf(source.handle),
    text: textOf(source.text),
    timestamp: textOf(source.timestamp),
    url: textOf(source.url),
    channel: textOf(source.channel),
    threadId: textOf(source.threadId),
    unread: source.unread === true
  };
}

export function normalizeSocialHubDraft(value: Object | SocialHubDraftData | null | undefined): SocialHubDraftData {
  if (value === undefined || value === null) {
    return emptySocialHubDraft();
  }
  const source = value as LooseSocialHubDraftData;
  return {
    itemId: textOf(source.itemId),
    platform: normalizePlatform(source.platform),
    text: textOf(source.text),
    status: normalizeDraftStatus(source.status),
    error: textOf(source.error),
    localOnly: true,
    sent: false
  };
}

export function normalizeSocialHubConnection(value: Object | SocialHubConnectionData | null | undefined): SocialHubConnectionData {
  if (value === undefined || value === null) {
    return {
      platform: 'unknown',
      status: 'disabled',
      displayName: '',
      accountId: '',
      message: ''
    };
  }
  const source = value as LooseSocialHubConnectionData;
  return {
    platform: normalizePlatform(source.platform),
    status: normalizeConnectionStatus(source.status),
    displayName: textOf(source.displayName),
    accountId: textOf(source.accountId),
    message: textOf(source.message)
  };
}

export function normalizeSocialHub(value: Object | SocialHubData | null | undefined, fallback: SocialHubData = emptySocialHub()): SocialHubData {
  if (value === undefined || value === null) {
    return fallback;
  }
  const source = value as LooseSocialHubData;
  const items: SocialHubItemData[] = [];
  const connections: SocialHubConnectionData[] = [];
  if (Array.isArray(source.items)) {
    source.items.forEach((item: Object) => {
      items.push(normalizeSocialHubItem(item));
    });
  }
  if (Array.isArray(source.connections)) {
    source.connections.forEach((connection: Object) => {
      connections.push(normalizeSocialHubConnection(connection));
    });
  }
  return {
    items: items,
    selected: source.selected === undefined ? fallback.selected : normalizeSocialHubItem(source.selected),
    draft: source.draft === undefined ? fallback.draft : normalizeSocialHubDraft(source.draft),
    connections: connections
  };
}
