import {
  A2uiLabelValueData,
  A2uiSocialMessageData,
  A2uiSocialReplyData
} from './A2uiTypes';

export interface SocialCaptureCandidate {
  platform: string;
  conversationId?: string;
  conversationTitle: string;
  senderName: string;
  preview: string;
  receivedAt: string;
  source: string;
}

export interface SocialIngestResult {
  accepted: boolean;
  message: A2uiSocialMessageData;
  reason: string;
}

export interface SocialCaptureResult {
  ok: boolean;
  source: string;
  messages: SocialCaptureCandidate[];
  error: string;
}

export interface SocialCapabilityInput {
  notificationBridgeAvailable: boolean;
  accessibilityAvailable: boolean;
  wechatInstalled: boolean;
  lastCapture: string;
  lastSend: string;
}

export interface SocialCapabilities {
  notificationBridgeAvailable: boolean;
  accessibilityAvailable: boolean;
  wechatInstalled: boolean;
  lastCapture: string;
  lastSend: string;
}

export interface SocialReplyRequest {
  targetMessageId: string;
  platform: string;
  conversationId: string;
  text: string;
}

export interface WechatReplyExecutor {
  send(request: SocialReplyRequest): A2uiSocialReplyData;
}

function textOf(value: string | undefined | null): string {
  if (value === undefined || value === null) {
    return '';
  }
  return value.trim();
}

function emptyMessage(): A2uiSocialMessageData {
  return {
    id: '',
    platform: '',
    conversationId: '',
    conversationTitle: '',
    senderName: '',
    preview: '',
    receivedAt: '',
    source: '',
    status: 'failed'
  };
}

function timestampOf(value: string): number {
  const parsed = Date.parse(value);
  if (!isNaN(parsed)) {
    return parsed;
  }
  return Date.now();
}

function minuteBucket(value: string): string {
  return Math.floor(timestampOf(value) / 60000).toString();
}

function stableHash(source: string): string {
  let hash = 0;
  for (let index = 0; index < source.length; index++) {
    hash = ((hash * 31) + source.charCodeAt(index)) % 1000000007;
  }
  return Math.abs(hash).toString();
}

function normalizePlatform(value: string): string {
  const normalized = textOf(value).toLowerCase();
  if (normalized === 'wechat' || normalized === '微信' || normalized === 'weixin') {
    return 'wechat';
  }
  return normalized;
}

function normalizeSource(value: string): string {
  const normalized = textOf(value).toLowerCase();
  if (normalized === 'notification' || normalized === '通知') {
    return 'notification';
  }
  if (normalized === 'accessibility' || normalized === '辅助') {
    return 'accessibility';
  }
  if (normalized === 'official' || normalized === 'api') {
    return 'official';
  }
  return normalized;
}

function conversationIdFor(candidate: SocialCaptureCandidate): string {
  const explicitId = textOf(candidate.conversationId);
  if (explicitId.length > 0) {
    return explicitId;
  }
  const platform = normalizePlatform(candidate.platform);
  const title = textOf(candidate.conversationTitle);
  return platform + '-' + stableHash(title);
}

function messageDedupeKey(candidate: SocialCaptureCandidate): string {
  return normalizePlatform(candidate.platform) + '|' +
    textOf(candidate.conversationTitle) + '|' +
    textOf(candidate.preview) + '|' +
    minuteBucket(textOf(candidate.receivedAt));
}

function messageFromCandidate(candidate: SocialCaptureCandidate): A2uiSocialMessageData {
  const platform = normalizePlatform(candidate.platform);
  const conversationTitle = textOf(candidate.conversationTitle);
  const senderName = textOf(candidate.senderName).length > 0 ? textOf(candidate.senderName) : conversationTitle;
  const preview = textOf(candidate.preview);
  const receivedAt = textOf(candidate.receivedAt).length > 0 ? textOf(candidate.receivedAt) : new Date().toISOString();
  const source = normalizeSource(candidate.source);
  const dedupeKey = messageDedupeKey({
    platform,
    conversationTitle,
    senderName,
    preview,
    receivedAt,
    source,
    conversationId: conversationIdFor(candidate)
  });
  return {
    id: platform + '-' + stableHash(dedupeKey),
    platform,
    conversationId: conversationIdFor(candidate),
    conversationTitle,
    senderName,
    preview,
    receivedAt,
    source,
    status: 'unread'
  };
}

function isRealCandidate(candidate: SocialCaptureCandidate): boolean {
  return normalizePlatform(candidate.platform).length > 0 &&
    textOf(candidate.conversationTitle).length > 0 &&
    textOf(candidate.preview).length > 0 &&
    normalizeSource(candidate.source).length > 0;
}

export class SocialMessageStore {
  private retentionMs: number;
  private maxMessages: number;
  private items: A2uiSocialMessageData[] = [];
  private dedupeKeys: string[] = [];

  constructor(retentionMs: number = 24 * 60 * 60 * 1000, maxMessages: number = 100) {
    this.retentionMs = retentionMs;
    this.maxMessages = maxMessages;
  }

