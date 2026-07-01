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
  doc.kind = 'dynamic-tools';
  doc.title = '动态工具连接';
  doc.subtitle = '工具需要授权后才能继续';
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

function foodDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'food';
  doc.title = '外卖聚合搜索';
  doc.subtitle = '以下结果来自高德、腾讯地图、百度地图；仅展示真实返回字段。';
  doc.chips = [];
  doc.metrics = [];
  doc.timeline = [];
  doc.actions = [
    { id: 'food_show_all', label: '全部', prompt: 'food_show_all', variant: 'activated', kind: 'client' },
    { id: 'food_filter_1km', label: '1公里内', prompt: 'food_filter_1km', variant: 'secondary', kind: 'client' },
    { id: 'food_show_more', label: '展示更多', prompt: 'food_show_more', variant: 'secondary', kind: 'client' }
  ];
  doc.blocks = [{
    id: 'food-0',
    kind: 'food-result',
    title: '三津汤包 (深圳北站店)',
    subtitle: '餐饮服务; 餐饮相关场所; 餐饮相关',
    status: 'ready',
    source: '高德 / 腾讯地图',
    metrics: [
      { label: 'category', value: '餐饮服务; 餐饮相关场所; 餐饮相关' },
      { label: 'address', value: '民治街道深圳北站（深圳北站地铁D口旁）' },
      { label: 'distance', value: '21米' },
      { label: 'location', value: '114.029506,22.609878' },
      { label: 'source', value: '高德 / 腾讯地图' }
    ],
    rows: [],
    actions: [
      { id: 'html_pin_food', label: '固定到桌面', prompt: '{"index":0,"name":"三津汤包 (深圳北站店)","address":"民治街道深圳北站（深圳北站地铁D口旁）","location":"114.029506,22.609878","distance":"21米"}', variant: 'secondary', kind: 'client' },
      { id: 'html_open_food_map', label: '导航去', prompt: '{"index":0,"name":"三津汤包 (深圳北站店)","address":"民治街道深圳北站（深圳北站地铁D口旁）","location":"114.029506,22.609878","distance":"21米"}', variant: 'secondary', kind: 'client' }
    ]
  }, {
    id: 'food-1',
    kind: 'food-result',
    title: 'N多寿司 (深圳北站店)',
    subtitle: '餐饮服务; 快餐厅; 快餐厅',
    status: 'ready',
    source: '高德',
    metrics: [
      { label: 'category', value: '餐饮服务; 快餐厅; 快餐厅' },
      { label: 'address', value: '民治街道北站社区深圳北站综合交通枢纽东广场C1栋102号' },
      { label: 'distance', value: '0米' },
      { label: 'location', value: '114.029506,22.609878' },
      { label: 'source', value: '高德' }
    ],
    rows: [],
    actions: [
      { id: 'html_pin_food', label: '固定到桌面', prompt: '{"index":1,"name":"N多寿司 (深圳北站店)","address":"民治街道北站社区深圳北站综合交通枢纽东广场C1栋102号","location":"114.029506,22.609878","distance":"0米"}', variant: 'secondary', kind: 'client' },
      { id: 'html_open_food_map', label: '导航去', prompt: '{"index":1,"name":"N多寿司 (深圳北站店)","address":"民治街道北站社区深圳北站综合交通枢纽东广场C1栋102号","location":"114.029506,22.609878","distance":"0米"}', variant: 'secondary', kind: 'client' }
    ]
  }, {
    id: 'food-2',
    kind: 'food-result',
    title: '麦当劳 (深圳北站店)',
    subtitle: '麦当劳门店',
    status: 'ready',
    source: '麦当劳',
    metrics: [
      { label: 'category', value: '麦当劳门店' },
      { label: 'address', value: '深圳北站商业区' },
      { label: 'distance', value: '180米' },
      { label: 'location', value: '114.030000,22.610000' },
      { label: 'source', value: '麦当劳' }
    ],
    rows: [],
    actions: [
      { id: 'html_pin_food', label: '固定到桌面', prompt: '{"index":2,"name":"麦当劳 (深圳北站店)","address":"深圳北站商业区","location":"114.030000,22.610000","distance":"180米"}', variant: 'secondary', kind: 'client' },
      { id: 'html_open_food_map', label: '导航去', prompt: '{"index":2,"name":"麦当劳 (深圳北站店)","address":"深圳北站商业区","location":"114.030000,22.610000","distance":"180米"}', variant: 'secondary', kind: 'client' }
    ]
  }, {
    id: 'food-3',
    kind: 'food-result',
    title: '未知坐标小吃档',
    subtitle: 'provider 未返回坐标',
    status: 'ready',
    source: '美团',
    metrics: [
      { label: 'category', value: '小吃' },
      { label: 'address', value: '坂田街道附近' },
      { label: 'distance', value: '900米' },
      { label: 'location', value: '' },
      { label: 'source', value: '美团' }
    ],
    rows: [],
    actions: [
      { id: 'html_pin_food', label: '固定到桌面', prompt: '{"index":3,"name":"未知坐标小吃档","address":"坂田街道附近","location":"","distance":"900米"}', variant: 'secondary', kind: 'client' },
      { id: 'html_open_food_map', label: '导航去', prompt: '{"index":3,"name":"未知坐标小吃档","address":"坂田街道附近","location":"","distance":"900米"}', variant: 'secondary', kind: 'client' }
    ]
  }];
  doc.history = [];
  return doc;
}

function googleMapsDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'generic';
  doc.title = 'Google Maps 搜索结果';
  doc.subtitle = 'Google Places API 返回的真实地点';
  doc.blocks = [{
    id: 'maps-0',
    kind: 'generic-tool-result',
    title: 'Coffee Lab',
    subtitle: 'Google Places result for: 深圳咖啡',
    status: 'success',
    source: 'Google Places API',
    metrics: [
      { label: 'source', value: 'Google Places API' },
      { label: 'toolName', value: 'maps.place.search' }
    ],
    rows: [
      { label: 'Place ID', value: 'place-123' },
      { label: 'Address', value: '深圳市龙岗区坂田' },
      { label: 'Map Location', value: '22.609878,114.029506' },
      { label: 'Maps URL', value: 'https://maps.google.com/?cid=123' }
    ],
    actions: [
      { id: 'maps.open.web', label: '打开 Google Maps', prompt: 'https://maps.google.com/?cid=123', variant: 'secondary', kind: 'client' }
    ]
  }];
  doc.actions = [];
  return doc;
}

function calendarSearchDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'dynamic-tools';
  doc.title = '明日 Google Calendar';
  doc.subtitle = 'Google Calendar API 查询成功。';
  doc.blocks = [{
    id: 'calendar-search-0',
    kind: 'generic-tool-result',
    title: '产品同步',
    subtitle: 'Google Calendar API 查询成功。',
    status: 'success',
    source: 'Google Calendar API',
    metrics: [
      { label: 'source', value: 'Google Calendar API' },
      { label: 'toolName', value: 'calendar.events.search' }
    ],
    rows: [
      { label: 'Event ID', value: 'event-1' },
      { label: 'Start', value: '2026-07-02T10:00:00+08:00' },
      { label: 'End', value: '2026-07-02T10:30:00+08:00' },
      { label: 'Link', value: 'https://calendar.google.com/calendar/event?eid=event-1' }
    ],
    actions: []
  }];
  doc.actions = [];
  doc.history = [];
  return doc;
}

function calendarEmptySearchDocumentFixture(): HtmlHomeDocument {
  const doc = calendarSearchDocumentFixture();
  doc.title = '明日 Google Calendar';
  doc.subtitle = 'Google Calendar API 查询成功，但没有可展示事件。';
  doc.blocks[0].title = '没有找到日程';
  doc.blocks[0].subtitle = 'Google Calendar API 查询成功，但没有可展示事件。';
  doc.blocks[0].rows = [
    { label: 'Window Start', value: '2026-07-02T00:00:00+08:00' },
    { label: 'Window End', value: '2026-07-03T00:00:00+08:00' }
  ];
  return doc;
}

function calendarCreateDocumentFixture(): HtmlHomeDocument {
  const doc = calendarSearchDocumentFixture();
  doc.title = '已创建一对一会议';
  doc.subtitle = '已直接写入真实 Google Calendar。';
  doc.blocks[0].title = '一对一会议';
  doc.blocks[0].subtitle = '已直接写入真实 Google Calendar。';
  doc.blocks[0].metrics = [
    { label: 'source', value: 'Google Calendar API' },
    { label: 'toolName', value: 'calendar.event.create' }
  ];
  doc.blocks[0].rows = [
    { label: 'Event ID', value: 'event-create-1' },
    { label: 'Start', value: '2026-07-02T16:30:00+08:00' },
    { label: 'End', value: '2026-07-02T17:00:00+08:00' },
    { label: 'Link', value: 'https://calendar.google.com/calendar/event?eid=event-create-1' }
  ];
  return doc;
}

function mailAggregateDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'gmail';
  doc.title = '邮箱';
  doc.subtitle = '聚合展示 Gmail 和 QQ 邮箱';
  doc.blocks = [{
    id: 'gmail-1',
    kind: 'generic-tool-result',
    title: 'Gmail message',
    subtitle: 'Gmail thread retrieved.',
    status: 'success',
    source: 'Gmail',
    metrics: [
      { label: 'source', value: 'Gmail' },
      { label: 'toolName', value: 'mail.thread' }
    ],
    rows: [
      { label: 'Provider', value: 'gmail' },
      { label: 'Thread ID', value: 'gmail-thread' }
    ],
    actions: []
  }, {
    id: 'qq-1',
    kind: 'generic-tool-result',
    title: 'QQ message',
    subtitle: 'QQ Mail thread retrieved.',
    status: 'success',
    source: 'QQ Mail',
    metrics: [
      { label: 'source', value: 'QQ Mail' },
      { label: 'toolName', value: 'mail.thread' }
    ],
    rows: [
      { label: 'Provider', value: 'qq' },
      { label: 'Thread ID', value: 'qq-thread' }
    ],
    actions: []
  }];
  doc.actions = [];
  return doc;
}

function socialDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'social';
  doc.title = '微信消息';
  doc.subtitle = '来自通知捕获的真实消息';
  doc.blocks = [{
    id: 'wechat-1',
    kind: 'social-message',
    title: 'Alice',
    subtitle: '晚上一起吃饭吗',
    status: 'unread',
    source: 'notification',
    metrics: [
      { label: 'platform', value: 'wechat' },
      { label: 'sender', value: 'Alice' }
    ],
    rows: [
      { label: 'receivedAt', value: '2026-06-11T08:30:00.000Z' }
    ],
    actions: [
      { id: 'social_select_message', label: '选择消息', prompt: 'wechat-1', variant: 'secondary', kind: 'client' }
    ]
  }];
  doc.actions = [];
  doc.history = [];
  return doc;
}

function mediaAggregateDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'media';
  doc.title = 'Qwen Max 官方视频';
  doc.subtitle = '聚合展示 YouTube 和 Bilibili';
  doc.blocks = [{
    id: 'youtube-1',
    kind: 'generic-tool-result',
    title: 'YouTube video',
    subtitle: 'YouTube result.',
    status: 'success',
    source: 'YouTube Data API',
    metrics: [
      { label: 'source', value: 'YouTube Data API' },
      { label: 'toolName', value: 'media.video.search' }
    ],
    rows: [
      { label: 'Video ID', value: 'abc123' },
      { label: 'Watch URL', value: 'https://www.youtube.com/watch?v=abc123' }
    ],
    actions: [{
      id: 'media.open.web',
      label: '打开网页',
      prompt: 'https://www.youtube.com/watch?v=abc123',
      variant: 'primary',
      kind: 'client'
    }],
    mediaEmbed: {
      provider: 'YouTube',
      title: 'YouTube video',
      embedUrl: 'https://www.youtube.com/embed/abc123?playsinline=1&rel=0&enablejsapi=1&origin=https%3A%2F%2Faiphone.local',
      pageUrl: 'https://www.youtube.com/watch?v=abc123',
      thumbnail: 'https://i.ytimg.com/vi/abc123/mqdefault.jpg'
    }
  }, {
    id: 'bilibili-1',
    kind: 'generic-tool-result',
    title: 'Bilibili video',
    subtitle: 'Bilibili result.',
    status: 'success',
    source: '哔哩哔哩',
    metrics: [
      { label: 'source', value: '哔哩哔哩' },
      { label: 'toolName', value: 'media.video.search' }
    ],
    rows: [
      { label: 'BVID', value: 'BV1h57y6pE5o' },
      { label: 'Playback URL', value: 'https://www.bilibili.com/video/BV1h57y6pE5o' }
    ],
    actions: [{
      id: 'media.open.web',
      label: '打开网页',
      prompt: 'https://www.bilibili.com/video/BV1h57y6pE5o',
      variant: 'primary',
      kind: 'client'
    }],
    mediaEmbed: {
      provider: 'Bilibili',
      title: 'Bilibili video',
      embedUrl: 'https://player.bilibili.com/player.html?bvid=BV1h57y6pE5o&p=1&autoplay=0&poster=true&danmaku=0&isOutside=true',
      pageUrl: 'https://www.bilibili.com/video/BV1h57y6pE5o',
      thumbnail: 'https://i1.hdslb.com/bfs/archive/cover.jpg'
    }
  }];
  doc.actions = [];
  return doc;
}

