import { HtmlHomeDocument } from './HtmlHomeTypes';

type HtmlHomeTextValue = Object | string | number | boolean | null | undefined;

interface HtmlHomeDocumentWithBusy extends HtmlHomeDocument {
  isBusy?: boolean;
}

const HTML_HOME_CSS: string = `
:root {
  color-scheme: light;
  --paper: #f5f2ee;
  --paper-deep: #ebe5dc;
  --panel: rgba(255, 255, 255, 0.86);
  --panel-strong: #ffffff;
  --ink: #211b17;
  --ink-soft: #493f38;
  --muted: #786e66;
  --line: rgba(33, 27, 23, 0.12);
  --accent: #995f4c;
  --accent-soft: rgba(153, 95, 76, 0.13);
  --red: #b04a42;
  --red-soft: rgba(176, 74, 66, 0.1);
  --amber: #9a6a22;
  --shadow: 0 14px 34px rgba(44, 34, 26, 0.08);
  --train: #397a55;
  --train-soft: rgba(57, 122, 85, 0.12);
  --flight: #476f9f;
  --flight-soft: rgba(71, 111, 159, 0.12);
  --amap: #2f8f5f;
  --amap-soft: rgba(47, 143, 95, 0.12);
  --tencent: #2d78a8;
  --tencent-soft: rgba(45, 120, 168, 0.12);
  --baidu: #b34f66;
  --baidu-soft: rgba(179, 79, 102, 0.12);
  --meituan: #a77816;
  --meituan-soft: rgba(167, 120, 22, 0.14);
  --taobao: #7a5bb5;
  --taobao-soft: rgba(122, 91, 181, 0.12);
  --mcd: #b57915;
  --mcd-soft: rgba(181, 121, 21, 0.14);
  --luckin: #466eb8;
  --luckin-soft: rgba(70, 110, 184, 0.12);
}
* { box-sizing: border-box; }
body {
  margin: 0;
  min-height: 100vh;
  background:
    linear-gradient(180deg, rgba(255,255,255,0.72) 0%, rgba(255,255,255,0) 45%),
    var(--paper);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", "Helvetica Neue", Arial, sans-serif;
  letter-spacing: 0;
  -webkit-font-smoothing: antialiased;
}
button { font: inherit; cursor: pointer; }
button:disabled {
  cursor: default;
  opacity: 0.5;
}
.shell {
  width: min(100%, 760px);
  margin: 0 auto;
  padding: 14px 14px calc(96px + env(safe-area-inset-bottom, 0px));
}
.hero {
  padding: 18px 2px 14px;
  border-bottom: 1px solid var(--line);
}
.eyebrow, .label, .meta {
  color: var(--muted);
  font-size: 11px;
  line-height: 1.35;
  letter-spacing: 0;
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
}
h1, h2, h3, p { margin: 0; }
h1 {
  margin-top: 8px;
  max-width: 12em;
  font-size: 27px;
  line-height: 1.08;
  font-weight: 760;
}
h2 {
  font-size: 16px;
  line-height: 1.25;
  font-weight: 760;
}
h3 {
  font-size: 17px;
  line-height: 1.24;
  font-weight: 760;
}
.subtitle {
  margin-top: 8px;
  color: var(--ink-soft);
  font-size: 14px;
  line-height: 1.55;
}
.chipbar {
  position: sticky;
  top: 0;
  z-index: 2;
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding: 10px 0 12px;
  background: rgba(245, 242, 238, 0.92);
  backdrop-filter: blur(12px);
}
.chip {
  flex: 0 0 auto;
  border: 1px solid var(--line);
  border-radius: 999px;
  padding: 8px 12px;
  background: var(--panel-strong);
  color: var(--ink-soft);
  font-size: 12px;
  line-height: 1;
  box-shadow: 0 2px 8px rgba(48, 34, 18, 0.05);
}
.metrics {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0 12px;
  margin-top: 12px;
}
.metric, .row {
  min-width: 0;
  border-top: 1px solid var(--line);
  padding: 8px 0;
  background: transparent;
}
.hero .metric {
  border: 1px solid var(--line);
  border-radius: 16px;
  padding: 9px 10px;
  background: var(--panel);
}
.value {
  margin-top: 4px;
  overflow-wrap: anywhere;
  font-size: 14px;
  line-height: 1.35;
  font-weight: 680;
}
.section {
  margin-top: 16px;
}
.section-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 10px;
  margin-bottom: 9px;
}
.block, .timeline-item, .empty, .history-item {
  border: 1px solid var(--line);
  border-radius: 16px;
  background: var(--panel);
  box-shadow: var(--shadow);
}
.block {
  --kind-accent: var(--accent);
  --kind-soft: var(--accent-soft);
  position: relative;
  overflow: hidden;
  padding: 12px 12px 13px;
  margin-top: 10px;
  border-color: var(--line);
}
.block:first-of-type { margin-top: 0; }
.block[data-kind="travel-option"],
.block[data-kind="train-option"] {
  --kind-accent: var(--train);
  --kind-soft: var(--train-soft);
}
.block[data-kind="flight-option"] {
  --kind-accent: var(--flight);
  --kind-soft: var(--flight-soft);
}
.block[data-kind="food-result"] {
  --kind-accent: var(--red);
  --kind-soft: var(--red-soft);
}
.block[data-source-key="travel-train"] {
  --kind-accent: var(--train);
  --kind-soft: var(--train-soft);
}
.block[data-source-key="travel-flight"] {
  --kind-accent: var(--flight);
  --kind-soft: var(--flight-soft);
}
.block[data-source-key="food-amap"] {
  --kind-accent: var(--amap);
  --kind-soft: var(--amap-soft);
}
.block[data-source-key="food-tencent"] {
  --kind-accent: var(--tencent);
  --kind-soft: var(--tencent-soft);
}
.block[data-source-key="food-baidu"] {
  --kind-accent: var(--baidu);
  --kind-soft: var(--baidu-soft);
}
.block[data-source-key="food-meituan"] {
  --kind-accent: var(--meituan);
  --kind-soft: var(--meituan-soft);
}
.block[data-source-key="food-taobao"] {
  --kind-accent: var(--taobao);
  --kind-soft: var(--taobao-soft);
}
.block[data-source-key="food-mcd"] {
  --kind-accent: var(--mcd);
  --kind-soft: var(--mcd-soft);
}
.block[data-source-key="food-luckin"] {
  --kind-accent: var(--luckin);
  --kind-soft: var(--luckin-soft);
}
.block[data-kind="dynamic-tool-connect"],
.block[data-kind="generic-tool-result"] {
  --kind-accent: var(--amber);
  --kind-soft: rgba(154, 100, 24, 0.12);
}
.block[data-kind="social-message"] {
  --kind-accent: #2f6f5e;
  --kind-soft: rgba(47, 111, 94, 0.12);
}
.block::before {
  content: "";
  position: absolute;
  inset: 0 auto 0 0;
  width: 4px;
  background: var(--kind-accent);
}
.block[data-expandable="true"] {
  cursor: pointer;
}
.block:not(.expanded) .details {
  display: none;
}
.details {
  margin-top: 10px;
  border-top: 1px solid var(--line);
  padding-top: 10px;
}
.expand-button {
  border: 1px solid var(--line);
  border-radius: 999px;
  flex: 0 0 auto;
  min-width: 58px;
  min-height: 34px;
  padding: 7px 12px;
  background: var(--kind-soft);
  color: var(--kind-accent);
  font-size: 13px;
  font-weight: 760;
  line-height: 1;
  white-space: nowrap;
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.58);
}
.block-top {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 12px;
}
.block-top > * {
  min-width: 0;
}
.block-title {
  flex: 1 1 auto;
}
h3, .subtitle, .kind-tag, .status, .action, .chip, .label, .meta {
  min-width: 0;
  overflow-wrap: anywhere;
}
.kind-tag {
  display: inline-flex;
  width: fit-content;
  margin-bottom: 7px;
  border-radius: 11px;
  padding: 4px 7px;
  background: var(--kind-soft);
  color: var(--kind-accent);
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 10px;
  line-height: 1;
}
.status {
  align-self: flex-start;
  max-width: min(42%, 180px);
  border-radius: 999px;
  padding: 6px 8px;
  background: var(--kind-soft);
  color: var(--kind-accent);
  font-size: 11px;
  line-height: 1.25;
  text-align: right;
  white-space: normal;
}
.rows {
  display: grid;
  gap: 7px;
  margin-top: 8px;
}
.timeline {
  border-left: 1px solid var(--line);
  margin-left: 7px;
  padding-left: 11px;
}
.timeline-item {
  position: relative;
  margin-top: 8px;
  padding: 10px 11px;
}
.timeline-item::before {
  content: "";
  position: absolute;
  left: -16px;
  top: 14px;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--accent);
}
.actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 12px;
}
.action {
  min-width: 0;
  border: 1px solid var(--line);
  border-radius: 999px;
  min-height: 40px;
  padding: 9px 13px;
  background: var(--accent);
  color: white;
  font-weight: 650;
  box-shadow: 0 8px 18px rgba(153, 95, 76, 0.14);
  overflow-wrap: anywhere;
  white-space: normal;
}
.action.secondary {
  background: var(--panel-strong);
  color: var(--kind-accent);
  box-shadow: none;
}
.credential {
  display: grid;
  gap: 8px;
  margin-top: 12px;
  border: 1px dashed rgba(15, 118, 110, 0.34);
  border-radius: 8px;
  padding: 10px;
  background: rgba(15, 118, 110, 0.08);
}
.credential input {
  width: 100%;
  border: 1px solid var(--line);
  border-radius: 8px;
  padding: 10px 11px;
  background: white;
  color: var(--ink);
  font: inherit;
}
.raw {
  margin: 10px 0 0;
  overflow: auto;
  border-radius: 12px;
  padding: 10px;
  background: rgba(24, 22, 20, 0.06);
  color: #332d28;
  font-size: 12px;
  line-height: 1.45;
  white-space: pre-wrap;
}
.empty {
  padding: 18px;
  color: var(--muted);
  line-height: 1.55;
  border-style: dashed;
  background: rgba(255, 250, 242, 0.62);
}
.filter-empty {
  display: none;
  margin-top: 10px;
}
.history-item {
  padding: 10px 11px;
  margin-top: 8px;
}
@media (min-width: 620px) {
  .shell { padding: 24px 22px calc(112px + env(safe-area-inset-bottom, 0px)); }
  h1 { font-size: 34px; }
  .metrics { grid-template-columns: repeat(3, minmax(0, 1fr)); }
}
`;

