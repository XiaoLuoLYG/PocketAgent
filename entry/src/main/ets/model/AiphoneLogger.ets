import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'AIPhone';
const MAX_LOG_CHARS = 3000;

function trimForLog(message: string): string {
  if (message.length <= MAX_LOG_CHARS) {
    return message;
  }
  return message.substring(0, MAX_LOG_CHARS) + '...<truncated>';
}

export function aiLogInfo(message: string): void {
  const safe = trimForLog(message);
  hilog.info(DOMAIN, TAG, '%{public}s', safe);
  console.info(safe);
}

export function aiLogError(message: string): void {
  const safe = trimForLog(message);
  hilog.error(DOMAIN, TAG, '%{public}s', safe);
  console.error(safe);
}