function socialHubDocumentFixture(): HtmlHomeDocument {
  const doc = documentFixture();
  doc.kind = 'social';
  doc.title = '社交工作台';
  doc.subtitle = 'X, Slack, WeCom';
  doc.blocks = [{
    id: 'social_hub-item-0',
    kind: 'social-hub-item',
    title: '@openai',
    subtitle: 'Hello from X',
    status: 'unread',
    source: 'x',
    metrics: [
      { label: 'platform', value: 'x' },
      { label: 'kind', value: 'post' },
      { label: 'time', value: '2026-07-01T01:00:00.000Z' }
    ],
    rows: [
      { label: 'text', value: 'Hello from X' },
      { label: 'url', value: 'https://x.com/openai/status/1' }
    ],
    actions: [
      { id: 'social_hub_select_item', label: '查看', prompt: 'x-1', variant: 'secondary', kind: 'client' },
      { id: 'social_hub_draft_reply', label: '生成草稿', prompt: 'x-1', variant: 'secondary', kind: 'client' },
      { id: 'social_hub_open_source', label: '打开原文', prompt: 'https://x.com/openai/status/1', variant: 'secondary', kind: 'client' }
    ]
  }, {
    id: 'social_hub-connection-0',
    kind: 'social-hub-connection',
    title: 'Slack',
    subtitle: 'Slack token required',
    status: 'needs_auth',
    source: 'slack',
    metrics: [{ label: 'platform', value: 'slack' }],
    rows: [{ label: 'message', value: 'Slack token required' }],
    actions: []
  }, {
    id: 'social_hub-draft',
    kind: 'social-hub-draft',
    title: '回复草稿',
    subtitle: 'local draft only; not sent',
    status: 'error',
    source: 'x',
    metrics: [{ label: 'platform', value: 'x' }],
    rows: [
      { label: 'text', value: 'Thanks for the update' },
      { label: 'error', value: 'local draft only; not sent' },
      { label: 'localOnly', value: 'true' },
      { label: 'sent', value: 'false' }
    ],
    actions: []
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

      expect(html.indexOf('data-scene="dynamic-tools"')).assertEqual(-1);
      expect(html.indexOf('Tool Console')).assertEqual(-1);
      expect(html.indexOf('tool-hero')).assertEqual(-1);
      expect(html.indexOf('tool-console')).assertEqual(-1);
      expect(html.indexOf('media-shell')).assertEqual(-1);
      expect(html.indexOf('任务结果')).assertLarger(-1);
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

      expect(html.indexOf('itinerary-shell')).assertLarger(-1);
      expect(html.indexOf('route-hero')).assertLarger(-1);
      expect(html.indexOf('route-map')).assertLarger(-1);
      expect(html.indexOf('font-family: Georgia')).assertLarger(-1);
      expect(html.indexOf('route-kicker::before')).assertLarger(-1);
      expect(html.indexOf('journey-tag.train::before')).assertLarger(-1);
      expect(html.indexOf("journey-tag ' + source")).assertLarger(-1);
      expect(html.indexOf('travel-controls')).assertLarger(-1);
      expect(html.indexOf('journey-board')).assertLarger(-1);
      expect(html.indexOf('journey-card')).assertLarger(-1);
      expect(html.indexOf('出行方案 · 实时候选')).assertLarger(-1);
      expect(html.indexOf('G123')).assertLarger(-1);
      expect(html.indexOf('麦当劳 科技园店')).assertLarger(-1);
      expect(html.indexOf('html_pin_travel')).assertLarger(-1);
      expect(html.indexOf('html_open_food_map')).assertLarger(-1);
      expect(html.indexOf('AIPhoneHome.postAction')).assertLarger(-1);
      expect(html.indexOf('travel_filter_train')).assertLarger(-1);
      expect(html.indexOf('travel_filter_flight')).assertLarger(-1);
      expect(html.indexOf('client_sort_fastest')).assertLarger(-1);
      expect(html.indexOf('client_filter_available')).assertLarger(-1);
      expect(html.indexOf('client_show_more')).assertLarger(-1);
      expect(html.indexOf("state.trainShowMore = !state.trainShowMore")).assertLarger(-1);
      expect(html.indexOf('data-source="train"')).assertLarger(-1);
      expect(html.indexOf('data-source="food"')).assertLarger(-1);
      expect(html.indexOf('data-duration')).assertLarger(-1);
      expect(html.indexOf('data-availability')).assertLarger(-1);
      expect(html.indexOf('classList.toggle')).assertLarger(-1);
      expect(html.indexOf('expandedKey')).assertLarger(-1);
      expect(html.indexOf('querySelectorAll')).assertLarger(-1);
      expect(html.indexOf('.journey-card:not(.expanded) .journey-detail')).assertLarger(-1);
      expect(html.indexOf("button.textContent = expanded ? '收起' : '展开'")).assertLarger(-1);
      expect(html.indexOf("add(top, 'button', 'journey-expand', '展开')")).assertLarger(-1);
      expect(html.indexOf("add(statusWrap, 'button', 'expand-button', '详情')")).assertEqual(-1);
      expect(html.indexOf('detailRow(grid')).assertLarger(-1);
      expect(html.indexOf('function labelText(label)')).assertLarger(-1);
      expect(html.indexOf("if (raw === 'source') { return '来源'; }")).assertLarger(-1);
      expect(html.indexOf('event.stopPropagation()')).assertLarger(-1);
      expect(html.indexOf('sourceKind')).assertLarger(-1);
      expect(html.indexOf('Food Field')).assertEqual(-1);
      expect(html.indexOf('附近餐饮探索')).assertEqual(-1);
      expect(html.indexOf('ReactDOM')).assertEqual(-1);
    });

    it('renders food documents with the food scene template and preserves actions', 0, () => {
      const html = renderHtmlHomeDocument(foodDocumentFixture());

      expect(html.indexOf('editorial-food-shell')).assertLarger(-1);
      expect(html.indexOf('editorial-cover')).assertLarger(-1);
      expect(html.indexOf('editorial-tabs')).assertLarger(-1);
      expect(html.indexOf('editorial-feature')).assertLarger(-1);
      expect(html.indexOf('photo-1552566626-52f8b828add9')).assertLarger(-1);
      expect(html.indexOf('editorial-list')).assertLarger(-1);
      expect(html.indexOf('merchant-avatar')).assertLarger(-1);
      expect(html.indexOf('merchant-avatar-fallback')).assertLarger(-1);
      expect(html.indexOf('AVATAR_MCDONALDS')).assertLarger(-1);
      expect(html.indexOf('AVATAR_KFC')).assertLarger(-1);
      expect(html.indexOf('AVATAR_TAOBAO')).assertLarger(-1);
      expect(html.indexOf('AVATAR_AMAP')).assertLarger(-1);
      expect(html.indexOf('AVATAR_TENCENT')).assertLarger(-1);
      expect(html.indexOf('AVATAR_BAIDU')).assertLarger(-1);
      expect(html.indexOf('AVATAR_MEITUAN')).assertLarger(-1);
      expect(html.indexOf('AVATAR_LUCKIN')).assertLarger(-1);
      expect(html.indexOf('AVATAR_GOOGLE_MAPS')).assertLarger(-1);
      expect(html.indexOf('AVATAR_LOCAL')).assertLarger(-1);
      expect(html.indexOf('function addAvatar(parent, block)')).assertLarger(-1);
      expect(html.indexOf('addAvatar(head, block)')).assertLarger(-1);
      expect(html.indexOf('border-radius: 999px')).assertLarger(-1);
      expect(html.indexOf('今日附近值得吃')).assertLarger(-1);
      expect(html.indexOf('附近餐饮 · 今日编辑')).assertLarger(-1);
      expect(html.indexOf('今日编辑')).assertLarger(-1);
      expect(html.indexOf('高德 / 腾讯地图')).assertLarger(-1);
      expect(html.indexOf('三津汤包 (深圳北站店)')).assertLarger(-1);
      expect(html.indexOf('N多寿司 (深圳北站店)')).assertLarger(-1);
      expect(html.indexOf('麦当劳 (深圳北站店)')).assertLarger(-1);
      expect(html.indexOf('未知坐标小吃档')).assertLarger(-1);
      expect(html.indexOf('data-source-key="food-amap"')).assertLarger(-1);
      expect(html.indexOf('data-source-key="food-local"')).assertLarger(-1);
      expect(html.indexOf('data-source-key="food-meituan"')).assertLarger(-1);
      expect(html.indexOf('data-source-key="food-taobao"')).assertLarger(-1);
      expect(html.indexOf('data-source-key="food-mcd"')).assertLarger(-1);
      expect(html.indexOf('data-source-key="food-luckin"')).assertLarger(-1);
      expect(html.indexOf('food-google-maps')).assertLarger(-1);
      expect(html.indexOf('html_open_food_map')).assertLarger(-1);
      expect(html.indexOf('html_pin_food')).assertLarger(-1);
      expect(html.indexOf('导航去')).assertLarger(-1);
      expect(html.indexOf('固定到桌面')).assertLarger(-1);
      expect(html.indexOf('AIPhoneHome.postAction')).assertLarger(-1);
      expect(html.indexOf('food_filter_1km')).assertLarger(-1);
      expect(html.indexOf("if (id === 'food_filter_1km')")).assertLarger(-1);
      expect(html.indexOf("state.filter = 'within_1km'")).assertLarger(-1);
      expect(html.indexOf("if (id === 'food_filter_1km') { state.filter = 'within_1km'; applyFilter(); return true; }")).assertLarger(-1);
      expect(html.indexOf("if (feature) { feature.style.display = matchesFilter(feature) ? '' : 'none'; }")).assertLarger(-1);
      expect(html.indexOf("feature.setAttribute('data-search'")).assertLarger(-1);
      expect(html.indexOf('food_show_more')).assertLarger(-1);
      expect(html.indexOf('function sourceParts(block)')).assertLarger(-1);
      expect(html.indexOf("card.setAttribute('data-source-key', sourceKey(block))")).assertLarger(-1);
      expect(html.indexOf("raw.indexOf('美团')")).assertLarger(-1);
      expect(html.indexOf("raw.indexOf('麦当劳')")).assertLarger(-1);
      expect(html.indexOf("id === 'html_open_food_map' ? '导航去' : '固定到桌面'")).assertLarger(-1);
      expect(html.indexOf('var canNavigate = hasLocation(block)')).assertLarger(-1);
      expect(html.indexOf('if (!canNavigate) { return false; }')).assertLarger(-1);
      expect(html.indexOf('setExpanded(key)')).assertLarger(-1);
      expect(html.indexOf('Food Field')).assertEqual(-1);
      expect(html.indexOf('附近餐饮探索')).assertEqual(-1);
      expect(html.indexOf('window.AMap')).assertEqual(-1);
      expect(html.indexOf('webapi.amap.com')).assertEqual(-1);
      expect(html.indexOf('ReactDOM')).assertEqual(-1);
    });

    it('keeps non-food documents on the generic renderer', 0, () => {
      const html = renderHtmlHomeDocument(documentFixture());

      expect(html.indexOf('food-scene-shell')).assertEqual(-1);
      expect(html.indexOf('data-scene="generic"')).assertEqual(-1);
      expect(html.indexOf('result-hero')).assertEqual(-1);
      expect(html.indexOf('result-canvas')).assertEqual(-1);
      expect(html.indexOf('calendar-shell')).assertEqual(-1);
      expect(html.indexOf('任务结果')).assertLarger(-1);
      expect(html.indexOf('Project Brief')).assertLarger(-1);
    });

    it('renders Google Maps result blocks with an in-app map preview', 0, () => {
      const html = renderHtmlHomeDocument(googleMapsDocumentFixture());

      expect(html.indexOf('google-map-preview')).assertLarger(-1);
      expect(html.indexOf("text(block && block.kind) === 'generic-tool-result' && text(block && block.source).length > 0")).assertLarger(-1);
      expect(html.indexOf("url + (url.indexOf('?') >= 0 ? '&' : '?') + 'output=embed'")).assertLarger(-1);
      expect(html.indexOf('22.609878,114.029506')).assertLarger(-1);
      expect(html.indexOf('maps.open.web')).assertLarger(-1);
      expect(html.indexOf('打开 Google Maps')).assertLarger(-1);
      expect(html.indexOf('calendar-shell')).assertEqual(-1);
    });

    it('renders Google Calendar search results as a day week month workspace', 0, () => {
      const html = renderHtmlHomeDocument(calendarSearchDocumentFixture());

      expect(html.indexOf('calendar-shell')).assertLarger(-1);
      expect(html.indexOf('calendar-view-day')).assertLarger(-1);
      expect(html.indexOf('calendar-view-week')).assertLarger(-1);
      expect(html.indexOf('calendar-view-month')).assertLarger(-1);
      expect(html.indexOf('data-calendar-view="day"')).assertLarger(-1);
      expect(html.indexOf('Google Calendar API')).assertLarger(-1);
      expect(html.indexOf('产品同步')).assertLarger(-1);
      expect(html.indexOf('10:00')).assertLarger(-1);
      expect(html.indexOf('任务结果')).assertEqual(-1);
    });

    it('uses the requested Google Calendar search window for empty results', 0, () => {
      const html = renderHtmlHomeDocument(calendarEmptySearchDocumentFixture());

      expect(html.indexOf('7月2日 周四')).assertLarger(-1);
      expect(html.indexOf('无定时日程')).assertLarger(-1);
      expect(html.indexOf('这个时间窗没有可放入时间轴的日程')).assertLarger(-1);
      expect(html.indexOf('6月25日')).assertEqual(-1);
    });

    it('renders Google Calendar create results as a write confirmation', 0, () => {
      const html = renderHtmlHomeDocument(calendarCreateDocumentFixture());

      expect(html.indexOf('calendar-confirmation')).assertLarger(-1);
      expect(html.indexOf('一对一会议')).assertLarger(-1);
      expect(html.indexOf('16:30')).assertLarger(-1);
      expect(html.indexOf('17:00')).assertLarger(-1);
      expect(html.indexOf('已写入')).assertLarger(-1);
    });

    it('renders Gmail and QQ mail sources with app icons and separate card frames', 0, () => {
      const html = renderHtmlHomeDocument(mailAggregateDocumentFixture());

      expect(html.indexOf('data-scene="gmail"')).assertLarger(-1);
      expect(html.indexOf('Mail Deck')).assertLarger(-1);
      expect(html.indexOf('gmail-hero')).assertLarger(-1);
      expect(html.indexOf('mail-hero-icon')).assertLarger(-1);
      expect(html.indexOf('mail-rail')).assertLarger(-1);
      expect(html.indexOf('mail_filter_gmail')).assertLarger(-1);
      expect(html.indexOf('mail_filter_qq')).assertLarger(-1);
      expect(html.indexOf('data-mail-filter')).assertLarger(-1);
      expect(html.indexOf('星标')).assertEqual(-1);
      expect(html.indexOf('草稿</button>')).assertEqual(-1);
      expect(html.indexOf('Gmail message')).assertLarger(-1);
      expect(html.indexOf('QQ message')).assertLarger(-1);
      expect(html.indexOf('MAIL_ICON_GMAIL')).assertLarger(-1);
      expect(html.indexOf('MAIL_ICON_QQ')).assertLarger(-1);
      expect(html.indexOf('mail-source-icon')).assertLarger(-1);
      expect(html.indexOf("if (key === 'mail-gmail')")).assertLarger(-1);
      expect(html.indexOf("if (key === 'mail-qq')")).assertLarger(-1);
      expect(html.indexOf(".block[data-source-key=\"mail-gmail\"]")).assertLarger(-1);
      expect(html.indexOf(".block[data-source-key=\"mail-qq\"]")).assertLarger(-1);
      expect(html.indexOf('border-color: rgba(194, 70, 54, 0.45)')).assertLarger(-1);
      expect(html.indexOf('border-color: rgba(45, 120, 196, 0.45)')).assertLarger(-1);
    });

    it('keeps social documents on the legacy frame with actions intact', 0, () => {
      const html = renderHtmlHomeDocument(socialDocumentFixture());

      expect(html.indexOf('data-scene="social"')).assertEqual(-1);
      expect(html.indexOf('social-hero')).assertEqual(-1);
      expect(html.indexOf('chat-bubble')).assertEqual(-1);
      expect(html.indexOf('任务结果')).assertLarger(-1);
      expect(html.indexOf('social_select_message')).assertLarger(-1);
    });

    it('renders media sources with app icons and unified playable card frames', 0, () => {
      const html = renderHtmlHomeDocument(mediaAggregateDocumentFixture());

      expect(html.indexOf('media-shell')).assertLarger(-1);
      expect(html.indexOf('media-hero')).assertLarger(-1);
      expect(html.indexOf('media-source-rail')).assertLarger(-1);
      expect(html.indexOf('media-stage')).assertEqual(-1);
      expect(html.indexOf('media-provider-grid')).assertLarger(-1);
      expect(html.indexOf('media-inspector')).assertEqual(-1);
      expect(html.indexOf('media-source-summary')).assertEqual(-1);
      expect(html.indexOf('media-source-facts')).assertEqual(-1);
      expect(html.indexOf('media-theater')).assertEqual(-1);
      expect(html.indexOf('media-cover-wall')).assertEqual(-1);
      expect(html.indexOf('media-hero-frame')).assertEqual(-1);
      expect(html.indexOf('media-hero-art')).assertEqual(-1);
      expect(html.indexOf('media-hero-stats')).assertLarger(-1);
      expect(html.indexOf('media-card-player')).assertLarger(-1);
      expect(html.indexOf('media-card-title-row')).assertLarger(-1);
      expect(html.indexOf('media-card-detail')).assertLarger(-1);
      expect(html.indexOf('media-thumb-shell')).assertEqual(-1);
      expect(html.indexOf('media-inline-player')).assertEqual(-1);
      expect(html.indexOf('media-inline-mount')).assertEqual(-1);
      expect(html.indexOf('media-logo-mark')).assertLarger(-1);
      expect(html.indexOf('Qwen Max 官方视频')).assertLarger(-1);
      expect(html.indexOf('YouTube video')).assertLarger(-1);
      expect(html.indexOf('Bilibili video')).assertLarger(-1);
      expect(html.indexOf('data-source-key="media-youtube"')).assertLarger(-1);
      expect(html.indexOf('data-source-key="media-bilibili"')).assertLarger(-1);
      expect(html.indexOf('https://upload.wikimedia.org/wikipedia/commons/e/ef/Youtube_logo.png')).assertLarger(-1);
      expect(html.indexOf('data:image/svg+xml;charset=utf-8,%3Csvg')).assertLarger(-1);
      expect(html.indexOf('%3Ebilibili%3C/text%3E')).assertLarger(-1);
      expect(html.indexOf('data-filter="youtube"')).assertLarger(-1);
      expect(html.indexOf('data-filter="bilibili"')).assertLarger(-1);
      expect(html.indexOf('data-filter="playable"')).assertEqual(-1);
      expect(html.indexOf('data-mode')).assertEqual(-1);
      expect(html.indexOf('data-filter="error"')).assertLarger(-1);
      expect(html.indexOf('B 站')).assertLarger(-1);
      expect(html.indexOf('media.open.web')).assertLarger(-1);
      expect(html.indexOf("var play = add(actions")).assertEqual(-1);
      expect(html.indexOf("var detail = add(actions")).assertEqual(-1);
      expect(html.indexOf("add(heroCaption, 'span'")).assertEqual(-1);
      expect(html.indexOf('aria-expanded')).assertLarger(-1);
      expect(html.indexOf('data-broken')).assertLarger(-1);
      expect(html.indexOf('剧场')).assertEqual(-1);
      expect(html.indexOf('封面墙')).assertEqual(-1);
      expect(html.indexOf('置顶舞台')).assertEqual(-1);
      expect(html.indexOf('来源概览')).assertEqual(-1);
      expect(html.indexOf("iframe.setAttribute('referrerpolicy', 'origin-when-cross-origin')")).assertLarger(-1);
      expect(html.indexOf('https://i.ytimg.com/vi/abc123/mqdefault.jpg')).assertLarger(-1);
      expect(html.indexOf('https://i1.hdslb.com/bfs/archive/cover.jpg')).assertLarger(-1);
    });

    it('normalizes generic dynamic media titles in the H5 document', 0, () => {
      const doc = mediaAggregateDocumentFixture();
      doc.title = '动态工具结果';
      doc.subtitle = '帮我在b站和youtube里搜索qwen max 的官方视频';
      const html = renderHtmlHomeDocument(doc);

      expect(html.indexOf('<title>媒体搜索结果</title>')).assertLarger(-1);
      expect(html.indexOf('"title":"媒体搜索结果"')).assertLarger(-1);
      expect(html.indexOf('帮我在b站和youtube里搜索qwen max 的官方视频')).assertLarger(-1);
      expect(html.indexOf('"title":"动态工具结果"')).assertEqual(-1);
    });

    it('does not render mixed generic blocks as media cards', 0, () => {
      const doc = mediaAggregateDocumentFixture();
      doc.blocks.push({
        id: 'plain-generic',
        kind: 'generic-tool-result',
        title: 'Plain tool result',
        subtitle: 'Not a video result',
        status: 'success',
        source: 'Generic API',
        metrics: [
          { label: 'source', value: 'Generic API' },
          { label: 'toolName', value: 'generic.search' }
        ],
        rows: [
          { label: 'URL', value: 'https://example.com/plain' }
        ],
        actions: [{
          id: 'generic.open',
          label: '打开',
          prompt: 'https://example.com/plain',
          variant: 'secondary',
          kind: 'client'
        }]
      });
      const html = renderHtmlHomeDocument(doc);

      expect(html.indexOf('media-shell')).assertLarger(-1);
      expect(html.indexOf('Plain tool result')).assertEqual(-1);
      expect(html.indexOf('generic.open')).assertEqual(-1);
    });

    it('renders SocialHub blocks with actions and platform styles', 0, () => {
      const html = renderHtmlHomeDocument(socialHubDocumentFixture());

      expect(html.indexOf('data-scene="social"')).assertLarger(-1);
      expect(html.indexOf('Hello from X')).assertLarger(-1);
      expect(html.indexOf('Slack token required')).assertLarger(-1);
      expect(html.indexOf('Thanks for the update')).assertLarger(-1);
      expect(html.indexOf('social_hub_draft_reply')).assertLarger(-1);
      expect(html.indexOf('social_hub_open_source')).assertLarger(-1);
      expect(html.indexOf('data-kind="social-hub-item"')).assertLarger(-1);
      expect(html.indexOf('social-x')).assertLarger(-1);
      expect(html.indexOf('social-slack')).assertLarger(-1);
      expect(html.indexOf('social_select_message')).assertEqual(-1);
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

      expect(html.indexOf('data-scene="welcome"')).assertEqual(-1);
      expect(html.indexOf('status-hero')).assertEqual(-1);
      expect(html.indexOf('场景')).assertEqual(-1);
      expect(html.indexOf('来源')).assertEqual(-1);
      expect(html.indexOf('待命')).assertEqual(-1);
    });
  });
}