  ingest(candidate: SocialCaptureCandidate, nowIso: string = new Date().toISOString()): SocialIngestResult {
    this.prune(nowIso);
    if (!isRealCandidate(candidate)) {
      return {
        accepted: false,
        message: emptyMessage(),
        reason: '消息缺少真实来源、会话或正文'
      };
    }
    const key = messageDedupeKey(candidate);
    const existingIndex = this.dedupeKeys.indexOf(key);
    if (existingIndex >= 0) {
      return {
        accepted: false,
        message: this.items[existingIndex],
        reason: 'duplicate'
      };
    }
    const message = messageFromCandidate(candidate);
    this.items.push(message);
    this.dedupeKeys.push(key);
    this.prune(nowIso);
    return {
      accepted: true,
      message,
      reason: ''
    };
  }

  messages(): A2uiSocialMessageData[] {
    const copy = this.items.slice();
    copy.sort((left: A2uiSocialMessageData, right: A2uiSocialMessageData) => {
      return timestampOf(right.receivedAt) - timestampOf(left.receivedAt);
    });
    return copy;
  }

  private prune(nowIso: string): void {
    const cutoff = timestampOf(nowIso) - this.retentionMs;
    const nextItems: A2uiSocialMessageData[] = [];
    const nextKeys: string[] = [];
    for (let index = 0; index < this.items.length; index++) {
      if (timestampOf(this.items[index].receivedAt) >= cutoff) {
        nextItems.push(this.items[index]);
        nextKeys.push(this.dedupeKeys[index]);
      }
    }
    while (nextItems.length > this.maxMessages) {
      nextItems.shift();
      nextKeys.shift();
    }
    this.items = nextItems;
    this.dedupeKeys = nextKeys;
  }
}

export class NotificationIngestProvider {
  private available: boolean;
  private unavailableReason: string;
  private captured: SocialCaptureCandidate[];

  constructor(available: boolean = false, unavailableReason: string = '通知中心桥接不可用', captured: SocialCaptureCandidate[] = []) {
    this.available = available;
    this.unavailableReason = unavailableReason;
    this.captured = captured;
  }

  capture(): SocialCaptureResult {
    if (!this.available) {
      return {
        ok: false,
        source: 'notification',
        messages: [],
        error: this.unavailableReason
      };
    }
    return {
      ok: true,
      source: 'notification',
      messages: this.captured.slice(),
      error: ''
    };
  }
}

export class AccessibilityIngestProvider {
  private available: boolean;
  private unavailableReason: string;
  private captured: SocialCaptureCandidate[];

  constructor(available: boolean = false, unavailableReason: string = '辅助捕获不可用', captured: SocialCaptureCandidate[] = []) {
    this.available = available;
    this.unavailableReason = unavailableReason;
    this.captured = captured;
  }

  capture(): SocialCaptureResult {
    if (!this.available) {
      return {
        ok: false,
        source: 'accessibility',
        messages: [],
        error: this.unavailableReason
      };
    }
    return {
      ok: true,
      source: 'accessibility',
      messages: this.captured.slice(),
      error: ''
    };
  }
}

export class WechatReplyAutomation {
  private available: boolean;
  private unavailableReason: string;
  private executor: WechatReplyExecutor | null;

  constructor(available: boolean = false, unavailableReason: string = '微信辅助自动化不可用', executor: WechatReplyExecutor | null = null) {
    this.available = available;
    this.unavailableReason = unavailableReason;
    this.executor = executor;
  }

  send(request: SocialReplyRequest): A2uiSocialReplyData {
    if (!this.available) {
      return this.failedReply(request, this.unavailableReason);
    }
    if (this.executor === null) {
      return this.failedReply(request, '未接入真实微信辅助发送器');
    }
    return this.executor.send(request);
  }

  private failedReply(request: SocialReplyRequest, error: string): A2uiSocialReplyData {
    return {
      id: 'reply-' + stableHash(request.targetMessageId + '|' + request.text + '|' + new Date().toISOString()),
      targetMessageId: request.targetMessageId,
      platform: normalizePlatform(request.platform),
      conversationId: textOf(request.conversationId),
      text: request.text,
      status: 'failed',
      error,
      sentAt: ''
    };
  }
}

export function probeSocialCapabilities(input: SocialCapabilityInput): SocialCapabilities {
  return {
    notificationBridgeAvailable: input.notificationBridgeAvailable,
    accessibilityAvailable: input.accessibilityAvailable,
    wechatInstalled: input.wechatInstalled,
    lastCapture: textOf(input.lastCapture),
    lastSend: textOf(input.lastSend)
  };
}

function availability(value: boolean): string {
  return value ? '可用' : '不可用';
}

export function buildSocialDiagnosticsRows(capabilities: SocialCapabilities): A2uiLabelValueData[] {
  return [
    {
      label: '通知权限名',
      value: 'ohos.permission.SUBSCRIBE_NOTIFICATION'
    },
    {
      label: '通知中心桥接',
      value: availability(capabilities.notificationBridgeAvailable)
    },
    {
      label: '辅助权限',
      value: availability(capabilities.accessibilityAvailable)
    },
    {
      label: '微信识别',
      value: capabilities.wechatInstalled ? '已检测到' : '未检测到'
    },
    {
      label: '最近捕获',
      value: capabilities.lastCapture.length > 0 ? capabilities.lastCapture : '无真实消息'
    },
    {
      label: '最近发送',
      value: capabilities.lastSend.length > 0 ? capabilities.lastSend : '未发送'
    }
  ];
}
