import { describe, it, expect } from '@ohos/hypium';
import { renderHtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeRenderer';
import { HtmlHomeDocument } from '../main/ets/pages/A2uiHome/html/HtmlHomeTypes';

function documentFixture(): HtmlHomeDocument {
  return {
    version: 1,
    source: 'tool',
    kind: 'generic',
    title: 'Project Brief',
    subtitle: 'Today',
    chips: [{ label: 'status', value: 'ready' }],
    metrics: [{ label: 'blocks', value: '1' }],
    timeline: [{ title: 'Draft', subtitle: 'Collected notes', status: 'ready' }],
    blocks: [{
      id: 'block-1',
      kind: 'note',
      title: 'Known Block',
      subtitle: 'Rendered from document data',
      status: 'ready',
      metrics: [{ label: 'owner', value: 'local' }],
      rows: [{ label: 'next', value: 'review' }],
      actions: [{ id: 'block-action', label: 'Review Block', prompt: 'review it', variant: 'primary', kind: 'prompt' }]
    }],
    actions: [{ id: 'doc-action', label: 'Run Action', prompt: 'run it', variant: 'primary', kind: 'prompt' }],
    history: [{ id: 'm1', role: 'user', content: 'make a brief' }],
    rawSurfaceRoot: null,
    generatedAt: '2026-06-25T00:00:00.000Z'
  };
}

function dynamicCredentialDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.blocks = [{
    id: 'connect',
    kind: 'dynamic-tool-connect',
    title: 'Amap Maps',
    subtitle: 'API key required',
    status: 'needs_auth',
    credentialName: 'API Key',
    credentialRef: 'dynamic:maps:API Key',
    toolId: 'maps.weather',
    prompt: 'weather now',
    metrics: [],
    rows: [],
    actions: []
  }];
  return doc;
}

function travelFoodCardsDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'travel';
  doc.title = '深圳北到上海虹桥';
  doc.subtitle = 'Travel and food results';
  doc.blocks = [{
    id: 'train-g123',
    kind: 'train-option',
    title: 'G123',
    subtitle: '深圳北 -> 上海虹桥',
    status: 'available',
    source: '12306',
    metrics: [
      { label: 'duration', value: '6h30m' },
      { label: 'source', value: 'train' }
    ],
    rows: [
      { label: 'depart', value: '09:00' },
      { label: 'arrive', value: '15:30' },
      { label: 'seats', value: '二等座有票' }
    ],
    actions: [{ id: 'html_pin_travel', label: '收藏行程', prompt: 'pin train', variant: 'secondary', kind: 'client' }]
  }, {
    id: 'food-amap-1',
    kind: 'food-result',
    title: '麦当劳 科技园店',
    subtitle: '步行可达',
    status: 'ready',
    source: 'amap',
    metrics: [
      { label: 'distance', value: '450m' },
      { label: 'source', value: 'amap' }
    ],
    rows: [
      { label: 'address', value: '科技园路 1 号' },
      { label: 'rating', value: '4.6' }
    ],
    actions: [{ id: 'html_open_food_map', label: '打开地图', prompt: 'open food map', variant: 'primary', kind: 'client' }]
  }];
  doc.actions = [];
  return doc;
}

