import { HtmlHomeDocument } from './HtmlHomeTypes';

type HtmlFoodTextValue = Object | string | number | boolean | null | undefined;

interface HtmlFoodHomeDocumentWithBusy extends HtmlHomeDocument {
  isBusy?: boolean;
}

const FOOD_HOME_CSS: string = `
:root {
  color-scheme: light;
  --paper: #f8f2e8;
  --ink: #17120d;
  --muted: #756c62;
  --line: rgba(23, 18, 13, 0.12);
  --cream: #fffaf1;
  --tomato: #d8492f;
  --gold: #d8a63f;
  --food-amap: #16875b;
  --food-tencent: #1f79a9;
  --food-baidu: #b94b65;
  --food-meituan: #c27a10;
  --food-taobao: #d95d1b;
  --food-mcd: #b97908;
  --food-kfc: #c8102e;
  --food-luckin: #356fc0;
  --food-google-maps: #4285f4;
  --food-local: #815f3e;
  --shadow: 0 18px 44px rgba(37, 24, 13, 0.15);
  --radius-xl: 30px;
  --radius-lg: 24px;
  --radius-md: 18px;
}
* { box-sizing: border-box; }
body {
  margin: 0;
  min-height: 100vh;
  background: var(--paper);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", "Helvetica Neue", Arial, sans-serif;
  letter-spacing: 0;
  -webkit-font-smoothing: antialiased;
}
button { font: inherit; cursor: pointer; }
button:disabled { cursor: default; opacity: 0.5; }
.editorial-food-shell {
  width: min(100%, 760px);
  min-height: 100vh;
  margin: 0 auto;
  padding-bottom: calc(84px + env(safe-area-inset-bottom, 0px));
  background: var(--paper);
}
.editorial-cover {
  position: relative;
  min-height: 360px;
  padding: 22px 18px 22px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  background: linear-gradient(145deg, #2f1b10 0%, #9d673e 48%, #f0bc58 100%);
  color: #fff;
}
.editorial-cover-media {
  position: absolute;
  inset: 0;
  background:
    linear-gradient(180deg, rgba(24, 13, 8, 0.18) 0%, rgba(24, 13, 8, 0.2) 38%, rgba(24, 13, 8, 0.76) 100%),
    url("https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80"),
    linear-gradient(145deg, #2f1b10 0%, #9d673e 48%, #f0bc58 100%);
  background-size: cover;
  background-position: center;
  transform: scale(1.02);
}
.editorial-cover::after {
  content: "";
  position: absolute;
  inset: auto 0 0;
  height: 58px;
  background: linear-gradient(180deg, rgba(248, 242, 232, 0), var(--paper));
}
.editorial-cover-content {
  position: relative;
  z-index: 1;
}
.editorial-kicker {
  display: inline-flex;
  align-items: center;
  min-height: 28px;
  padding: 7px 10px;
  border: 1px solid rgba(255, 255, 255, 0.34);
  border-radius: 999px;
  background: rgba(23, 18, 13, 0.28);
  color: #fff7e9;
  font-size: 12px;
  font-weight: 800;
  line-height: 1;
  backdrop-filter: blur(14px);
}
.editorial-cover h1 {
  margin: 18px 0 10px;
  max-width: 7.4em;
  overflow-wrap: anywhere;
  font-family: Georgia, "Times New Roman", "Songti SC", serif;
  font-size: 48px;
  line-height: 0.96;
  font-weight: 760;
}
.editorial-cover p {
  margin: 0;
  max-width: 27em;
  overflow-wrap: anywhere;
  color: rgba(255, 250, 241, 0.86);
  font-size: 14px;
  line-height: 1.55;
}
.source-cloud {
  position: relative;
  z-index: 1;
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 18px;
}
.source-pill {
  --source-accent: var(--food-local);
  border: 1px solid rgba(255, 255, 255, 0.26);
  border-radius: 999px;
  padding: 8px 10px;
  max-width: 100%;
  background: rgba(23, 18, 13, 0.44);
  color: #fffaf1;
  font-size: 11px;
  font-weight: 820;
  line-height: 1;
  overflow-wrap: anywhere;
  box-shadow: inset 0 -2px 0 var(--source-accent);
  backdrop-filter: blur(16px);
}
.source-pill[data-source-key="food-amap"], .editorial-card[data-source-key="food-amap"], .editorial-feature[data-source-key="food-amap"] { --source-accent: var(--food-amap); }
.source-pill[data-source-key="food-tencent"], .editorial-card[data-source-key="food-tencent"], .editorial-feature[data-source-key="food-tencent"] { --source-accent: var(--food-tencent); }
.source-pill[data-source-key="food-baidu"], .editorial-card[data-source-key="food-baidu"], .editorial-feature[data-source-key="food-baidu"] { --source-accent: var(--food-baidu); }
.source-pill[data-source-key="food-meituan"], .editorial-card[data-source-key="food-meituan"], .editorial-feature[data-source-key="food-meituan"] { --source-accent: var(--food-meituan); }
.source-pill[data-source-key="food-taobao"], .editorial-card[data-source-key="food-taobao"], .editorial-feature[data-source-key="food-taobao"] { --source-accent: var(--food-taobao); }
.source-pill[data-source-key="food-mcd"], .editorial-card[data-source-key="food-mcd"], .editorial-feature[data-source-key="food-mcd"] { --source-accent: var(--food-mcd); }
.source-pill[data-source-key="food-kfc"], .editorial-card[data-source-key="food-kfc"], .editorial-feature[data-source-key="food-kfc"] { --source-accent: var(--food-kfc); }
.source-pill[data-source-key="food-luckin"], .editorial-card[data-source-key="food-luckin"], .editorial-feature[data-source-key="food-luckin"] { --source-accent: var(--food-luckin); }
.source-pill[data-source-key="food-google-maps"], .editorial-card[data-source-key="food-google-maps"], .editorial-feature[data-source-key="food-google-maps"] { --source-accent: var(--food-google-maps); }
.source-pill[data-source-key="food-local"], .editorial-card[data-source-key="food-local"], .editorial-feature[data-source-key="food-local"] { --source-accent: var(--food-local); }
.cover-stats {
  position: relative;
  z-index: 1;
  display: flex;
  flex-wrap: wrap;
  gap: 9px;
  margin-top: 14px;
}
.cover-stat {
  border-radius: 999px;
  padding: 8px 10px;
  background: rgba(255, 250, 241, 0.9);
  color: var(--ink);
  font-size: 11px;
  font-weight: 840;
  line-height: 1;
}
.editorial-tabs {
  position: sticky;
  top: 0;
  z-index: 6;
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding: 12px 14px;
  background: rgba(248, 242, 232, 0.9);
  backdrop-filter: blur(16px);
  border-bottom: 1px solid rgba(23, 18, 13, 0.06);
  -webkit-overflow-scrolling: touch;
  scrollbar-width: none;
}
.editorial-tabs::-webkit-scrollbar { display: none; }
.editorial-tab {
  flex: 0 0 auto;
  border: 1px solid var(--line);
  border-radius: 999px;
  min-height: 38px;
  padding: 10px 14px;
  background: rgba(255, 250, 241, 0.92);
  color: var(--ink);
  font-size: 12px;
  font-weight: 780;
  line-height: 1;
  box-shadow: 0 8px 18px rgba(37, 24, 13, 0.06);
  transition: transform 140ms ease, box-shadow 140ms ease, background 140ms ease;
}
.editorial-tab.active {
  border-color: var(--ink);
  background: var(--ink);
  color: var(--cream);
  box-shadow: 0 12px 24px rgba(37, 24, 13, 0.18);
}
.editorial-tab:active { transform: translateY(1px); }
.editorial-feature {
  --source-accent: var(--food-local);
  margin: 10px 14px 18px;
  overflow: hidden;
  border-radius: var(--radius-xl);
  background: #17120d;
  color: #fffaf1;
  box-shadow: var(--shadow);
}
.editorial-feature-media {
  min-height: 160px;
  background:
    linear-gradient(180deg, rgba(23, 18, 13, 0.02) 0%, rgba(23, 18, 13, 0.08) 48%, rgba(23, 18, 13, 0.36) 100%),
    url("https://images.unsplash.com/photo-1552566626-52f8b828add9?auto=format&fit=crop&w=900&q=80"),
    linear-gradient(135deg, #17120d 0%, var(--source-accent) 72%, #e8b451 100%);
  background-size: cover;
  background-position: center;
}
.editorial-feature-copy {
  padding: 14px;
}
.editorial-feature-label {
  color: var(--gold);
  font-size: 11px;
  font-weight: 860;
  line-height: 1;
}
.editorial-feature h2 {
  margin: 9px 0 8px;
  overflow-wrap: anywhere;
  font-family: Georgia, "Times New Roman", "Songti SC", serif;
  font-size: 29px;
  line-height: 1.02;
  font-weight: 760;
}
.editorial-feature p {
  margin: 0;
  color: rgba(255, 250, 241, 0.78);
  font-size: 13px;
  line-height: 1.55;
  overflow-wrap: anywhere;
}
.editorial-list {
  display: grid;
  gap: 10px;
  padding: 0 14px 18px;
}
.editorial-card {
  --source-accent: var(--food-local);
  position: relative;
  overflow: hidden;
  border: 1px solid var(--line);
  border-radius: var(--radius-lg);
  padding: 12px;
  background:
    linear-gradient(135deg, rgba(255, 250, 241, 0.98), rgba(255, 247, 231, 0.92)),
    rgba(255, 250, 241, 0.94);
  box-shadow: 0 14px 34px rgba(37, 24, 13, 0.1);
}
.editorial-card::before {
  content: "";
  position: absolute;
  inset: 0 auto 0 0;
  width: 6px;
  background: linear-gradient(180deg, var(--source-accent), rgba(216, 166, 63, 0.36));
}
.editorial-card-head {
  display: grid;
  grid-template-columns: 46px minmax(0, 1fr) auto;
  gap: 10px;
  align-items: start;
}
.merchant-avatar {
  position: relative;
  display: grid;
  place-items: center;
  width: 46px;
  height: 46px;
  overflow: hidden;
  border: 1px solid rgba(23, 18, 13, 0.08);
  border-radius: 16px;
  background: var(--cream);
  box-shadow: 0 10px 22px rgba(37, 24, 13, 0.12);
}
.merchant-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.merchant-avatar.multi {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0;
  padding: 5px;
}
.merchant-avatar.multi img {
  width: 25px;
  height: 25px;
  flex: 0 0 auto;
  margin-left: -8px;
  border: 1px solid var(--cream);
  border-radius: 9px;
}
.merchant-avatar.multi img:first-child {
  margin-left: 0;
}
.merchant-avatar-fallback {
  color: #fffaf1;
  font-size: 18px;
  font-weight: 900;
  line-height: 1;
}
.editorial-title { min-width: 0; }
.editorial-title h2 {
  margin: 0;
  overflow-wrap: anywhere;
  font-size: 19px;
  line-height: 1.12;
  font-weight: 860;
}
.editorial-meta {
  margin-top: 7px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.45;
  overflow-wrap: anywhere;
}
.editorial-source-row {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 9px;
}
.editorial-source {
  border-radius: 999px;
  padding: 6px 8px;
  background: rgba(23, 18, 13, 0.06);
  color: var(--source-accent);
  font-size: 10px;
  font-weight: 820;
  line-height: 1;
  overflow-wrap: anywhere;
}
.editorial-expand {
  flex: 0 0 auto;
  appearance: none;
  -webkit-appearance: none;
  border: 0;
  border-radius: 0;
  min-width: 0;
  min-height: 0;
  padding: 2px 0 4px;
  background: transparent;
  color: var(--muted);
  font: inherit;
  font-size: 11px;
  font-weight: 760;
  line-height: 1.2;
  white-space: nowrap;
  box-shadow: none;
  border-bottom: 1px solid rgba(122, 103, 79, 0.34);
}
.editorial-card.expanded .editorial-expand {
  color: var(--source-accent);
  border-bottom-color: currentColor;
}
.editorial-card:not(.expanded) .editorial-detail {
  display: none;
}
.editorial-detail {
  margin-top: 10px;
  border-top: 1px solid var(--line);
  padding-top: 10px;
}
.editorial-detail-grid {
  display: grid;
  gap: 7px;
}
.editorial-detail-row {
  display: grid;
  grid-template-columns: 72px minmax(0, 1fr);
  gap: 10px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.45;
  overflow-wrap: anywhere;
}
.editorial-detail-row b {
  color: var(--ink);
  font-weight: 760;
}
.editorial-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 10px;
}
.editorial-action {
  border: 0;
  border-radius: 999px;
  min-height: 42px;
  padding: 10px 16px;
  background: linear-gradient(135deg, var(--tomato), #a82f1e);
  color: var(--cream);
  font-size: 13px;
  font-weight: 820;
  box-shadow: 0 12px 22px rgba(216, 73, 47, 0.22);
}
.editorial-action.secondary {
  background: linear-gradient(135deg, var(--ink), #3c2b1d);
  color: var(--cream);
  box-shadow: 0 12px 22px rgba(37, 24, 13, 0.2);
}
.editorial-empty {
  border: 1px dashed rgba(23, 18, 13, 0.18);
  border-radius: var(--radius-md);
  padding: 18px;
  background: rgba(255, 250, 241, 0.7);
  color: var(--muted);
  line-height: 1.55;
  overflow-wrap: anywhere;
}
@media (min-width: 620px) {
  .editorial-cover { min-height: 430px; padding: 36px 28px 30px; }
  .editorial-cover h1 { font-size: 58px; }
  .editorial-feature { margin-left: 22px; margin-right: 22px; }
  .editorial-list { padding-left: 22px; padding-right: 22px; grid-template-columns: repeat(2, minmax(0, 1fr)); }
}
@media (max-width: 360px) {
  .editorial-cover h1 { font-size: 40px; }
  .editorial-feature h2 { font-size: 29px; }
  .merchant-avatar { width: 42px; height: 42px; border-radius: 15px; }
  .merchant-avatar img { width: 100%; height: 100%; }
}
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.001ms !important;
    animation-iteration-count: 1 !important;
    scroll-behavior: auto !important;
    transition-duration: 0.001ms !important;
  }
}
`;

