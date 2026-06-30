import { describe, it, expect } from '@ohos/hypium';
import { componentById, labelValues } from '../main/ets/model/A2uiData';
import { A2uiComponent } from '../main/ets/model/A2uiTypes';
import {
  A2UI_STYLE_LAB_CASES,
  A2uiStyleLabCase,
  cloneA2uiStyleLabSurface,
  defaultA2uiStyleLabCase,
  findA2uiStyleLabCase
} from '../main/ets/pages/A2uiHome/mocks/A2uiStyleLabMocks';
import { rootComponentIdOf } from '../main/ets/pages/A2uiHome/render/A2uiRenderData';

export default function a2uiStyleLabMocksTest() {
  describe('a2uiStyleLabMocks', () => {
    it('contains selectable mock cases', 0, () => {
      expect(A2UI_STYLE_LAB_CASES.length > 0).assertTrue();
      expect(defaultA2uiStyleLabCase().id).assertEqual(A2UI_STYLE_LAB_CASES[0].id);
    });

    it('keeps every mock surface rooted in an existing component', 0, () => {
      A2UI_STYLE_LAB_CASES.forEach((item: A2uiStyleLabCase) => {
        const surface = item.surface;
        expect(componentById(surface, rootComponentIdOf(surface)) !== null).assertTrue();
      });
    });

    it('resolves known and unknown cases predictably', 0, () => {
      expect(findA2uiStyleLabCase('info_rows').id).assertEqual('info_rows');
      expect(findA2uiStyleLabCase('missing').id).assertEqual(defaultA2uiStyleLabCase().id);
    });

    it('provides row data for the info rows case', 0, () => {
      const surface = findA2uiStyleLabCase('info_rows').surface;
      const rows = componentById(surface, 'rows');

      expect(rows !== null).assertTrue();
      if (rows !== null) {
        expect(labelValues(surface, rows as A2uiComponent).length).assertEqual(4);
      }
    });

    it('keeps the food style lab case rich enough for html scene visual QA', 0, () => {
      const food = findA2uiStyleLabCase('food_choices').surface;
      const serialized = food.dataModelJson;

      expect(serialized.indexOf('三津汤包')).assertLarger(-1);
      expect(serialized.indexOf('N多寿司')).assertLarger(-1);
      expect(serialized.indexOf('高德')).assertLarger(-1);
      expect(serialized.indexOf('腾讯地图')).assertLarger(-1);
      expect(serialized.indexOf('百度地图')).assertLarger(-1);
      expect(serialized.indexOf('1500米')).assertLarger(-1);
      expect(serialized.indexOf('"location":""')).assertLarger(-1);
      expect(serialized.indexOf('淘宝闪购')).assertLarger(-1);
      expect(serialized.indexOf('瑞幸')).assertLarger(-1);

      const actions = JSON.stringify(food.components);
      expect(actions.indexOf('food_show_all')).assertLarger(-1);
      expect(actions.indexOf('food_filter_1km')).assertLarger(-1);
      expect(actions.indexOf('food_show_more')).assertLarger(-1);
    });

    it('clones mock surfaces before page state mutates them', 0, () => {
      const original = defaultA2uiStyleLabCase().surface;
      const cloned = cloneA2uiStyleLabSurface(original);
      cloned.components[0].id = 'changed';

      expect(original.components[0].id).assertEqual('root');
    });
  });
}
