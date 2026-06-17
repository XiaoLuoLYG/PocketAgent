import { describe, it, expect } from '@ohos/hypium';
import { A2uiComponent, A2uiLabelValueData, A2uiSummaryData } from '../main/ets/model/A2uiTypes';
import { parseA2uiJsonl } from '../main/ets/model/A2uiParser';
import {
  A2uiPartialDataPatch,
  A2uiPartialRenderState,
  A2uiPartialUpdateResult,
  planA2uiPartialUpdate
} from '../main/ets/model/A2uiPartialUpdatePlanner';

function foodComponents(status: string): A2uiComponent[] {
  return [
    {
      id: 'root',
      component: 'SurfaceRoot',
      child: 'results',
      title: '外卖聚合搜索',
      body: '正在聚合餐饮来源',
      status: status
    },
    {
      id: 'results',
      component: 'FoodChoices',
      title: '外卖聚合搜索',
      body: '真实 provider 返回',
      status: status,
      dataPath: '/foods',
      actions: [
        { id: 'food_show_all', label: '全部范围', prompt: '显示全部附近餐饮', kind: 'client', variant: 'secondary' }
      ]
    }
  ];
}

function rowsPatch(value: string): A2uiPartialDataPatch {
  const rows: A2uiLabelValueData[] = [
    { label: '高德', value: value }
  ];
  return {
    path: '/rows',
    value: rows,
    signature: value
  };
}

function summaryPatch(text: string): A2uiPartialDataPatch {
  const summary: A2uiSummaryData = {
    text: text,
    toolName: 'food.search',
    dataLabel: '餐饮',
    count: 0
  };
  return {
    path: '/summary',
    value: summary,
    signature: text
  };
}

function renderState(status: string, rowsValue: string): A2uiPartialRenderState {
  const dataPatches: A2uiPartialDataPatch[] = [
    rowsPatch(rowsValue),
    summaryPatch(rowsValue)
  ];
  return {
    surfaceId: 'surface_food',
    root: 'root',
    title: '外卖聚合搜索',
    intent: 'food',
    status: status,
    sendDataModel: true,
    components: foodComponents(status),
    componentsSignature: 'food-layout-v1|' + status,
    dataPatches: dataPatches
  };
}

export default function a2uiPartialUpdatePlannerTest() {
  describe('a2uiPartialUpdatePlanner', () => {
    it('emits surface, components, and data on the first partial state', 0, () => {
      const result: A2uiPartialUpdateResult = planA2uiPartialUpdate(null, renderState('calling_tool', '等待中'));
      const parsed = parseA2uiJsonl(result.jsonl);

      expect(parsed.error).assertEqual('');
      expect(parsed.envelopes.length).assertEqual(4);
      expect(parsed.envelopes[0].createSurface?.surfaceId).assertEqual('surface_food');
      expect(parsed.envelopes[1].updateComponents?.components.length).assertEqual(2);
      expect(result.updatedDataPaths.length).assertEqual(2);
      expect(result.componentsUpdated).assertTrue();
    });

    it('emits only changed data paths when components and status stay stable', 0, () => {
      const first: A2uiPartialUpdateResult = planA2uiPartialUpdate(null, renderState('calling_tool', '等待中'));
      const second: A2uiPartialUpdateResult = planA2uiPartialUpdate(first.cache, renderState('calling_tool', '已返回 8 条'));
      const parsed = parseA2uiJsonl(second.jsonl);

      expect(parsed.error).assertEqual('');
      expect(parsed.envelopes.length).assertEqual(2);
      expect(parsed.envelopes[0].updateComponents === undefined).assertTrue();
      expect(parsed.envelopes[0].updateDataModel?.path).assertEqual('/rows');
      expect(parsed.envelopes[1].updateDataModel?.path).assertEqual('/summary');
      expect(second.componentsUpdated).assertFalse();
    });

    it('skips emitting when signatures are unchanged', 0, () => {
      const first: A2uiPartialUpdateResult = planA2uiPartialUpdate(null, renderState('calling_tool', '等待中'));
      const second: A2uiPartialUpdateResult = planA2uiPartialUpdate(first.cache, renderState('calling_tool', '等待中'));

      expect(second.jsonl).assertEqual('');
      expect(second.emittedEnvelopeCount).assertEqual(0);
    });

    it('emits surface and components when status changes to ready', 0, () => {
      const first: A2uiPartialUpdateResult = planA2uiPartialUpdate(null, renderState('calling_tool', '已返回 8 条'));
      const ready: A2uiPartialUpdateResult = planA2uiPartialUpdate(first.cache, renderState('ready', '已返回 8 条'));
      const parsed = parseA2uiJsonl(ready.jsonl);

      expect(parsed.error).assertEqual('');
      expect(parsed.envelopes.length).assertEqual(2);
      expect(parsed.envelopes[0].createSurface?.status).assertEqual('ready');
      expect(parsed.envelopes[1].updateComponents?.components[0].status).assertEqual('ready');
      expect(ready.updatedDataPaths.length).assertEqual(0);
    });
  });
}
