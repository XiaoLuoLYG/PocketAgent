import { HtmlHomeBlock, HtmlHomeDocument } from './HtmlHomeTypes';

type HtmlMediaTextValue = Object | string | number | boolean | null | undefined;

interface HtmlMediaHomeDocumentWithBusy extends HtmlHomeDocument {
  isBusy?: boolean;
}

const MEDIA_HOME_CSS: string = `
:root {
  color-scheme: light;
  --paper: #f8f2e8;
  --ink: #17120d;
  --muted: #756c62;
  --line: rgba(23, 18, 13, 0.12);
  --line-strong: rgba(23, 18, 13, 0.2);
  --panel: rgba(255, 250, 241, 0.94);
  --panel-strong: #fffaf1;
  --youtube: #ad4a3f;
  --bilibili: #b66783;
  --youtube-card: #fff1e9;
  --bilibili-card: #fff0f6;
  --local: #815f3e;
  --media-hero-fixed-image: url("https://images.unsplash.com/photo-1741968323015-08282392b54f?auto=format&fit=crop&w=1200&q=80");
  --shadow: 0 18px 44px rgba(37, 24, 13, 0.14);
  --tight-shadow: 0 10px 24px rgba(37, 24, 13, 0.1);
}
* { box-sizing: border-box; }
body {
  margin: 0;
  min-height: 100vh;
  background:
    linear-gradient(180deg, rgba(255, 250, 241, 0.78) 0%, rgba(248, 242, 232, 0.98) 58%, var(--paper) 100%),
    var(--paper);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", "Helvetica Neue", Arial, sans-serif;
  letter-spacing: 0;
  -webkit-font-smoothing: antialiased;
}
button { font: inherit; cursor: pointer; }
button:disabled { cursor: default; opacity: 0.5; }
h1, h2, h3, p { margin: 0; }
img { display: block; }
.media-shell {
  width: min(100%, 820px);
  min-height: 100vh;
  margin: 0 auto;
  padding-bottom: calc(92px + env(safe-area-inset-bottom, 0px));
}
.media-hero {
  position: relative;
  min-height: 330px;
  padding: 24px 16px 20px;
  overflow: hidden;
  background: #21170f;
  isolation: isolate;
}
.media-hero::before {
  content: "";
  position: absolute;
  inset: 0;
  z-index: -2;
  background:
    var(--media-hero-fixed-image),
    linear-gradient(135deg, #2b2017, #5d3d26 52%, #243947);
  background-size: cover;
  background-position: center;
  filter: none;
  transform: scale(1.12);
}
.media-hero::after {
  content: "";
  position: absolute;
  inset: 0;
  z-index: -1;
  background:
    linear-gradient(180deg, rgba(18, 13, 9, 0.06) 0%, rgba(18, 13, 9, 0.28) 44%, rgba(248, 242, 232, 0.98) 100%),
    linear-gradient(90deg, rgba(248, 242, 232, 0.88) 0%, rgba(248, 242, 232, 0.48) 48%, rgba(248, 242, 232, 0.18) 100%);
}
.media-hero-grid {
  position: relative;
  z-index: 1;
  display: flex;
  min-height: 286px;
  align-items: flex-end;
}
.media-hero-copy {
  max-width: 620px;
}
.media-kicker {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  border: 1px solid rgba(23, 18, 13, 0.14);
  border-radius: 999px;
  padding: 7px 10px;
  background: rgba(255, 250, 241, 0.84);
  color: var(--muted);
  font-size: 12px;
  font-weight: 820;
  line-height: 1;
  backdrop-filter: blur(18px);
  box-shadow: 0 10px 28px rgba(37, 24, 13, 0.08);
}
.media-hero h1 {
  margin-top: 14px;
  max-width: 10em;
  overflow-wrap: anywhere;
  font-size: 42px;
  line-height: 1.02;
  font-weight: 860;
}
.media-hero p {
  margin-top: 10px;
  max-width: 32em;
  color: rgba(23, 18, 13, 0.76);
  font-size: 14px;
  line-height: 1.55;
  overflow-wrap: anywhere;
}
.media-hero-stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 8px;
  max-width: 520px;
  margin-top: 14px;
}
.media-stat {
  min-height: 60px;
  border: 1px solid rgba(23, 18, 13, 0.1);
  border-radius: 16px;
  padding: 10px;
  background: rgba(255, 250, 241, 0.76);
  backdrop-filter: blur(16px);
}
.media-stat b {
  display: block;
  color: var(--ink);
  font-size: 18px;
  line-height: 1;
}
.media-stat span {
  display: block;
  margin-top: 7px;
  color: var(--muted);
  font-size: 11px;
  font-weight: 760;
  line-height: 1.1;
}
.media-logo-row {
  display: inline-flex;
  align-items: center;
  gap: 4px;
}
.media-logo-mark {
  position: relative;
  display: inline-grid;
  place-items: center;
  width: 24px;
  height: 24px;
  overflow: hidden;
  border: 1px solid rgba(23, 18, 13, 0.12);
  border-radius: 9px;
  background: rgba(255, 250, 241, 0.9);
  color: var(--ink);
  vertical-align: middle;
}
.media-logo-mark[data-source-key="media-youtube"] { color: var(--youtube); }
.media-logo-mark[data-source-key="media-bilibili"] { color: var(--bilibili); }
.media-logo-mark img {
  width: 17px;
  height: 17px;
  object-fit: contain;
}
.media-logo-letter {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  color: currentColor;
  font-size: 10px;
  font-weight: 900;
  line-height: 1;
}
.media-logo-mark img + .media-logo-letter { opacity: 0; }
.media-logo-mark[data-broken="true"] img { display: none; }
.media-logo-mark[data-broken="true"] .media-logo-letter { opacity: 1; }
.media-source-rail {
  position: sticky;
  top: 0;
  z-index: 8;
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding: 12px 14px 13px;
  border-bottom: 1px solid rgba(23, 18, 13, 0.06);
  background: rgba(248, 242, 232, 0.92);
  backdrop-filter: blur(18px);
  scrollbar-width: none;
}
.media-source-rail::-webkit-scrollbar { display: none; }
.media-filter {
  flex: 0 0 auto;
  display: inline-flex;
  align-items: center;
  gap: 7px;
  min-height: 40px;
  border: 1px solid var(--line);
  border-radius: 999px;
  padding: 9px 13px;
  background: rgba(255, 250, 241, 0.92);
  color: var(--ink);
  font-size: 12px;
  font-weight: 800;
  line-height: 1;
  box-shadow: 0 8px 18px rgba(37, 24, 13, 0.06);
}
.media-filter.active {
  border-color: var(--ink);
  background: var(--ink);
  color: var(--panel-strong);
}
.media-filter.active .media-logo-mark {
  border-color: rgba(255, 250, 241, 0.28);
  background: rgba(255, 250, 241, 0.12);
  color: var(--panel-strong);
}
.media-filter[data-filter="youtube"],
.media-filter[data-filter="bilibili"],
.media-filter[data-filter="error"] {
  scroll-margin-left: 12px;
}
.media-card-player::after {
  content: "";
  position: absolute;
  inset: auto 0 0;
  height: 72px;
  pointer-events: none;
  background: linear-gradient(180deg, rgba(23, 18, 13, 0), rgba(23, 18, 13, 0.58));
}
.media-player-chrome {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  z-index: 2;
  display: flex;
  align-items: center;
  gap: 6px;
  height: 34px;
  padding: 0 12px;
  background: linear-gradient(180deg, rgba(23, 18, 13, 0.72), rgba(23, 18, 13, 0));
  color: rgba(255, 250, 241, 0.82);
  font-size: 10px;
  font-weight: 780;
  letter-spacing: 0;
  pointer-events: none;
}
.media-player-dot {
  width: 7px;
  height: 7px;
  border-radius: 99px;
  background: rgba(255, 250, 241, 0.62);
}
.media-player-title {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.media-player-placeholder {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  padding: 42px 18px 18px;
  text-align: center;
  background:
    radial-gradient(circle at 20% 10%, rgba(196, 48, 43, 0.16), transparent 38%),
    radial-gradient(circle at 82% 18%, rgba(45, 143, 189, 0.16), transparent 42%),
    rgba(255, 250, 241, 0.92);
}
.media-player-placeholder p {
  max-width: 24em;
  color: rgba(23, 18, 13, 0.66);
  font-size: 13px;
  line-height: 1.45;
}
.media-provider-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 10px;
  padding: 0 14px 16px;
}
.media-card {
  --source-accent: var(--local);
  --source-soft: rgba(129, 95, 62, 0.12);
  --card-bg: var(--panel-strong);
  position: relative;
  overflow: hidden;
  border: 1px solid rgba(23, 18, 13, 0.1);
  border-radius: 30px;
  padding: 0;
  background:
    linear-gradient(135deg, var(--source-soft), rgba(255, 250, 241, 0) 54%),
    var(--card-bg);
  box-shadow: 0 18px 42px rgba(37, 24, 13, 0.13);
  -webkit-tap-highlight-color: transparent;
  transition: border-color 0.18s ease, box-shadow 0.18s ease, transform 0.18s ease, background 0.18s ease;
}
.media-card:focus-visible {
  outline: 2px solid var(--source-accent);
  outline-offset: 2px;
}
.media-card.expanded {
  border-color: rgba(23, 18, 13, 0.16);
  background:
    linear-gradient(135deg, var(--source-soft), rgba(255, 250, 241, 0) 58%),
    var(--card-bg);
  box-shadow: 0 22px 50px rgba(37, 24, 13, 0.18);
}
.media-card.expanded {
  transform: translateY(-1px);
}
.media-card[data-source-key="media-youtube"] {
  --source-accent: var(--youtube);
  --source-soft: rgba(173, 74, 63, 0.13);
  --card-bg: var(--youtube-card);
}
.media-card[data-source-key="media-bilibili"] {
  --source-accent: var(--bilibili);
  --source-soft: rgba(182, 103, 131, 0.15);
  --card-bg: var(--bilibili-card);
}
.media-card h3 {
  min-width: 0;
  overflow-wrap: anywhere;
  color: var(--ink);
  font-size: 16px;
  line-height: 1.22;
  font-weight: 820;
}
.media-card p {
  margin-top: 8px;
  color: var(--muted);
  font-size: 13px;
  line-height: 1.45;
  overflow-wrap: anywhere;
}
.media-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  border-radius: 999px;
  padding: 5px 8px 5px 5px;
  border: 1px solid rgba(23, 18, 13, 0.08);
  background: var(--source-soft);
  color: var(--source-accent);
  font-size: 11px;
  font-weight: 820;
  line-height: 1;
  flex: 0 0 auto;
  white-space: nowrap;
}
.media-card-player {
  position: relative;
  overflow: hidden;
  border-radius: 30px 30px 0 0;
  aspect-ratio: 16 / 9;
  background: #080604;
}
.media-card-player::before {
  content: "";
  position: absolute;
  inset: 0;
  z-index: 0;
  background:
    var(--media-player-image, linear-gradient(135deg, rgba(196, 48, 43, 0.28), rgba(45, 143, 189, 0.22))),
    linear-gradient(135deg, #251a12, #080604);
  background-size: cover;
  background-position: center;
  filter: blur(18px) saturate(0.9);
  opacity: 0.62;
  transform: scale(1.14);
}
.media-card-player iframe {
  position: relative;
  z-index: 1;
  width: 100%;
  height: 100%;
  border: 0;
  display: block;
}
.media-card-body {
  margin-top: 0;
  padding: 16px 18px 18px;
}
.media-card-title-row {
  display: block;
}
.media-card-side {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  width: 100%;
  max-width: 100%;
  margin-top: 12px;
  flex-wrap: nowrap;
}
.media-card-actions {
  display: flex;
  flex: 0 0 auto;
  gap: 8px;
  margin-top: 0;
  flex-wrap: nowrap;
}
.media-card-action {
  border: 1px solid rgba(23, 18, 13, 0.1);
  border-radius: 999px;
  padding: 8px 10px;
  background: rgba(255, 250, 241, 0.78);
  color: var(--ink);
  font-size: 12px;
  font-weight: 780;
  white-space: nowrap;
}
.media-card-action.primary {
  border-color: var(--source-accent);
  color: var(--source-accent);
}
.media-card-detail {
  display: none;
  margin-top: 12px;
  border: 1px solid rgba(23, 18, 13, 0.08);
  border-radius: 18px;
  padding: 12px;
  background: rgba(255, 250, 241, 0.64);
}
.media-card.expanded .media-card-detail { display: block; }
.media-detail-grid {
  display: grid;
  gap: 8px;
  grid-template-columns: repeat(2, minmax(0, 1fr));
}
.media-detail-cell {
  border: 1px solid rgba(23, 18, 13, 0.08);
  border-radius: 14px;
  padding: 9px;
  background: rgba(255, 250, 241, 0.64);
}
.media-detail-cell span {
  display: block;
  color: var(--muted);
  font-size: 10px;
  font-weight: 820;
  line-height: 1;
}
.media-detail-cell b {
  display: block;
  min-height: 1.2em;
  margin-top: 6px;
  overflow: hidden;
  color: var(--ink);
  font-size: 12px;
  line-height: 1.25;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.media-empty {
  margin: 14px;
  border: 1px dashed var(--line);
  border-radius: 20px;
  padding: 18px;
  background: rgba(255, 250, 241, 0.72);
  color: var(--muted);
  font-size: 13px;
  line-height: 1.5;
}
@media (min-width: 720px) {
  .media-provider-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .media-hero { min-height: 360px; padding-left: 22px; padding-right: 22px; }
  .media-hero-grid { min-height: 316px; }
  .media-hero h1 { font-size: 50px; }
}
@media (max-width: 360px) {
  .media-hero h1 { font-size: 39px; }
  .media-detail-grid { grid-template-columns: 1fr; }
}
`;