const FOOD_HOME_JS: string = `
(function () {
  var node = document.getElementById('home-data');
  var data = {};
  try { data = JSON.parse(node && node.textContent ? node.textContent : '{}') || {}; } catch (error) { data = {}; }
  var app = document.getElementById('app');
  if (!app) { return; }
  var state = { filter: 'all', expandedKey: '', showMore: false };
  var AVATAR_MCDONALDS = 'data:image/jpeg;base64,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';
  var AVATAR_KFC = 'data:image/jpeg;base64,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';
  var AVATAR_TAOBAO = 'data:image/jpeg;base64,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';
  var AVATAR_AMAP = 'data:image/jpeg;base64,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';
  var AVATAR_TENCENT = 'data:image/jpeg;base64,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';
  var AVATAR_BAIDU = 'data:image/jpeg;base64,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';
  var AVATAR_MEITUAN = 'data:image/jpeg;base64,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';
  var AVATAR_LUCKIN = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAASABIAAD/4QB6RXhpZgAATU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAABJKGAAcAAAAiAAAAUKABAAMAAAABAAEAAKACAAQAAAABAAAAYKADAAQAAAABAAAAYAAAAABBU0NJSQAAAEJRQkY0SUJKSExPM0gyNUNWR1VIWkpCV1ZF/8AAEQgAYABgAwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMAAgICAgICAwICAwUDAwMFBgUFBQUGCAYGBgYGCAoICAgICAgKCgoKCgoKCgwMDAwMDA4ODg4ODw8PDw8PDw8PD//bAEMBAgICBAQEBwQEBxALCQsQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEP/dAAQABv/aAAwDAQACEQMRAD8A+GPgL8Ubj4MfGDwt8Sodxh0e8RrpV6vaSfu7hPxiZse+DX2V/wAFKPhNFoPxN0343eGkE3hv4h20Upnj5j+3RxjuOP3sIR19SGI6GvzYr9cP2RfiD4P/AGkvgrqX7GPxeu/Jv4Y2k8OXjY8wJEfMREJ6y27ZKj+KIlegNf1VxHGWFxFPNaauorlmlvyPW/8A269fS58Rg2qkHQfXVev/AAT56/4JvrAf2svDRlxuFnqZTP8Ae+yv/TNfKXxXa5f4qeNWvc/aDrmqeZnru+1yZr3z4f6d4t/ZB/a08NQfESD7BLoOpxx3MvPkz6fdZga4iY9YmjcsD1GCCMgirX7dvwwufhp+0j4leOIrpXilxrNhJ/BIl1zNtPfbNvB/D1FbYfEQ/tbni7xqU1yvvyyd7fKSZM4P2Fnunr81/wAA+O6KKK+sOAKKKKACuu8Y+AvGfw+vbPTvG+jXOi3OoWsd7bx3KFGltps7JF9QcEexBBwa7P8AZ/8AhlffGH4y+E/h7ZRmRNSvY2uiP4LOA+bcMT2xGrAe5FfXP7VVj4l/ap/bRvPhz8MIPtx0dINFhcDEFtFaZN1NIRwsUUsjgnvgAZJArw8XnCpYuOHdlFRc5N9Emkvv1+46qeH5qbl1vZH5x7l3bcjcOcd6dX6a/ttWHwT+Cvw28J/sv+AbC21HxRosqahq2r+Wn2pGdGyski8l5y24oSQkYUelfmVXRk+ZrGUFiIwcYu9r9V0fz3IxFH2cuS9z/9D8u60NJ1bVNB1S01vRLuWw1CwlWa3uIWKSxSocq6MOQQaz6K/ttpNWZ+bpn7J+CPi78GP29fA1n8I/j+8Phr4m6dH5elaym2MXMpGN0RbChnIHmWzHD9YznG31rxd+zB48+Lnwag+AfxXRE8deAUZvC3ihFL2eqWaDasMr8tE+wKksb/NlVkXeA1fgrGJDIghDGTcNu3O7dnjGOc56Yr9bP2bf2hP26PAejWdvqvw5134h+EVQCE3VnOl5HGOnlXRQtIAOgkDegYV+W8QcO18GlUy6oopPmjGTS5ZdeRvo+sXo/uPcwmLjU0qq/RtdV5/5n5c+NPBPiz4d+JLzwh430ufR9YsGKy2867W9mU9HRuqspKkdDXLV/Ql8QvjN+yF8edNh8PftKeF9S8EalENsL+IdOn0+eBj1EN9ECoGezOFPoa8q1L/glH8PfEATWvAfxFvbXSr1FmtluLSO7/duNykSq8O4EHglc16GE8QaMIJZlTlSl6Nxf+Fq/wDXVmNTKZN/uWpL8T8Qq0NK0nVNd1K20XQ7ObUNQvXEUFvbxtLLK7dFRFBJP0r9bNY/4J1fAb4d3qQ/FX45Q6WQA7QSRW1jK0fqpmmkP47DXo3hb46f8E+P2SoZH+FEM3i7xAUKPfWsTXly/wDs/a5/LiRT3EXHqK663G9KpD/hPpTqye1otR+baWhEcskn+9kor1O1/Zg/ZD8ffAT4Zahr2nwW4+LPjKEWiXM5DW2gWknJLFcmSRPvsqffcImQis9eR+P/AIyfB/8AYU8H6l8MfgbPH4t+K2shv7Z12YrM0Nw2S0k7DILqzEpbg4U8yEnO75o+PP8AwUW+M/xbgufD/hHHgbw9OCjx2che+mQ/89LrClMjqIgvuxr8/CSzF2JLMSSTyST1JPrXlZTwljMTOWIzeS95puC622Un2j0itOrbZvXx9OCUcOtuv+X+Zf1bV9U1/VLvXNcu5b/Ub+Vpri4nYvLLK5yzux5JJrPoor9MSSVkeK2f/9H8u6KKK/tw/NzT0XWdU8OaxY+INDuWs9R02aO4t50xujliYMjDORwR3GPWv2W+Cf8AwVUsF0+DRvjzoUq3cQCnVdKQOkuON0tsxDKx6kxlgf7q1+K1W7CwvdVv7bStNiM95eypBDGoyXllYKij6kgV4Oe8OYPMIKOKhe2z2a+f+eh1YXGVKTvBn9PHw2/aPtP2mFv0+D3hlrvQdNkWO41fXo/Js/OwG8qG3XdLLIFIJzsVQQSxOFP11Hv8tfNAD4G4LyM98Z7V5F8BPhNpPwR+E3h34c6Si5022U3UoUAz3cnzzytjqWcnGc4GBnivYK/lTNqmHdaUcLG1NPS+rfm/XysfcUFLlTnucD49+Fnw5+KOmf2R8QvDljr9qPui6hV2Q+qP99D7qwNfA3jz9l39gfR59U1WfS1gfQbSee7hsru+ltIdsZINy8bSJE2R8oZ0yccHOKi+Ov8AwU28A/DPxTqPgvwD4fl8YX2lu9vcXZuBbWS3CHayIwSRpQpGGIAGeAT1r8wvjh+3J8a/jhot34RvXtPDfhm9bdNp+mRlPPGd22aZiXcZ5IG0E9Qa/ReFOE85fK+aVOm/79tP8Ku9u6XqeTjsdh1fRN+n6nxxkN8ygqDyAeoHYGiiiv6EPkwooooA/9L8u6K951n4G3y7pvDeoR3ado5vkk+m4fKf0ryXV/C3iLQWI1fT5rcD+MrlD9GXK/rX9d5RxVl2OS+rVk322f3OzPyejmlCdR0XLlmt4yTjJesXZ/gYFfav/BPv4eQ/EH9p/wANm9TfZ+G0m1mUEZBe1AEA/wC/zofwNfFIIPTmv2K/4JIeF45dd+InjSRcvbW9jp8Z9BM0kr4/79rWHGmNeHyuvUT1tb/wLT9T3cupc9eK/rQ/bevMvjVrl/4Z+D3jjxFpTMl7puiajcQMhwyyx27sjA+oIBr02sjxBodh4m0HUvDeqqXstVtprSdQcExToY3AP+6TX8pYacY1IymrpNXPuZptNI/jVDtIPMclmbkk8kk9SaWvcvj7+z/48/Z68a3nhfxfYyDT/Nf+z9RCH7NeW4PyOj9A23G9DyrcYxgnw33r+zsLiqdenGrRleL1TR+eTg4txktQooorcgKKv6dpepatMLfTLaS6kPaNScfU9B+NeqaP8JLrC3Hie8Syj6+VGQ8p/HoP1rwM74owGXR5sXVUfLd/ctTfC4WrXqxo0IOc3soptv0S1P/T8bMuz5gcY71RfxHeIxSJw8fQhxkGqVvNaanqltYXt8um2UsipLdOjyLEhPLskYLsFHOFBJ7V9XP+y14fHw+0nxRF4wuLu616V5bOS20PUp7drKMbSzpHA0qsz/cLAKy8jPWvg8Oqru6T287H978c4Dh/FRhRz3DRqqWkeanz/c+V20TejTtqfHWoaf4Q1os2raHD5jdZLcmF/r8vX8a+pv2Wvj9oX7M1nrWk6PpD6nZa7cRXE3nylJUaJCgVGVWBGCTyOtYWhfArwzqfj+PwBd+NZIruSxubwkaRdQvH9ljadkkivPIcbolZlZQQSMHGc11egfszaL4j8PjW9K8WxSC9sLW5sxPttn8+W5KTRyxneQEth5qkNyx29s19JT4kzaVF4Z1nKD6N3Wmvc/Cs+8IuBcMniKcquGsk7wlUslK6Vo1Izir2eij02PvTw5+318KdXU/2ppmo2Lr1MapOg+pBRv8Ax2u5t/22P2fJxltbmiPo9rLn9Aa/MGx+Br6zqGv6RoNzqz6JpN/JZW9/a6NLdreiPq52yR+WcEHBzkEEcV0XxT/ZNPg671KPwrd61rAs7SO4iQaOzxyMYg7KblJAigHIPyHbjByRms3mFdK6in/XQ+FyLw0o16s1iMdKkpP93GdNSnyq2tRw5Ipyumor4V8Tvt+h+vftbfsx67ps2la/qC6pZTjElvPYSTRuPdXQg18c+N9S/wCCcWrmWf8A4V201w+Tu06J9O5/4BPCv/jp+leLaX+zdZap8O4vE8GramdTu7ZL+EDRpvsX2Yx5IMhcfx8ebxGBkmofiN+zY3g99Lt7LVtt1qFzpls0V20QRBf2yyPL5kbN8scxaPbtyRgjOa6cNxJmGHXNh24+kmvyZ9LR8IMqqVvY1sxbd2v4VtrX+Jy79jxz4keFv2XdXt5E+HnhvWNBuSfklk1P7RGPrC0LE/8AfyvJrLwh4I0zDJYyX8i/xXL5XP8AuDA/Ovt+X9mLwmdZguYfFN7Doj372Btr3TXstUlkS2MyLbxzsqStMR+7zsBGecjB8z8d/CXwJ8OvFWneHvE/i+8t1vLA3lwg0xWvbGR2Hk29xALjCu6Zc/PlRjI+bjrxXHWfTp8ksTJR/wAX63ue/kfhBwc6qjOVWtK1+VqS230hCL09X0Wt0eKDVJYoRb2aJaQjgJEoQfpVEyM5LMSSepJzX1H4C+Anw2+IaXl7pPjrUbLSdNRpLvU7/RktrCDaM7Xna6I3t0CLlj6Y5r5n12HSdP1q/sdDvzqmn288kdvdmMw+fErELJ5ZJK7hzgnivi8S6r9+o7387n7jwlg8lwkp4XKaCpuNua0HF67XbSu/Jtu2p//U+ZdJ1GDSdVtdUurGHU4bSRZWtbjd5M2znZJsKsVPcAjI4r9Ovi14+8PPq3gy212W0XW9X8OaRMtutpqzs73KHasSafdQxYLEhUCbh0yeK/LJGWVFkQhkcZBByCDWrC+pX9zFK9xKzwBQsrOxaNU+6FJORjsB07V8JQrSp3hbU/vnirKcNX5MfiKvJGmpars7W7/gry0XY/T691G90r9r/V9aj1ez0TTbHwvbQ6hNeSpAsbS6cywJtuC0m5ZtpKjLj+LPOe38Pa02leBv+EbsM6zc3+m20zSpf32+9n+yXF0rW4SaNkR5Y1AWJUyp246AfkhqN+ZMwRMZMnLyOSzu3cljyfrWf9svhJFMLiUSQACNvMbcgX7oU5yuO2Onaux5koNpLdv8T84y/wAOa+ZRpYrFS9nGEYxhG2r5E7TnZq0nd2jf3U97n3Zea14O+H3xd8fS3Wq6GLqW+nsVg16PWL+eO1eBI3QSQMysGyQC7NIpHUYFdL8dLT4WeC01T4QaRceHND09Y4L+NJ4Namv47q4tFIlEyF4zkN+7VsqAfmGc1+c7tJK7SyMXdiSWY5JJ6kk9TU11dXl9Mbm+nkuZiAC8rl2IUYA3MScAcCuX69o1yrU++jwR++pVZYifuxSe2rXLyvZ7We9372+9/wBLdIsLDVPhLptg1zYQeI77S7PwVZ60YJDCq3tpPLLZh/NMbhJAkcs6ofLZmBGBmsj45yaLrV58Mvi/4YtY28KeEpY7S91KNVBkj0+9itkOR80jMIyyLy2znGM1+c/n3JijgMrmKIkom47VLdSq5wM98U3zJvK8je3lA52bjtz646Z96qWPTjy8v9Iwo8ByhiI4j2+zlpbS0k1Jb+jXRO+jufrn4Y8XLJoXhvWvDdve61GdREVndCzbypTFZvm7aO48uQ2kbuqvIHiOeN+Mhvgn9o26+HTeKLXTvBMVnNqVmkza5qVg9w9ne38sm5vI+0SSMUjHG7OGYnHAFeD/AGy+8o2/2mXyiuzZ5jbdhIJXGcbcgHHTNVtuBjFTiMdzx5bHTkPBMcDiniVVb302vvbm11sntZK+ttrfXHjnRdZ8L/sh+D9E8R2kumXt34ou7uO3uFMUklu1t8koRsEoezYx0xXyXbWk13KIoup6nsB6mrC/bdRlSOSV5iowC7Ftq+2TwKsXd3BY27W1swVFBMkhOM468+lZv9407aaL1Mq2JrYNSwOEanXnKU27WjTUm3zS1ei6K95NdFe3/9k=';
  var AVATAR_GOOGLE_MAPS = 'data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 64 64%22%3E%3Crect width=%2264%22 height=%2264%22 rx=%2218%22 fill=%22%23fff%22/%3E%3Cpath d=%22M32 7c-10 0-18 8-18 18 0 13 18 32 18 32s18-19 18-32c0-10-8-18-18-18z%22 fill=%22%23ea4335%22/%3E%3Ccircle cx=%2232%22 cy=%2225%22 r=%226%22 fill=%22%23fff%22/%3E%3Cpath d=%22M15 51h34%22 stroke=%22%234285f4%22 stroke-width=%226%22 stroke-linecap=%22round%22/%3E%3C/svg%3E';
  var AVATAR_LOCAL = 'data:image/svg+xml;base64,PHN2ZyBmaWxsPSJub25lIiByb2xlPSJpbWciIHZpZXdCb3g9IjAgMCA2NCA2NCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iNjQiIGhlaWdodD0iNjQiIHJ4PSIxOCIgZmlsbD0iIzgxNUYzRSIvPjxwYXRoIGQ9Ik0yMCAyMWgyNE0yMCAzMmgyNE0yMCA0M2gxNSIgc3Ryb2tlPSIjRkZGIiBzdHJva2Utd2lkdGg9IjUiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIvPjwvc3ZnPgo=';
  function text(value) { return value === undefined || value === null ? '' : String(value); }
  function list(value) { return Array.isArray(value) ? value : []; }
  var isBusy = text(data.isBusy).toLowerCase() === 'true';
  function add(parent, tag, className, value) {
    var el = document.createElement(tag);
    if (className) { el.className = className; }
    if (value !== undefined && value !== null && text(value).length > 0) { el.textContent = text(value); }
    parent.appendChild(el);
    return el;
  }
  function metric(block, labels) {
    var items = list(block && block.metrics).concat(list(block && block.rows));
    for (var i = 0; i < items.length; i += 1) {
      var label = text(items[i] && items[i].label);
      if (labels.indexOf(label) >= 0) { return text(items[i] && items[i].value); }
    }
    return '';
  }
  function numberIn(value) {
    var match = text(value).replace(/,/g, '').match(/[0-9]+(?:\\.[0-9]+)?/);
    return match ? Number(match[0]) : Number.NaN;
  }
  function distanceMeters(value) {
    var raw = text(value).toLowerCase();
    var n = numberIn(raw);
    if (!(n >= 0)) { return Number.POSITIVE_INFINITY; }
    return raw.indexOf('km') >= 0 || raw.indexOf('公里') >= 0 ? n * 1000 : n;
  }
  function sourceParts(block) {
    var raw = text(block && block.source) || metric(block, ['source', 'provider', 'sourceTag']);
    return raw.split(/[\\/|,，、]+/).map(function (part) { return part.trim(); }).filter(Boolean);
  }
  function sourceKey(block) {
    var parts = sourceParts(block);
    if (parts.length > 1) { return 'food-local'; }
    var raw = [parts.join(' '), text(block && block.title), text(block && block.subtitle)].join(' ').toLowerCase();
    if (raw.indexOf('amap') >= 0 || raw.indexOf('gaode') >= 0 || raw.indexOf('高德') >= 0) { return 'food-amap'; }
    if (raw.indexOf('tencent') >= 0 || raw.indexOf('腾讯') >= 0) { return 'food-tencent'; }
    if (raw.indexOf('baidu') >= 0 || raw.indexOf('百度') >= 0) { return 'food-baidu'; }
    if (raw.indexOf('meituan') >= 0 || raw.indexOf('美团') >= 0) { return 'food-meituan'; }
    if (raw.indexOf('taobao') >= 0 || raw.indexOf('淘宝') >= 0 || raw.indexOf('闪购') >= 0) { return 'food-taobao'; }
    if (raw.indexOf('mcd') >= 0 || raw.indexOf('mcdonald') >= 0 || raw.indexOf('麦当劳') >= 0) { return 'food-mcd'; }
    if (raw.indexOf('kfc') >= 0 || raw.indexOf('肯德基') >= 0) { return 'food-kfc'; }
    if (raw.indexOf('luckin') >= 0 || raw.indexOf('瑞幸') >= 0) { return 'food-luckin'; }
    if (raw.indexOf('google maps') >= 0 || raw.indexOf('google places') >= 0) { return 'food-google-maps'; }
    return 'food-local';
  }
  function avatarData(block) {
    var parts = sourceParts(block);
    if (parts.length > 1) { return AVATAR_LOCAL; }
    var raw = [parts.join(' '), text(block && block.title), text(block && block.subtitle)].join(' ').toLowerCase();
    if (raw.indexOf('mcd') >= 0 || raw.indexOf('mcdonald') >= 0 || raw.indexOf('麦当劳') >= 0) { return AVATAR_MCDONALDS; }
    if (raw.indexOf('kfc') >= 0 || raw.indexOf('肯德基') >= 0) { return AVATAR_KFC; }
    if (raw.indexOf('taobao') >= 0 || raw.indexOf('淘宝') >= 0 || raw.indexOf('闪购') >= 0) { return AVATAR_TAOBAO; }
    if (raw.indexOf('amap') >= 0 || raw.indexOf('gaode') >= 0 || raw.indexOf('高德') >= 0) { return AVATAR_AMAP; }
    if (raw.indexOf('tencent') >= 0 || raw.indexOf('腾讯') >= 0) { return AVATAR_TENCENT; }
    if (raw.indexOf('baidu') >= 0 || raw.indexOf('百度') >= 0) { return AVATAR_BAIDU; }
    if (raw.indexOf('meituan') >= 0 || raw.indexOf('美团') >= 0) { return AVATAR_MEITUAN; }
    if (raw.indexOf('luckin') >= 0 || raw.indexOf('瑞幸') >= 0) { return AVATAR_LUCKIN; }
    if (raw.indexOf('google maps') >= 0 || raw.indexOf('google places') >= 0) { return AVATAR_GOOGLE_MAPS; }
    return AVATAR_LOCAL;
  }
  function avatarInitial(block) {
    var raw = text(block && block.title).trim() || sourceParts(block).join('').trim() || '食';
    return raw.slice(0, 1);
  }
  function addAvatar(parent, block) {
    var wrap = add(parent, 'div', 'merchant-avatar');
    var sources = sourceParts(block);
    if (sources.length > 1) {
      wrap.className += ' multi';
      sources.slice(0, 3).forEach(function (source) {
        var sourceAvatar = avatarData({ source: source });
        if (sourceAvatar === AVATAR_LOCAL) { return; }
        var sourceImg = add(wrap, 'img');
        sourceImg.src = sourceAvatar;
        sourceImg.alt = '';
        sourceImg.setAttribute('aria-hidden', 'true');
      });
      if (wrap.children.length > 0) { return; }
    }
    var src = avatarData(block);
    if (src.length > 0) {
      var img = add(wrap, 'img');
      img.src = src;
      img.alt = '';
      img.setAttribute('aria-hidden', 'true');
      return;
    }
    add(wrap, 'span', 'merchant-avatar-fallback', avatarInitial(block));
  }
  function hasLocation(block) {
    return text(metric(block, ['location'])).length > 0;
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
    } catch (error) {}
  }
  function setExpanded(key) {
    state.expandedKey = state.expandedKey === key ? '' : key;
    Array.prototype.slice.call(document.querySelectorAll('.editorial-card')).forEach(function (card) {
      var expanded = card.getAttribute('data-card-key') === state.expandedKey;
      card.classList.toggle('expanded', expanded);
      card.setAttribute('aria-expanded', expanded ? 'true' : 'false');
      var button = card.querySelector('.editorial-expand');
      if (button) { button.textContent = expanded ? '收起' : '展开'; }
    });
  }
  function matchesFilter(node) {
    var haystack = text(node.getAttribute('data-search')).toLowerCase();
    if (state.filter === 'featured') { return node.getAttribute('data-featured') === 'true'; }
    if (state.filter === 'within_1km') { return distanceMeters(node.getAttribute('data-distance')) <= 1000; }
    if (state.filter === 'source') { return text(node.getAttribute('data-sources')).length > 0; }
    if (state.filter === 'coffee') { return haystack.indexOf('咖啡') >= 0 || haystack.indexOf('coffee') >= 0 || haystack.indexOf('瑞幸') >= 0 || haystack.indexOf('luckin') >= 0; }
    if (state.filter === 'late') { return haystack.indexOf('深夜') >= 0 || haystack.indexOf('夜') >= 0 || haystack.indexOf('宵夜') >= 0; }
    if (state.filter === 'group') { return haystack.indexOf('聚餐') >= 0 || haystack.indexOf('火锅') >= 0 || haystack.indexOf('烧烤') >= 0; }
    if (state.filter === 'light') { return haystack.indexOf('轻食') >= 0 || haystack.indexOf('沙拉') >= 0 || haystack.indexOf('简餐') >= 0; }
    return true;
  }
  function applyFilter() {
    var cards = Array.prototype.slice.call(document.querySelectorAll('.editorial-card'));
    var feature = document.querySelector('.editorial-feature');
    if (feature) { feature.style.display = matchesFilter(feature) ? '' : 'none'; }
    var visible = 0;
    cards.forEach(function (card) {
      var keep = matchesFilter(card);
      if (keep && !state.showMore && visible >= 6) { keep = false; }
      if (keep) { visible += 1; }
      card.style.display = keep ? '' : 'none';
    });
    var count = document.getElementById('editorial-count');
    if (count) { count.textContent = String(visible) + ' / ' + String(cards.length) + ' 条'; }
    var empty = document.getElementById('editorial-filter-empty');
    if (empty) { empty.style.display = cards.length > 0 && visible === 0 ? '' : 'none'; }
    Array.prototype.slice.call(document.querySelectorAll('.editorial-tab')).forEach(function (button) {
      var actionId = button.getAttribute('data-action');
      var active = button.getAttribute('data-filter') === state.filter;
      if (actionId === 'food_show_all') { active = state.filter === 'all' && !state.showMore; }
      if (actionId === 'food_show_more') { active = state.filter === 'all' && state.showMore; }
      button.classList.toggle('active', active);
    });
  }
  function handleFilter(action) {
    var id = text(action && action.id);
    if (id === 'food_filter_featured') { state.filter = 'featured'; applyFilter(); return true; }
    if (id === 'food_filter_1km') { state.filter = 'within_1km'; applyFilter(); return true; }
    if (id === 'food_filter_source') { state.filter = 'source'; state.showMore = true; applyFilter(); return true; }
    if (id === 'food_filter_coffee') { state.filter = 'coffee'; state.showMore = true; applyFilter(); return true; }
    if (id === 'food_filter_late') { state.filter = 'late'; state.showMore = true; applyFilter(); return true; }
    if (id === 'food_filter_group') { state.filter = 'group'; state.showMore = true; applyFilter(); return true; }
    if (id === 'food_filter_light') { state.filter = 'light'; state.showMore = true; applyFilter(); return true; }
    if (id === 'food_show_all') { state.filter = 'all'; state.showMore = false; applyFilter(); return true; }
    if (id === 'food_show_more') { state.showMore = true; state.filter = 'all'; applyFilter(); return true; }
    return false;
  }
  function detailRow(parent, label, value) {
    if (text(value).length === 0) { return; }
    var row = add(parent, 'div', 'editorial-detail-row');
    add(row, 'b', '', label);
    add(row, 'span', '', value);
  }
  app.textContent = '';
  var shell = add(app, 'main', 'editorial-food-shell');
  var blocks = list(data.blocks).filter(function (block) { return text(block && block.kind) === 'food-result'; });
  var hero = add(shell, 'header', 'editorial-cover');
  add(hero, 'div', 'editorial-cover-media');
  var heroContent = add(hero, 'div', 'editorial-cover-content');
  add(heroContent, 'div', 'editorial-kicker', '附近餐饮 · 今日编辑');
  add(heroContent, 'h1', '', '今日附近值得吃');
  add(heroContent, 'p', '', text(data.subtitle) || text(data.title) || '从真实餐饮结果里挑出今天可以出发的一餐。');
  var sourceCloud = add(hero, 'div', 'source-cloud');
  var seenSources = {};
  blocks.forEach(function (block) {
    sourceParts(block).forEach(function (source) {
      if (seenSources[source]) { return; }
      seenSources[source] = true;
      var pill = add(sourceCloud, 'span', 'source-pill', source);
      pill.setAttribute('data-source-key', sourceKey({ source: source }));
    });
  });
  if (Object.keys(seenSources).length === 0) { sourceCloud.style.display = 'none'; }
  var stats = add(hero, 'div', 'cover-stats');
  var count = add(stats, 'span', 'cover-stat', String(blocks.length) + ' 条');
  count.id = 'editorial-count';
  add(stats, 'span', 'cover-stat', String(blocks.filter(hasLocation).length) + ' 家可导航');
  var tabs = add(shell, 'nav', 'editorial-tabs');
  [
    ['food_show_all', '全部', 'all'],
    ['food_filter_featured', '精选', 'featured'],
    ['food_filter_1km', '1公里内', 'within_1km'],
    ['food_filter_source', '来源', 'source'],
    ['food_show_more', '展示更多', 'all'],
    ['food_filter_coffee', '咖啡', 'coffee'],
    ['food_filter_late', '深夜', 'late'],
    ['food_filter_group', '聚餐', 'group'],
    ['food_filter_light', '轻食', 'light']
  ].forEach(function (item) {
    var button = add(tabs, 'button', 'editorial-tab', item[1]);
    button.type = 'button';
    button.disabled = isBusy;
    button.setAttribute('data-action', item[0]);
    button.setAttribute('data-filter', item[2]);
    button.addEventListener('click', function () { handleFilter({ id: item[0], label: item[1] }); });
  });
  if (blocks.length > 0) {
    var featureBlock = blocks[0];
    var feature = add(shell, 'section', 'editorial-feature');
    feature.setAttribute('data-card-key', text(featureBlock.id) || '0');
    feature.setAttribute('data-source-key', sourceKey(featureBlock));
    feature.setAttribute('data-distance', metric(featureBlock, ['distance']));
    feature.setAttribute('data-featured', 'true');
    feature.setAttribute('data-sources', sourceParts(featureBlock).join(' / '));
    feature.setAttribute('data-search', [text(featureBlock.title), text(featureBlock.subtitle), metric(featureBlock, ['category']), metric(featureBlock, ['address']), sourceParts(featureBlock).join(' ')].join(' '));
    add(feature, 'div', 'editorial-feature-media');
    var featureCopy = add(feature, 'div', 'editorial-feature-copy');
    add(featureCopy, 'div', 'editorial-feature-label', '今日编辑');
    add(featureCopy, 'h2', '', text(featureBlock.title) || '餐饮结果');
    add(featureCopy, 'p', '', [metric(featureBlock, ['distance']), metric(featureBlock, ['address']), sourceParts(featureBlock).join(' / ')].filter(Boolean).join(' · '));
  }
  var listNode = add(shell, 'section', 'editorial-list');
  var empty = add(listNode, 'div', 'editorial-empty', '当前筛选下暂无匹配餐饮。');
  empty.id = 'editorial-filter-empty';
  empty.style.display = 'none';
  blocks.forEach(function (block, index) {
    var key = text(block.id) || String(index);
    var card = add(listNode, 'article', 'editorial-card');
    card.setAttribute('data-card-key', key);
    card.setAttribute('data-source-key', sourceKey(block));
    card.setAttribute('data-distance', metric(block, ['distance']));
    card.setAttribute('data-featured', index === 0 ? 'true' : 'false');
    card.setAttribute('data-sources', sourceParts(block).join(' / '));
    card.setAttribute('data-search', [text(block.title), text(block.subtitle), metric(block, ['category']), metric(block, ['address']), sourceParts(block).join(' ')].join(' '));
    card.setAttribute('aria-expanded', 'false');
    var head = add(card, 'div', 'editorial-card-head');
    addAvatar(head, block);
    var title = add(head, 'div', 'editorial-title');
    add(title, 'h2', '', text(block.title) || '餐饮结果');
    add(title, 'div', 'editorial-meta', [metric(block, ['distance']), metric(block, ['address'])].filter(Boolean).join(' · '));
    var expand = add(head, 'button', 'editorial-expand', '展开');
    expand.type = 'button';
    expand.addEventListener('click', function (event) { event.stopPropagation(); setExpanded(key); });
    card.addEventListener('click', function () { setExpanded(key); });
    var sources = sourceParts(block);
    if (sources.length > 0) {
      var sourceRow = add(card, 'div', 'editorial-source-row');
      sources.forEach(function (source) { add(sourceRow, 'span', 'editorial-source', source); });
    }
    var detail = add(card, 'div', 'editorial-detail');
    var grid = add(detail, 'div', 'editorial-detail-grid');
    detailRow(grid, '地址', metric(block, ['address']));
    detailRow(grid, '分类', metric(block, ['category']) || text(block.subtitle));
    detailRow(grid, '距离', metric(block, ['distance']));
    detailRow(grid, '坐标', metric(block, ['location']));
    detailRow(grid, '来源', sourceParts(block).join(' / '));
    var canNavigate = hasLocation(block);
    var availableActions = list(block.actions).filter(function (action) {
      var id = text(action && action.id);
      if (id !== 'html_open_food_map' && id !== 'html_pin_food') { return false; }
      if (!canNavigate) { return false; }
      return true;
    });
    if (availableActions.length > 0) {
      var row = add(detail, 'div', 'editorial-actions');
      availableActions.forEach(function (action) {
        var id = text(action && action.id);
        var button = add(row, 'button', id === 'html_open_food_map' ? 'editorial-action' : 'editorial-action secondary',
          id === 'html_open_food_map' ? '导航去' : '固定到桌面');
        button.type = 'button';
        button.disabled = isBusy;
        button.addEventListener('click', function (event) { event.stopPropagation(); postAction(action); });
      });
    }
  });
  applyFilter();
})();
`;

