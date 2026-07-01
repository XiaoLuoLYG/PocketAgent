import {
  SocialHubConnectionData,
  SocialHubConnectionStatus,
  SocialHubDraftData,
  SocialHubItemData,
  SocialHubItemKind,
  SocialHubPlatform
} from '../../../model/SocialHubTypes';

export function socialHubPlatformLabel(platform: SocialHubPlatform | string): string {
  if (platform === 'x') {
    return 'X';
  }
  if (platform === 'slack') {
    return 'Slack';
  }
  if (platform === 'wecom') {
    return '企业微信';
  }
  return '未知';
}

export function socialHubKindLabel(kind: SocialHubItemKind | string): string {
  if (kind === 'post') {
    return '公开 post';
  }
  if (kind === 'mention') {
    return '提及';
  }
  if (kind === 'connection') {
    return '连接';
  }
  return '私信';
}

export function socialHubPrimaryText(item: SocialHubItemData): string {
  const text = item.text.trim();
  return text.length > 0 ? text : '没有正文';
}

export function socialHubAuthorText(item: SocialHubItemData): string {
  if (item.author.length > 0 && item.handle.length > 0) {
    return item.author + ' · ' + item.handle;
  }
  if (item.author.length > 0) {
    return item.author;
  }
  if (item.handle.length > 0) {
    return item.handle;
  }
  return socialHubPlatformLabel(item.platform);
}

export function socialHubItemMetaText(item: SocialHubItemData): string {
  const platform = socialHubPlatformLabel(item.platform);
  const kind = socialHubKindLabel(item.kind);
  if (item.channel.length > 0 && item.timestamp.length > 0) {
    return platform + ' · ' + kind + ' · ' + item.channel + ' · ' + item.timestamp;
  }
  if (item.channel.length > 0) {
    return platform + ' · ' + kind + ' · ' + item.channel;
  }
  if (item.timestamp.length > 0) {
    return platform + ' · ' + kind + ' · ' + item.timestamp;
  }
  return platform + ' · ' + kind;
}

export function socialHubConnectionStatusLabel(status: SocialHubConnectionStatus | string): string {
  if (status === 'connected') {
    return '已连接';
  }
  if (status === 'needs_auth') {
    return '待授权';
  }
  if (status === 'limited') {
    return '受限';
  }
  if (status === 'error') {
    return '异常';
  }
  return '未启用';
}

export function socialHubBadgeStatus(status: SocialHubConnectionStatus | string): string {
  if (status === 'connected') {
    return 'ready';
  }
  if (status === 'error') {
    return 'error';
  }
  if (status === 'needs_auth' || status === 'limited') {
    return 'checking';
  }
  return 'idle';
}

export function socialHubConnectionMessage(connection: SocialHubConnectionData): string {
  if (connection.message.length > 0) {
    return connection.message;
  }
  if (connection.displayName.length > 0) {
    return connection.displayName;
  }
  return socialHubConnectionStatusLabel(connection.status);
}

export function socialHubDraftDisplayText(draft: SocialHubDraftData): string {
  if (draft.status === 'error') {
    return draft.error.length > 0 ? draft.error : '草稿生成失败';
  }
  if (draft.text.trim().length > 0) {
    return draft.text;
  }
  return '尚未生成草稿';
}
