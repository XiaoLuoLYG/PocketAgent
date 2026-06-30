import { A2uiAction, A2uiGenericToolResultData, A2uiGenericToolResultRowData } from './A2uiTypes';

export function officialMediaVideoPlaybackUrl(value: string): string {
  const url = value.trim();
  if (url.startsWith('https://www.youtube.com/watch?') ||
    url.startsWith('https://youtube.com/watch?') ||
    url.startsWith('https://youtu.be/') ||
    url.startsWith('https://player.bilibili.com/player.html?') ||
    url.startsWith('https://www.bilibili.com/video/') ||
    url.startsWith('https://m.bilibili.com/video/')) {
    return url;
  }
  return '';
}

function rowValue(item: A2uiGenericToolResultData, labels: string[]): string {
  for (let rowIndex = 0; rowIndex < item.rows.length; rowIndex++) {
    const row: A2uiGenericToolResultRowData = item.rows[rowIndex];
    for (let labelIndex = 0; labelIndex < labels.length; labelIndex++) {
      const url = officialMediaVideoPlaybackUrl(row.value);
      if (row.label === labels[labelIndex] && url.length > 0) {
        return url;
      }
    }
  }
  return '';
}

export function isMediaVideoResult(item: A2uiGenericToolResultData): boolean {
  return item.toolName === 'media.video.search' ||
    item.toolName === 'youtube.video.search' ||
    item.sourceTag === 'YouTube Data API' ||
    item.sourceTag === '哔哩哔哩';
}

export function mediaVideoPlaybackUrl(item: A2uiGenericToolResultData): string {
  return rowValue(item, ['Watch URL', 'Share URL', 'Playback URL', 'Video URL']);
}

export function mediaVideoPlaybackAction(item: A2uiGenericToolResultData): A2uiAction | null {
  if (!isMediaVideoResult(item) || item.status !== 'success') {
    return null;
  }
  const url = mediaVideoPlaybackUrl(item).trim();
  if (url.length === 0) {
    return null;
  }
  return {
    id: 'media.open.web',
    label: '跳转',
    prompt: url,
    variant: 'primary',
    kind: 'client'
  };
}
