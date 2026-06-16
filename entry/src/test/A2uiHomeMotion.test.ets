import { describe, it, expect } from '@ohos/hypium';
import {
  a2uiThinkingDotOpacity,
  a2uiThinkingDotScale,
  a2uiThinkingDotsActive
} from '../main/ets/pages/A2uiHome/style/A2uiHomeMotion';

export default function a2uiHomeMotionTest() {
  describe('a2uiHomeMotion', () => {
    it('staggers thinking dot opacity by index', 0, () => {
      const activeStep = 1;

      expect(a2uiThinkingDotOpacity(1, activeStep) > a2uiThinkingDotOpacity(0, activeStep)).assertTrue();
      expect(a2uiThinkingDotOpacity(0, activeStep) > a2uiThinkingDotOpacity(2, activeStep)).assertTrue();
    });

    it('keeps thinking dot scale in a visible breathing range', 0, () => {
      expect(a2uiThinkingDotScale(0, 1) > a2uiThinkingDotScale(2, 1)).assertTrue();
      expect(a2uiThinkingDotScale(1, 1) >= 1.2).assertTrue();
    });

    it('only animates thinking dots while actively processing', 0, () => {
      expect(a2uiThinkingDotsActive(true, 'thinking')).assertTrue();
      expect(a2uiThinkingDotsActive(true, 'calling_tool')).assertTrue();
      expect(a2uiThinkingDotsActive(true, 'ready')).assertFalse();
      expect(a2uiThinkingDotsActive(false, 'thinking')).assertFalse();
    });
  });
}
