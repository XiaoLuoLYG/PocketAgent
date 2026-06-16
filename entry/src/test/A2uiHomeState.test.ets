import { describe, it, expect } from '@ohos/hypium';
import { createInitialConnectionPanelState, updateConnectionPanelState } from '../main/ets/pages/A2uiHome/state/A2uiHomeState';

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
  });
}