const MEDIA_HOME_JS: string = `
(function () {
  var node = document.getElementById('home-data');
  var data = {};
  try { data = JSON.parse(node && node.textContent ? node.textContent : '{}') || {}; } catch (error) { data = {}; }
  var app = document.getElementById('app');
  if (!app) { return; }
  var state = { filter: 'all' };
  var isBusy = text(data.isBusy).toLowerCase() === 'true';
  function text(value) { return value === undefined || value === null ? '' : String(value); }
  function list(value) { return Array.isArray(value) ? value : []; }
  function add(parent, tag, className, value) {
    var el = document.createElement(tag);
    if (className) { el.className = className; }
    if (value !== undefined && value !== null && text(value).length > 0) { el.textContent = text(value); }
    parent.appendChild(el);
    return el;
  }
  function trim(value) { return text(value).replace(/^\\s+|\\s+$/g, ''); }
  function metric(block, labels) {
    var items = list(block && block.metrics).concat(list(block && block.rows));
    for (var i = 0; i < items.length; i += 1) {
      var label = text(items[i] && items[i].label);
      if (labels.indexOf(label) >= 0) { return text(items[i] && items[i].value); }
    }
    return '';
  }
  function sourceKey(block) {
    var media = block && block.mediaEmbed ? block.mediaEmbed : {};
    var raw = [text(media.provider), text(block && block.source), text(block && block.title), text(media.pageUrl)].join(' ').toLowerCase();
    if (raw.indexOf('youtube') >= 0 || raw.indexOf('youtu.be') >= 0) { return 'media-youtube'; }
    if (raw.indexOf('bilibili') >= 0 || raw.indexOf('哔哩哔哩') >= 0 || raw.indexOf('b站') >= 0 || raw.indexOf('b 站') >= 0) { return 'media-bilibili'; }
    return 'media-local';
  }
  function sourceLabel(key) {
    if (key === 'media-youtube') { return 'YouTube'; }
    if (key === 'media-bilibili') { return 'B 站'; }
    return '媒体';
  }
  function sourceLogoUrl(key) {
    if (key === 'media-youtube') { return 'https://upload.wikimedia.org/wikipedia/commons/e/ef/Youtube_logo.png'; }
    if (key === 'media-bilibili') { return 'data:image/svg+xml;charset=utf-8,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 64 64%22%3E%3Crect width=%2264%22 height=%2264%22 rx=%2214%22 fill=%22%23fb7299%22/%3E%3Cpath d=%22M18 22h28a6 6 0 0 1 6 6v16a6 6 0 0 1-6 6H18a6 6 0 0 1-6-6V28a6 6 0 0 1 6-6Z%22 fill=%22none%22 stroke=%22white%22 stroke-width=%224%22/%3E%3Cpath d=%22M24 14l7 8M40 14l-7 8%22 stroke=%22white%22 stroke-width=%224%22 stroke-linecap=%22round%22/%3E%3Ctext x=%2232%22 y=%2241%22 text-anchor=%22middle%22 font-family=%22Arial,sans-serif%22 font-size=%2213%22 font-weight=%22700%22 fill=%22white%22%3Ebilibili%3C/text%3E%3C/svg%3E'; }
    return '';
  }
  function sourceShort(key) {
    if (key === 'media-youtube') { return 'YT'; }
    if (key === 'media-bilibili') { return 'B'; }
    return 'M';
  }
  function addLogo(parent, key) {
    var mark = add(parent, 'span', 'media-logo-mark');
    mark.setAttribute('data-source-key', key);
    mark.setAttribute('aria-label', sourceLabel(key));
    var url = sourceLogoUrl(key);
    if (url.length > 0) {
      var img = document.createElement('img');
      img.alt = '';
      img.loading = 'lazy';
      img.onerror = function () { mark.setAttribute('data-broken', 'true'); };
      img.src = url;
      mark.appendChild(img);
    } else {
      mark.setAttribute('data-broken', 'true');
    }
    add(mark, 'span', 'media-logo-letter', sourceShort(key));
    return mark;
  }
  function isAllowedMediaEmbedUrl(url) {
    var raw = text(url);
    return raw.indexOf('https://www.youtube.com/embed/') === 0 ||
      raw.indexOf('https://player.bilibili.com/player.html?') === 0;
  }
  function playable(block) {
    return !!(block && block.mediaEmbed && isAllowedMediaEmbedUrl(block.mediaEmbed.embedUrl));
  }
  function titleOf(block) {
    var media = block && block.mediaEmbed ? block.mediaEmbed : {};
    return trim(block && block.title) || trim(media.title) || '媒体结果';
  }
  function summaryOf(block) {
    var media = block && block.mediaEmbed ? block.mediaEmbed : {};
    return trim(block && block.subtitle) || trim(metric(block, ['source'])) || trim(media.pageUrl) || '点击卡片播放并展开详情。';
  }
  function isMediaBlock(block) {
    if (!block) { return false; }
    if (block.mediaEmbed) { return true; }
    var raw = [
      text(block.source),
      text(block.title),
      text(block.subtitle),
      metric(block, ['source', 'toolName', 'Watch URL', 'Playback URL'])
    ].join(' ').toLowerCase();
    return raw.indexOf('media.video.search') >= 0 ||
      raw.indexOf('youtube') >= 0 ||
      raw.indexOf('youtu.be') >= 0 ||
      raw.indexOf('bilibili') >= 0 ||
      raw.indexOf('哔哩哔哩') >= 0 ||
      raw.indexOf('b站') >= 0 ||
      raw.indexOf('b 站') >= 0;
  }
  function isGenericTitle(value) {
    var raw = trim(value);
    return raw.length === 0 || raw === '动态工具结果' || raw === '工具结果' || raw === '任务结果';
  }
  function heroTitle() {
    var raw = trim(data.title);
    if (isGenericTitle(raw)) { return '媒体搜索结果'; }
    return raw;
  }
  function heroSubtitle() {
    var subtitle = trim(data.subtitle);
    if (subtitle.length > 0) { return subtitle; }
    return '聚合 YouTube 与 B 站视频，每张卡片都可直接播放、展开详情并打开来源网页。';
  }
  function postAction(action) {
    if (isBusy || text(action && action.id) !== 'media.open.web') { return; }
    try {
      if (window.AIPhoneHome && typeof window.AIPhoneHome.postAction === 'function') {
        window.AIPhoneHome.postAction(JSON.stringify({
          id: text(action.id),
          label: text(action.label),
          prompt: text(action.prompt),
          variant: text(action.variant),
          kind: text(action.kind),
          sourceComponentId: text(action.sourceComponentId),
          args: action.args || {}
        }));
      }
    } catch (error) {}
  }
  function updateButtons() {
    Array.prototype.slice.call(document.querySelectorAll('.media-filter')).forEach(function (button) {
      var filter = button.getAttribute('data-filter') || '';
      button.classList.toggle('active', filter === state.filter);
    });
  }
  function applyFilter() {
    var visible = 0;
    Array.prototype.slice.call(document.querySelectorAll('.media-card')).forEach(function (card) {
      var key = card.getAttribute('data-source-key') || '';
      var keep = state.filter === 'all' ||
        (state.filter === 'error' && text(card.getAttribute('data-status')).toLowerCase() === 'error') ||
        key.indexOf(state.filter) >= 0;
      card.style.display = keep ? '' : 'none';
      if (keep) { visible += 1; }
    });
    var empty = document.getElementById('media-empty-filter');
    if (empty) { empty.style.display = visible === 0 ? '' : 'none'; }
    updateButtons();
  }
  function openAction(block) {
    var media = block && block.mediaEmbed ? block.mediaEmbed : {};
    var actions = list(block && block.actions);
    for (var i = 0; i < actions.length; i += 1) {
      if (text(actions[i] && actions[i].id) === 'media.open.web') { return actions[i]; }
    }
    return { id: 'media.open.web', label: '打开网页', prompt: text(media.pageUrl), variant: 'primary', kind: 'client' };
  }
  function thumbnailUrl(block) {
    var media = block && block.mediaEmbed ? block.mediaEmbed : {};
    return text(media.thumbnail).replace(/"/g, '%22');
  }
  function renderPlayer(parent, block, className) {
    var media = block && block.mediaEmbed ? block.mediaEmbed : {};
    var key = sourceKey(block);
    var player = add(parent, 'div', className || 'media-player');
    var poster = thumbnailUrl(block);
    if (poster.length > 0) { player.style.setProperty('--media-player-image', 'url("' + poster + '")'); }
    if (playable(block)) {
      var iframe = document.createElement('iframe');
      iframe.title = text(media.title) || text(block && block.title) || 'media player';
      iframe.setAttribute('loading', 'lazy');
      iframe.setAttribute('allowfullscreen', 'true');
      iframe.setAttribute('allow', 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share');
      iframe.setAttribute('referrerpolicy', 'origin-when-cross-origin');
      iframe.src = text(media.embedUrl);
      player.appendChild(iframe);
    } else {
      var chrome = add(player, 'div', 'media-player-chrome');
      add(chrome, 'span', 'media-player-dot');
      addLogo(chrome, key);
      add(chrome, 'span', 'media-player-title', sourceLabel(key) + ' · ' + titleOf(block));
      var placeholder = add(player, 'div', 'media-player-placeholder');
      add(placeholder, 'p', '', '当前结果没有可安全内嵌的视频地址，可以打开来源网页观看。');
    }
    return player;
  }
  function addFact(parent, label, value) {
    var cell = add(parent, 'div', 'media-detail-cell');
    add(cell, 'span', '', label);
    add(cell, 'b', '', value);
  }
  function collapseCard(card) {
    card.classList.remove('expanded');
    card.setAttribute('aria-expanded', 'false');
  }
  function expandCard(card, block) {
    Array.prototype.slice.call(document.querySelectorAll('.media-card.expanded')).forEach(function (item) {
      if (item !== card) { collapseCard(item); }
    });
    card.classList.add('expanded');
    card.setAttribute('aria-expanded', 'true');
  }
  function countBySource(blocks, key) {
    var count = 0;
    blocks.forEach(function (block) {
      if (sourceKey(block) === key) { count += 1; }
    });
    return count;
  }
  function addHeroStat(parent, label, value) {
    var stat = add(parent, 'div', 'media-stat');
    add(stat, 'b', '', value);
    add(stat, 'span', '', label);
  }
  app.textContent = '';
  var shell = add(app, 'main', 'media-shell');
  var blocks = list(data.blocks).filter(isMediaBlock);
  var hero = add(shell, 'header', 'media-hero');
  var heroGrid = add(hero, 'div', 'media-hero-grid');
  var heroCopy = add(heroGrid, 'div', 'media-hero-copy');
  var kicker = add(heroCopy, 'div', 'media-kicker');
  var kickerLogos = add(kicker, 'span', 'media-logo-row');
  addLogo(kickerLogos, 'media-youtube');
  addLogo(kickerLogos, 'media-bilibili');
  add(kicker, 'span', '', '媒体聚合 · 视频来源');
  add(heroCopy, 'h1', '', heroTitle());
  add(heroCopy, 'p', '', heroSubtitle());
  var stats = add(heroCopy, 'div', 'media-hero-stats');
  addHeroStat(stats, '结果', String(blocks.length));
  addHeroStat(stats, 'YouTube', String(countBySource(blocks, 'media-youtube')));
  addHeroStat(stats, 'B 站', String(countBySource(blocks, 'media-bilibili')));
  var rail = add(shell, 'nav', 'media-source-rail');
  [
    ['all', '全部'],
    ['youtube', 'YouTube'],
    ['bilibili', 'B 站'],
    ['error', '错误']
  ].forEach(function (item) {
    var button = add(rail, 'button', 'media-filter');
    button.type = 'button';
    button.setAttribute('data-filter', item[0]);
    if (item[0] === 'youtube') { addLogo(button, 'media-youtube'); }
    if (item[0] === 'bilibili') { addLogo(button, 'media-bilibili'); }
    add(button, 'span', '', item[1]);
    button.disabled = isBusy;
    button.addEventListener('click', function () { state.filter = item[0]; applyFilter(); });
  });
  var grid = add(shell, 'section', 'media-provider-grid');
  var filterEmpty = add(grid, 'div', 'media-empty', '当前筛选下暂无媒体结果。');
  filterEmpty.id = 'media-empty-filter';
  filterEmpty.style.display = 'none';
  blocks.forEach(function (block, index) {
    var media = block && block.mediaEmbed ? block.mediaEmbed : {};
    var key = sourceKey(block);
    var card = add(grid, 'article', 'media-card');
    card.setAttribute('data-card-key', text(block.id) || String(index));
    card.setAttribute('data-source-key', key);
    card.setAttribute('data-playable', playable(block) ? 'true' : 'false');
    card.setAttribute('data-status', text(block.status));
    card.setAttribute('role', 'button');
    card.setAttribute('tabindex', '0');
    card.setAttribute('aria-expanded', 'false');
    renderPlayer(card, block, 'media-card-player');
    var copy = add(card, 'div', 'media-card-body');
    var titleRow = add(copy, 'div', 'media-card-title-row');
    add(titleRow, 'h3', '', titleOf(block));
    add(titleRow, 'p', '', summaryOf(block));
    var side = add(copy, 'div', 'media-card-side');
    var badge = add(side, 'span', 'media-badge');
    addLogo(badge, key);
    add(badge, 'span', '', sourceLabel(key));
    var actions = add(side, 'div', 'media-card-actions');
    var open = add(actions, 'button', 'media-card-action primary', '打开网页');
    open.type = 'button';
    open.disabled = isBusy || text(openAction(block).prompt).length === 0;
    open.addEventListener('click', function (event) { event.stopPropagation(); postAction(openAction(block)); });
    var detailPanel = add(card, 'div', 'media-card-detail');
    var detailGrid = add(detailPanel, 'div', 'media-detail-grid');
    addFact(detailGrid, '来源', sourceLabel(key));
    addFact(detailGrid, '播放', playable(block) ? '页面内播放' : '网页观看');
    addFact(detailGrid, '状态', text(block.status) || 'success');
    addFact(detailGrid, '链接', text(media.pageUrl).length > 0 ? '可打开' : '未返回');
    card.addEventListener('click', function () {
      if (card.classList.contains('expanded')) {
        collapseCard(card);
      } else {
        expandCard(card, block);
      }
    });
    card.addEventListener('keydown', function (event) {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        if (card.classList.contains('expanded')) {
          collapseCard(card);
        } else {
          expandCard(card, block);
        }
      }
    });
  });
  applyFilter();
})();
`;