const HTML_HOME_JS: string = `
(function () {
  var dataNode = document.getElementById('home-data');
  var data = {};
  try {
    data = JSON.parse(dataNode && dataNode.textContent ? dataNode.textContent : '{}') || {};
  } catch (error) {
    data = {};
  }
  var app = document.getElementById('app');
  if (!app) { return; }
  var localState = { travel: 'all', food: 'all', trainFastest: false, trainAvailable: false, trainShowMore: false, expandedKey: '' };
  function text(value) {
    return value === undefined || value === null ? '' : String(value);
  }
  function list(value) {
    return Array.isArray(value) ? value : [];
  }
  var isBusy = text(data.isBusy).toLowerCase() === 'true';
  function kindLabel(value) {
    var kind = text(value);
    if (kind === 'welcome') { return '欢迎'; }
    if (kind === 'thinking') { return '执行中'; }
    if (kind === 'travel') { return '出行'; }
    if (kind === 'food') { return '附近餐饮'; }
    if (kind === 'social') { return '社交'; }
    if (kind === 'dynamic-tools') { return '动态工具'; }
    if (kind === 'gmail') { return 'Gmail'; }
    if (kind === 'generic') { return '通用任务'; }
    return kind;
  }
  function blockKindLabel(value) {
    var kind = text(value);
    if (kind === 'travel-option') { return '出行方案'; }
    if (kind === 'train-option') { return '高铁'; }
    if (kind === 'flight-option') { return '航班'; }
    if (kind === 'food-result') { return '餐饮'; }
    if (kind === 'dynamic-tool-connect') { return '授权'; }
    if (kind === 'generic-tool-result') { return '工具结果'; }
    if (kind === 'social-message') { return '消息'; }
    return kind;
  }
  function blockTagLabel(block) {
    if (text(block && block.kind) === 'food-result' && text(block && block.source).length > 0) {
      return text(block && block.source);
    }
    return blockKindLabel(block && block.kind);
  }
  function sourceKey(block) {
    var kind = text(block && block.kind).toLowerCase();
    if (kind === 'food-result' && text(block && block.source).indexOf(' / ') >= 0) {
      return 'food-local';
    }
    var raw = [
      text(block && block.source),
      metricValue(block, ['source', 'provider', 'sourceTag']),
      text(block && block.title),
      text(block && block.subtitle)
    ].join(' ').toLowerCase();
    if (kind === 'train-option' || raw.indexOf('12306') >= 0 || raw.indexOf('train') >= 0 || raw.indexOf('高铁') >= 0) {
      return 'travel-train';
    }
    if (kind === 'flight-option' || raw.indexOf('flight') >= 0 || raw.indexOf('飞常准') >= 0 || raw.indexOf('航班') >= 0) {
      return 'travel-flight';
    }
    if (raw.indexOf('amap') >= 0 || raw.indexOf('gaode') >= 0 || raw.indexOf('高德') >= 0) {
      return 'food-amap';
    }
    if (raw.indexOf('tencent') >= 0 || raw.indexOf('腾讯') >= 0) {
      return 'food-tencent';
    }
    if (raw.indexOf('baidu') >= 0 || raw.indexOf('百度') >= 0) {
      return 'food-baidu';
    }
    if (raw.indexOf('meituan') >= 0 || raw.indexOf('美团') >= 0) {
      return 'food-meituan';
    }
    if (raw.indexOf('taobao') >= 0 || raw.indexOf('淘宝') >= 0 || raw.indexOf('闪购') >= 0) {
      return 'food-taobao';
    }
    if (raw.indexOf('mcd') >= 0 || raw.indexOf('mcdonald') >= 0 || raw.indexOf('麦当劳') >= 0) {
      return 'food-mcd';
    }
    if (raw.indexOf('luckin') >= 0 || raw.indexOf('瑞幸') >= 0) {
      return 'food-luckin';
    }
    if (kind === 'food-result') {
      return 'food-local';
    }
    return kind || 'generic';
  }
	  function isExpandable(block) {
	    var kind = text(block && block.kind);
	    if (kind === 'generic-tool-result') {
	      return list(block && block.metrics).length > 0 ||
	        list(block && block.rows).length > 0 ||
	        list(block && block.actions).length > 0 ||
	        text(block && block.rawPreview).length > 0;
	    }
	    return kind === 'travel-option' || kind === 'train-option' || kind === 'flight-option' || kind === 'food-result';
	  }
  function updateExpandLabel(card) {
    var button = card.querySelector('.expand-button');
    if (!button) { return; }
    var expanded = card.classList.contains('expanded');
    button.textContent = expanded ? '收起' : '展开';
    card.setAttribute('aria-expanded', expanded ? 'true' : 'false');
  }
  function setExpandedCard(card) {
    var key = card.getAttribute('data-card-key') || '';
    localState.expandedKey = localState.expandedKey === key ? '' : key;
    Array.prototype.slice.call(document.querySelectorAll('[data-expandable="true"]')).forEach(function (item) {
      var expanded = (item.getAttribute('data-card-key') || '') === localState.expandedKey;
      item.classList.toggle('expanded', expanded);
      updateExpandLabel(item);
    });
  }
  function statusLabel(value) {
    var raw = text(value);
    var key = raw.toLowerCase();
    if (key === 'ready' || key === 'success' || key === 'available') { return '已完成'; }
    if (key === 'pending' || key === 'thinking') { return '执行中'; }
    if (key === 'needs_auth') { return '待授权'; }
    if (key === 'error' || key === 'failed' || key === 'fail') { return '失败'; }
    return raw;
  }
  function heroTitle() {
    var raw = text(data.title);
    if ((text(data.kind) === 'thinking' || text(data.source) === 'pending') && raw === 'Generating') {
      return '正在整理结果';
    }
    return raw || kindLabel(data.kind) || 'A2UI';
  }
  function heroSubtitle() {
    var raw = text(data.subtitle);
    if (raw.length > 0) { return raw; }
    if (text(data.source) === 'pending' || text(data.kind) === 'thinking') {
      return '已收到请求，正在等待模型或工具返回。';
    }
    if (text(data.kind) === 'welcome') {
      return '输入需求后，这里会展示真实返回的任务结果。';
    }
    return '';
  }
  function emptyCopy() {
    if (text(data.source) === 'pending' || text(data.kind) === 'thinking') {
      return '正在执行，结果会在这里出现。';
    }
    if (text(data.kind) === 'welcome') {
      return '还没有任务结果。发起一次查询后，卡片会在这里展开。';
    }
    return '暂无任务结果。真实返回后会显示在这里。';
  }
  function add(parent, tag, className, value) {
    var node = document.createElement(tag);
    if (className) { node.className = className; }
    if (value !== undefined && value !== null && text(value).length > 0) {
      node.textContent = text(value);
    }
    parent.appendChild(node);
    return node;
  }
  function postAction(action) {
    if (isBusy) { return; }
    try {
      if (window.AIPhoneHome && typeof window.AIPhoneHome.postAction === 'function') {
        window.AIPhoneHome.postAction(JSON.stringify({
          id: text(action.id),
          label: text(action.label || action.id),
          prompt: text(action.prompt),
          variant: text(action.variant),
          kind: text(action.kind),
          args: action.args && typeof action.args === 'object' ? action.args : null
        }));
      }
    } catch (error) {
    }
  }
  function metricValue(block, labels) {
    var items = list(block && block.metrics).concat(list(block && block.rows));
    for (var itemIndex = 0; itemIndex < items.length; itemIndex += 1) {
      var label = text(items[itemIndex] && items[itemIndex].label);
      if (labels.indexOf(label) >= 0) {
        return text(items[itemIndex] && items[itemIndex].value);
      }
    }
    return '';
  }
  function numberIn(value) {
    var match = text(value).replace(/,/g, '').match(/[0-9]+(?:\\.[0-9]+)?/);
    return match ? Number(match[0]) : Number.NaN;
  }
  function distanceMeters(value) {
    var raw = text(value).toLowerCase();
    var valueNumber = numberIn(raw);
    if (!(valueNumber >= 0)) { return Number.POSITIVE_INFINITY; }
    return raw.indexOf('km') >= 0 || raw.indexOf('公里') >= 0 ? valueNumber * 1000 : valueNumber;
  }
  function durationMinutes(value) {
    var raw = text(value);
    var colon = raw.match(/([0-9]+):([0-9]+)/);
    if (colon) { return Number(colon[1]) * 60 + Number(colon[2]); }
    var hours = raw.match(/([0-9]+)\\s*(?:h|小时|时)/i);
    var minutes = raw.match(/([0-9]+)\\s*(?:m|分钟|分)/i);
    var total = (hours ? Number(hours[1]) * 60 : 0) + (minutes ? Number(minutes[1]) : 0);
    return total > 0 ? total : 999999;
  }
  function hasAvailableText(value) {
    var raw = text(value);
    if (raw.indexOf('有') >= 0 || raw.toLowerCase().indexOf('available') >= 0) { return true; }
    if (raw.indexOf('无') >= 0 && raw.indexOf('有') < 0) { return false; }
    return /[1-9][0-9]*/.test(raw);
  }
  function handleLocalAction(action) {
    if (isBusy) { return false; }
    var id = text(action && action.id);
    if (id === 'travel_show_all') { localState.travel = 'all'; applyLocalView(); return true; }
    if (id === 'travel_filter_train') { localState.travel = 'train'; applyLocalView(); return true; }
    if (id === 'travel_filter_flight') { localState.travel = 'flight'; applyLocalView(); return true; }
    if (id === 'food_show_all' || id === 'food_show_more') { localState.food = 'all'; applyLocalView(); return true; }
    if (id === 'food_filter_1km') { localState.food = 'within_1km'; applyLocalView(); return true; }
    if (id === 'client_show_more') { localState.trainShowMore = !localState.trainShowMore; applyLocalView(); return true; }
    if (id === 'client_sort_fastest') { localState.trainFastest = !localState.trainFastest; applyLocalView(); return true; }
    if (id === 'client_filter_available') { localState.trainAvailable = !localState.trainAvailable; applyLocalView(); return true; }
    return false;
  }
  function updateVisibleCount(visibleCount, totalCount) {
    var countNode = document.getElementById('block-count');
    if (countNode) {
      countNode.textContent = String(visibleCount) + ' / ' + String(totalCount) + ' 条';
    }
    var emptyNode = document.getElementById('filter-empty');
    if (emptyNode) {
      emptyNode.style.display = totalCount > 0 && visibleCount === 0 ? '' : 'none';
    }
  }
  function applyLocalView() {
    var cards = Array.prototype.slice.call(document.querySelectorAll('.block'));
    var trains = cards.filter(function (card) {
      return (card.getAttribute('data-kind') || '') === 'train-option';
    }).sort(function (left, right) {
      if (localState.trainFastest) {
        return durationMinutes(left.getAttribute('data-duration') || '') - durationMinutes(right.getAttribute('data-duration') || '');
      }
      return numberIn(left.getAttribute('data-train-index') || '') - numberIn(right.getAttribute('data-train-index') || '');
    });
    trains.forEach(function (card) {
      if (card.parentNode) { card.parentNode.appendChild(card); }
    });
    cards = Array.prototype.slice.call(document.querySelectorAll('.block'));
    var trainVisibleCount = 0;
    var visibleCount = 0;
    cards.forEach(function (card) {
      var kind = card.getAttribute('data-kind') || '';
      var visible = true;
      if (kind === 'travel-option' && localState.travel !== 'all') {
        visible = (card.getAttribute('data-source') || '').toLowerCase().indexOf(localState.travel) >= 0;
      }
      if (kind === 'food-result' && localState.food === 'within_1km') {
        visible = distanceMeters(card.getAttribute('data-distance') || '') <= 1000;
      }
      if (kind === 'train-option' && localState.trainAvailable) {
        visible = hasAvailableText(card.getAttribute('data-availability') || '');
      }
      if (kind === 'train-option' && visible) {
        trainVisibleCount += 1;
        if (!localState.trainShowMore && trainVisibleCount > 6) {
          visible = false;
        }
      }
      if (visible) { visibleCount += 1; }
      card.style.display = visible ? '' : 'none';
    });
    updateVisibleCount(visibleCount, cards.length);
  }
  function addPairs(parent, items, className) {
    var kept = list(items).filter(function (item) {
      return text(item && item.label).length > 0 && text(item && item.value).length > 0;
    });
    if (kept.length === 0) { return; }
    var grid = add(parent, 'div', className || 'metrics');
    kept.forEach(function (item) {
      var card = add(grid, 'div', className === 'rows' ? 'row' : 'metric');
      add(card, 'div', 'label', item.label);
      add(card, 'div', 'value', item.value);
    });
  }
  function addActions(parent, actions) {
    var kept = list(actions).filter(function (action) {
      return text(action && (action.label || action.id)).length > 0;
    });
    if (kept.length === 0) { return; }
    var row = add(parent, 'div', 'actions');
    kept.forEach(function (action) {
      var button = add(row, 'button', 'action', action.label || action.id);
      button.type = 'button';
      button.disabled = isBusy;
      if (isBusy) { button.setAttribute('aria-disabled', 'true'); }
      button.addEventListener('click', function (event) {
        event.stopPropagation();
        if (isBusy) { return; }
        if (handleLocalAction(action)) {
          return;
        }
        postAction(action);
      });
    });
  }
  function addCredentialForm(parent, block) {
    var credentialName = text(block && block.credentialName);
    var credentialRef = text(block && block.credentialRef);
    if (text(block && block.kind) !== 'dynamic-tool-connect' || credentialName.length === 0 || credentialRef.length === 0) {
      return;
    }
    var wrap = add(parent, 'div', 'credential');
    wrap.addEventListener('click', function (event) {
      event.stopPropagation();
    });
    var input = document.createElement('input');
    input.type = 'password';
    input.placeholder = '粘贴 ' + credentialName;
    input.disabled = isBusy;
    wrap.appendChild(input);
    var button = add(wrap, 'button', 'action', '保存并测试');
    button.type = 'button';
    button.disabled = isBusy;
    button.addEventListener('click', function (event) {
      event.stopPropagation();
      if (isBusy) { return; }
      if ((input.value || '').trim().length === 0) {
        input.focus();
        return;
      }
      postAction({
        id: 'html_dynamic_save_and_test',
        label: '保存并测试',
        prompt: JSON.stringify({
          credentialRef: credentialRef,
          credentialValue: input.value || '',
          toolId: text(block.toolId),
          prompt: text(block.prompt)
        }),
        variant: 'primary',
        kind: 'client'
      });
    });
  }
  app.textContent = '';
  var shell = add(app, 'main', 'shell');
  var hero = add(shell, 'header', 'hero');
  var eyebrow = text(data.kind) === 'welcome' ? '' : kindLabel(data.kind);
  if (eyebrow.length > 0) { add(hero, 'div', 'eyebrow', eyebrow); }
  add(hero, 'h1', '', heroTitle());
  add(hero, 'p', 'subtitle', heroSubtitle());
  var chips = list(data.chips).slice();
  if (chips.length > 0) {
    var chipbar = add(shell, 'nav', 'chipbar');
    chips.forEach(function (chip) {
      add(chipbar, 'span', 'chip', [text(chip.label), text(chip.value)].filter(Boolean).join(' · '));
    });
  }
  addActions(hero, data.actions);
  var blocks = list(data.blocks);
  if (blocks.length > 0) {
    var blocksSection = add(shell, 'section', 'section');
    var blocksHead = add(blocksSection, 'div', 'section-head');
    add(blocksHead, 'h2', '', '任务结果');
    var countNode = add(blocksHead, 'div', 'meta', String(blocks.length) + ' 条');
    countNode.id = 'block-count';
    var filterEmpty = add(blocksSection, 'div', 'empty filter-empty', '当前筛选下暂无匹配结果。');
    filterEmpty.id = 'filter-empty';
    var trainIndex = 0;
    blocks.forEach(function (block) {
      var card = add(blocksSection, 'article', 'block');
      var expandable = isExpandable(block);
      card.setAttribute('data-kind', text(block.kind));
      card.setAttribute('data-source-key', sourceKey(block));
      if (expandable) {
        card.setAttribute('data-card-key', text(block.id) || text(block.title) || String(blocks.indexOf(block)));
        card.setAttribute('data-expandable', 'true');
        card.setAttribute('aria-expanded', 'false');
        card.addEventListener('click', function () {
          setExpandedCard(card);
        });
      }
      if (text(block.kind) === 'train-option') {
        card.setAttribute('data-train-index', String(trainIndex));
        trainIndex += 1;
      }
      card.setAttribute('data-source', [text(block.source), metricValue(block, ['source'])].join(' '));
      card.setAttribute('data-distance', metricValue(block, ['distance']));
      card.setAttribute('data-duration', metricValue(block, ['duration']));
      card.setAttribute('data-availability', [
        metricValue(block, ['availability', 'status']),
        metricValue(block, ['seats', 'business', 'first', 'second', 'noSeat', 'hardSeat', 'sleeperSoft'])
      ].join(' '));
      var top = add(card, 'div', 'block-top');
      var titleWrap = add(top, 'div', 'block-title');
      add(titleWrap, 'div', 'kind-tag', blockTagLabel(block));
      add(titleWrap, 'h3', '', text(block.title) || text(block.kind) || text(block.id));
      add(titleWrap, 'p', 'subtitle', text(block.subtitle));
      if (expandable) {
        var expandButton = add(top, 'button', 'expand-button', '展开');
        expandButton.type = 'button';
        expandButton.addEventListener('click', function (event) {
          event.stopPropagation();
          setExpandedCard(card);
        });
      }
      var detailHost = expandable ? add(card, 'div', 'details') : card;
      addPairs(detailHost, block.metrics, 'metrics');
      addPairs(detailHost, block.rows, 'rows');
      if (text(block.rawPreview).length > 0) {
        add(detailHost, 'pre', 'raw', block.rawPreview);
      }
      addCredentialForm(detailHost, block);
      addActions(detailHost, block.actions);
    });
    applyLocalView();
  } else {
    add(shell, 'section', 'empty', emptyCopy());
  }
  var timeline = list(data.timeline);
  if (timeline.length > 0 && (blocks.length === 0 || isBusy)) {
    var timelineSection = add(shell, 'section', 'section');
    var timelineHead = add(timelineSection, 'div', 'section-head');
    add(timelineHead, 'h2', '', '执行轨迹');
    var timelineWrap = add(timelineSection, 'div', 'timeline');
    timeline.forEach(function (item) {
      var node = add(timelineWrap, 'article', 'timeline-item');
      add(node, 'h3', '', text(item.title) === 'prompt' ? '用户请求' : text(item.title) || statusLabel(item.status));
      add(node, 'p', 'subtitle', text(item.subtitle));
      add(node, 'div', 'meta', statusLabel(item.status));
    });
  }
  var history = list(data.history);
  if (history.length > 0) {
    var historySection = add(shell, 'section', 'section');
    var historyHead = add(historySection, 'div', 'section-head');
    add(historyHead, 'h2', '', '最近上下文');
    history.forEach(function (item) {
      var node = add(historySection, 'article', 'history-item');
      add(node, 'div', 'meta', text(item.role));
      add(node, 'p', 'subtitle', text(item.content));
    });
  }
})();
`;

