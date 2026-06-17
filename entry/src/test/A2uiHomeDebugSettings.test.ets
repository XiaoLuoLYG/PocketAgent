import { describe, it, expect } from '@ohos/hypium';
import { normalizeFoodProviderDelayMs } from '../main/ets/pages/A2uiHome/state/A2uiHomeDebugSettings';

export default function a2uiHomeDebugSettingsTest() {
  describe('a2uiHomeDebugSettings', () => {
    it('normalizes food provider delay milliseconds for debug settings', 0, () => {
      expect(normalizeFoodProviderDelayMs('')).assertEqual(0);
      expect(normalizeFoodProviderDelayMs(' 2500 ')).assertEqual(2500);
      expect(normalizeFoodProviderDelayMs('-3')).assertEqual(0);
      expect(normalizeFoodProviderDelayMs('abc')).assertEqual(0);
      expect(normalizeFoodProviderDelayMs('90000')).assertEqual(30000);
    });
  });
}