export default function htmlHomeRendererTest() {
  describe('htmlHomeRenderer', () => {
    it('returns a full HTML document with document content', 0, () => {
      const html = renderHtmlHomeDocument(documentFixture());

      expect(html.indexOf('<!DOCTYPE html>')).assertEqual(0);
      expect(html.indexOf('<html')).assertLarger(-1);
      expect(html.indexOf('Project Brief')).assertLarger(-1);
      expect(html.indexOf('Known Block')).assertLarger(-1);
      expect(html.indexOf('Run Action')).assertLarger(-1);
    });

    it('escapes dangerous script text in embedded JSON', 0, () => {
      const doc = documentFixture();
      doc.title = '</script><img src=x onerror=alert(1)>';

      const html = renderHtmlHomeDocument(doc);

      expect(html.indexOf('</script><img')).assertEqual(-1);
      expect(html.indexOf('\\u003c/script\\u003e\\u003cimg')).assertLarger(-1);
    });

    it('includes the ArkWeb action bridge call', 0, () => {
      const html = renderHtmlHomeDocument(documentFixture());

      expect(html.indexOf('AIPhoneHome.postAction')).assertLarger(-1);
    });

    it('includes dynamic credential save and local action interception', 0, () => {
      const html = renderHtmlHomeDocument(dynamicCredentialDocumentFixture());

      expect(html.indexOf('保存并测试')).assertLarger(-1);
      expect(html.indexOf('html_dynamic_save_and_test')).assertLarger(-1);
      expect(html.indexOf('handleLocalAction')).assertLarger(-1);
      expect(html.indexOf('travel_filter_train')).assertLarger(-1);
      expect(html.indexOf('food_filter_1km')).assertLarger(-1);
      expect(html.indexOf('client_sort_fastest')).assertLarger(-1);
      expect(html.indexOf('trainShowMore: false')).assertLarger(-1);
      expect(html.indexOf('localState.trainShowMore = !localState.trainShowMore')).assertLarger(-1);
      expect(html.indexOf('data-train-index')).assertLarger(-1);
      expect(html.indexOf('trainVisibleCount > 6')).assertLarger(-1);
    });

    it('disables HTML actions and credential save while busy', 0, () => {
      const html = renderHtmlHomeDocument(dynamicCredentialDocumentFixture(), true);

      expect(html.indexOf('"isBusy":true')).assertLarger(-1);
      expect(html.indexOf('if (isBusy) { return; }')).assertLarger(-1);
      expect(html.indexOf('button.disabled = isBusy')).assertLarger(-1);
    });

    it('keeps local empty-filter feedback without row-level flight retry', 0, () => {
      const html = renderHtmlHomeDocument(documentFixture());

      expect(html.indexOf("input.type = 'date'")).assertEqual(-1);
      expect(html.indexOf('flight_retry_date')).assertEqual(-1);
      expect(html.indexOf('updateVisibleCount')).assertLarger(-1);
      expect(html.indexOf('filter-empty')).assertLarger(-1);
    });

    it('keeps mobile text from overflowing and avoids fake remote base urls', 0, () => {
      const html = renderHtmlHomeDocument(documentFixture());

      expect(html.indexOf('overflow-wrap: anywhere')).assertLarger(-1);
      expect(html.indexOf('max-width: min(42%, 180px)')).assertLarger(-1);
      expect(html.indexOf('flex: 0 0 auto')).assertLarger(-1);
      expect(html.indexOf('https://aiphone.local')).assertEqual(-1);
    });

    it('keeps travel and food card details collapsed behind source aware expansion hooks', 0, () => {
      const html = renderHtmlHomeDocument(travelFoodCardsDocumentFixture());
      const resultSectionIndex = html.indexOf('任务结果');
      const timelineSectionIndex = html.indexOf('执行轨迹');

      expect(html.indexOf('G123')).assertLarger(-1);
      expect(html.indexOf('麦当劳 科技园店')).assertLarger(-1);
      expect(resultSectionIndex).assertLarger(-1);
      expect(timelineSectionIndex).assertEqual(-1);
      expect(html.indexOf('data-expandable')).assertLarger(-1);
      expect(html.indexOf('data-source-key')).assertLarger(-1);
      expect(html.indexOf('classList.toggle')).assertLarger(-1);
      expect(html.indexOf('expandedKey')).assertLarger(-1);
      expect(html.indexOf('querySelectorAll')).assertLarger(-1);
      expect(html.indexOf('data-expandable="true"')).assertLarger(-1);
      expect(html.indexOf('.block:not(.expanded) .details')).assertLarger(-1);
      expect(html.indexOf("button.textContent = expanded ? '收起' : '展开'")).assertLarger(-1);
      expect(html.indexOf("add(top, 'button', 'expand-button', '展开')")).assertLarger(-1);
      expect(html.indexOf("add(statusWrap, 'button', 'expand-button', '详情')")).assertEqual(-1);
      expect(html.indexOf("kind === 'generic-tool-result'")).assertLarger(-1);
      expect(html.indexOf('addPairs(detailHost, block.metrics')).assertLarger(-1);
      expect(html.indexOf('event.stopPropagation()')).assertLarger(-1);
      expect(html.indexOf('sourceKey')).assertLarger(-1);
    });

    it('does not auto-render welcome scene and source chips', 0, () => {
      const doc = documentFixture();
      doc.source = 'welcome';
      doc.kind = 'welcome';
      doc.title = 'Appless Phone';
      doc.subtitle = '';
      doc.chips = [];
      doc.metrics = [];
      doc.timeline = [];
      doc.blocks = [];
      doc.actions = [];
      const html = renderHtmlHomeDocument(doc);

      expect(html.indexOf('场景')).assertEqual(-1);
      expect(html.indexOf('来源')).assertEqual(-1);
      expect(html.indexOf('待命')).assertEqual(-1);
    });
  });
}