export function renderHtmlHomeDocument(document: HtmlHomeDocument, isBusy: boolean = false): string {
  const renderDocument: HtmlHomeDocumentWithBusy = {
    version: document.version,
    source: document.source,
    kind: document.kind,
    title: document.title,
    subtitle: document.subtitle,
    chips: document.chips,
    metrics: document.metrics,
    timeline: document.timeline,
    blocks: document.blocks,
    actions: document.actions,
    history: document.history,
    rawSurfaceRoot: document.rawSurfaceRoot,
    generatedAt: '',
    isBusy: isBusy || (document as HtmlHomeDocumentWithBusy).isBusy === true
  };
  const json = escapeScriptJson(JSON.stringify(renderDocument));
  const title = escapeHtmlText(document.title.length > 0 ? document.title : document.kind);
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${title}</title>
<style>${HTML_HOME_CSS}</style>
</head>
<body>
<div id="app"></div>
<script id="home-data" type="application/json">${json}</script>
<script>${HTML_HOME_JS}</script>
</body>
</html>`;
}

function escapeScriptJson(json: string): string {
  return json
    .split('&').join('\\u0026')
    .split('<').join('\\u003c')
    .split('>').join('\\u003e')
    .split('\u2028').join('\\u2028')
    .split('\u2029').join('\\u2029');
}

function escapeHtmlText(value: HtmlHomeTextValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  return value.toString()
    .split('&').join('&amp;')
    .split('<').join('&lt;')
    .split('>').join('&gt;')
    .split('"').join('&quot;');
}