export function shouldRenderMediaHomeDocument(document: HtmlHomeDocument): boolean {
  if (document.kind !== 'media') {
    return false;
  }
  if (document.blocks.length === 0) {
    return true;
  }
  const blocks = document.blocks;
  for (let index = 0; index < blocks.length; index++) {
    if (isMediaHomeBlock(blocks[index])) {
      return true;
    }
  }
  return false;
}

export function renderMediaHomeDocument(document: HtmlHomeDocument, isBusy: boolean = false): string {
  const mediaBlocks = mediaHomeBlocks(document.blocks);
  const renderDocument: HtmlMediaHomeDocumentWithBusy = {
    version: document.version,
    source: document.source,
    kind: document.kind,
    title: mediaDisplayTitle(document.title),
    subtitle: document.subtitle,
    chips: document.chips,
    metrics: document.metrics,
    timeline: document.timeline,
    blocks: mediaBlocks,
    actions: document.actions,
    history: [],
    rawSurfaceRoot: null,
    generatedAt: '',
    isBusy: isBusy || (document as HtmlMediaHomeDocumentWithBusy).isBusy === true
  };
  const json = escapeScriptJson(JSON.stringify(renderDocument));
  const title = escapeHtmlText(mediaDisplayTitle(document.title));
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${title}</title>
<style>${MEDIA_HOME_CSS}</style>
</head>
<body>
<div id="app"></div>
<script id="home-data" type="application/json">${json}</script>
<script>${MEDIA_HOME_JS}</script>
</body>
</html>`;
}

function mediaHomeBlocks(blocks: HtmlHomeBlock[]): HtmlHomeBlock[] {
  const mediaBlocks: HtmlHomeBlock[] = [];
  for (let index = 0; index < blocks.length; index++) {
    if (isMediaHomeBlock(blocks[index])) {
      mediaBlocks.push(blocks[index]);
    }
  }
  return mediaBlocks;
}

function isMediaHomeBlock(block: HtmlHomeBlock): boolean {
  if (block.mediaEmbed !== undefined) {
    return true;
  }
  if (block.kind !== 'generic-tool-result') {
    return false;
  }
  return mediaMetric(block, ['toolName']) === 'media.video.search';
}

function mediaMetric(block: HtmlHomeBlock, labels: string[]): string {
  const items = block.metrics.concat(block.rows);
  for (let index = 0; index < items.length; index++) {
    if (labels.indexOf(items[index].label) >= 0) {
      return items[index].value;
    }
  }
  return '';
}

function mediaDisplayTitle(title: string): string {
  const trimmed = title.trim();
  if (trimmed.length === 0 || trimmed === '动态工具结果' || trimmed === '工具结果' || trimmed === '任务结果') {
    return '媒体搜索结果';
  }
  return trimmed;
}

function escapeScriptJson(json: string): string {
  return json
    .split('&').join('\\u0026')
    .split('<').join('\\u003c')
    .split('>').join('\\u003e')
    .split('\u2028').join('\\u2028')
    .split('\u2029').join('\\u2029');
}

function escapeHtmlText(value: HtmlMediaTextValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  return value.toString()
    .split('&').join('&amp;')
    .split('<').join('&lt;')
    .split('>').join('&gt;')
    .split('"').join('&quot;');
}
