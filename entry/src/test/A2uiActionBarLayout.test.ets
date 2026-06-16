import { describe, it, expect } from '@ohos/hypium';
import {
  A2UI_DIALOG_ACTION_COUNT,
  usesDialogActionLayout
} from '../main/ets/pages/A2uiHome/style/A2uiActionBarLayout';

export default function a2uiActionBarLayoutTest() {
  describe('a2uiActionBarLayout', () => {
    it('uses dialog action layout for exactly two actions', 0, () => {
      expect(usesDialogActionLayout(A2UI_DIALOG_ACTION_COUNT)).assertTrue();
    });

    it('keeps wrap layout for zero one or dense actions', 0, () => {
      expect(usesDialogActionLayout(0)).assertFalse();
      expect(usesDialogActionLayout(1)).assertFalse();
      expect(usesDialogActionLayout(3)).assertFalse();
      expect(usesDialogActionLayout(7)).assertFalse();
    });
  });
}
