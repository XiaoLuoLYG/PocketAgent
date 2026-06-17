import { A2uiSurfaceState } from '../../../model/A2uiTypes';

export interface ConnectionPanelState {
  connectionStatus: string;
  connectionMessage: string;
  lastModelRequest: string;
  lastModelOutput: string;
  lastError: string;
  refreshTick: number;
}

export interface ConnectionPanelUpdate {
  ok: boolean;
  status: string;
  message: string;
  requestDebug: string;
  assistantDebug: string;
  error: string;
}

export function createInitialConnectionPanelState(): ConnectionPanelState {
  return {
    connectionStatus: 'idle',
    connectionMessage: '尚未测试模型连接。',
    lastModelRequest: '',
    lastModelOutput: '',
    lastError: '',
    refreshTick: 0
  };
}

export function updateConnectionPanelState(current: ConnectionPanelState, update: ConnectionPanelUpdate): ConnectionPanelState {
  return {
    connectionStatus: update.status,
    connectionMessage: update.message,
    lastModelRequest: update.requestDebug,
    lastModelOutput: update.assistantDebug,
    lastError: update.ok ? '' : update.error,
    refreshTick: current.refreshTick + 1
  };
}

export function shouldApplySurfaceUpdate(current: A2uiSurfaceState, next: A2uiSurfaceState): boolean {
  return current.surfaceId !== next.surfaceId || current.sequence !== next.sequence;
}

export function connectionStatusLabel(status: string): string {
  if (status === 'checking') {
    return '检查中';
  }
  if (status === 'ready') {
    return '连接正常';
  }
  if (status === 'error') {
    return '连接异常';
  }
  return '未检查';
}
