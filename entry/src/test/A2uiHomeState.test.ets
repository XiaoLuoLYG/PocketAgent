import { describe, it, expect } from '@ohos/hypium';
import { A2uiSurfaceState } from '../main/ets/model/A2uiTypes';
import {
  A2UI_SEND_SPINNER_STEP_DEG,
  createInitialConnectionPanelState,
  inputTextAfterPromptSubmit,
  isPromptInputEnabled,
  nextSendSpinnerRotation,
  shouldShowQueryPendingSurface,
  shouldApplySurfaceUpdate,
  updateConnectionPanelState
} from '../main/ets/pages/A2uiHome/state/A2uiHomeState';

function surface(sequence: number, status: string): A2uiSurfaceState {
  return {
    surfaceId: 'surface_model',
    rootId: 'root',
    title: '测试',
    intent: 'food',
    status: status,
    components: [],
    dataModelJson: '{}',
    error: '',
    sequence: sequence
  };
}

export default function a2uiHomeStateTest() {
  describe('a2uiHomeState', () => {
    it('updates panel state after a successful connection check', 0, () => {
      const initial = createInitialConnectionPanelState();
      const next = updateConnectionPanelState(initial, {
        ok: true,
        status: 'ready',
        message: '模型连接正常',
        requestDebug: 'POST /chat/completions',
        assistantDebug: '{"version":"v0.9.1"}',
        error: ''
      });

      expect(next.connectionStatus).assertEqual('ready');
      expect(next.connectionMessage).assertEqual('模型连接正常');
      expect(next.lastModelRequest).assertEqual('POST /chat/completions');
      expect(next.lastModelOutput).assertEqual('{"version":"v0.9.1"}');
      expect(next.lastError).assertEqual('');
      expect(next.refreshTick).assertEqual(1);
    });

    it('updates panel state after a failed connection check', 0, () => {
      const initial = createInitialConnectionPanelState();
      const next = updateConnectionPanelState(initial, {
        ok: false,
        status: 'error',
        message: '模型连接异常',
        requestDebug: '',
        assistantDebug: '',
        error: 'ECONNREFUSED'
      });

      expect(next.connectionStatus).assertEqual('error');
      expect(next.connectionMessage).assertEqual('模型连接异常');
      expect(next.lastError).assertEqual('ECONNREFUSED');
      expect(next.refreshTick).assertEqual(1);
    });

    it('skips applying the same surface sequence twice', 0, () => {
      expect(shouldApplySurfaceUpdate(surface(12, 'ready'), surface(12, 'ready'))).assertFalse();
      expect(shouldApplySurfaceUpdate(surface(12, 'calling_tool'), surface(13, 'ready'))).assertTrue();
    });

    it('keeps send spinner rotation monotonic while loading', 0, () => {
      expect(nextSendSpinnerRotation(360 - A2UI_SEND_SPINNER_STEP_DEG, true)).assertEqual(360);
      expect(nextSendSpinnerRotation(360, true)).assertEqual(360 + A2UI_SEND_SPINNER_STEP_DEG);
      expect(nextSendSpinnerRotation(360 + A2UI_SEND_SPINNER_STEP_DEG, false)).assertEqual(0);
    });

    it('locks prompt input while busy and preserves submitted text', 0, () => {
      expect(isPromptInputEnabled(false)).assertTrue();
      expect(isPromptInputEnabled(true)).assertFalse();
      expect(inputTextAfterPromptSubmit('帮我查深圳北站附近餐馆')).assertEqual('帮我查深圳北站附近餐馆');
    });

    it('shows the query pending surface only before the first new render arrives', 0, () => {
      expect(shouldShowQueryPendingSurface(true, true)).assertTrue();
      expect(shouldShowQueryPendingSurface(true, false)).assertFalse();
      expect(shouldShowQueryPendingSurface(false, true)).assertFalse();
    });
  });
}
