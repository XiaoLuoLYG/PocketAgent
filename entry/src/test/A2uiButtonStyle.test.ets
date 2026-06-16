import { describe, it, expect } from '@ohos/hypium';
import { resolveA2uiButtonStyle } from '../main/ets/pages/A2uiHome/style/A2uiButtonStyle';
import {
  COLOR_ACCENT,
  COLOR_ACCENT_DEEP,
  COLOR_ACTION_ACTIVATED,
  COLOR_ACTION_DEACTIVATED,
  COLOR_BUTTON_TEXT,
  COLOR_ERROR_SOFT
} from '../main/ets/pages/A2uiHome/style/A2uiHomeTheme';

export default function a2uiButtonStyleTest() {
  describe('a2uiButtonStyle', () => {
    it('uses activated style when active', 0, () => {
      const style = resolveA2uiButtonStyle('secondary', true, true);

      expect(style.backgroundColor).assertEqual(COLOR_ACTION_ACTIVATED);
      expect(style.backgroundColor).assertEqual(COLOR_ACCENT_DEEP);
      expect(style.borderColor).assertEqual(COLOR_ACCENT);
      expect(style.textColor).assertEqual(COLOR_BUTTON_TEXT);
    });

    it('uses disabled style before active or tone', 0, () => {
      const style = resolveA2uiButtonStyle('danger', true, false);

      expect(style.backgroundColor).assertEqual(COLOR_ACTION_DEACTIVATED);
      expect(style.opacity < 1).assertTrue();
    });

    it('uses danger style when enabled and not overridden by disabled', 0, () => {
      expect(resolveA2uiButtonStyle('danger', false, true).backgroundColor).assertEqual(COLOR_ERROR_SOFT);
    });
  });
}