export function shouldRenderFoodHomeDocument(document: HtmlHomeDocument): boolean {
  if (document.kind !== 'food') {
    return false;
  }
  const blocks = document.blocks;
  for (let index = 0; index < blocks.length; index++) {
    if (blocks[index].kind === 'food-result') {
      return true;
    }
  }
  return false;
}

export function renderFoodHomeDocument(document: HtmlHomeDocument, isBusy: boolean = false): string {
  const renderDocument: HtmlFoodHomeDocumentWithBusy = {
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
    history: [],
    rawSurfaceRoot: null,
    generatedAt: '',
    isBusy: isBusy || (document as HtmlFoodHomeDocumentWithBusy).isBusy === true
  };
  const json = escapeScriptJson(JSON.stringify(renderDocument));
  const title = escapeHtmlText(document.title.length > 0 ? document.title : '今日附近值得吃');
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${title}</title>
<style>${FOOD_HOME_CSS}</style>
</head>
<body>
<div id="app"></div>
<script id="home-data" type="application/json">${json}</script>
<script>${FOOD_HOME_JS}</script>
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

function escapeHtmlText(value: HtmlFoodTextValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  return value.toString()
    .split('&').join('&amp;')
    .split('<').join('&lt;')
    .split('>').join('&gt;')
    .split('"').join('&quot;');
}
