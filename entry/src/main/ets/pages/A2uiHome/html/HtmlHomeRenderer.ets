import { HtmlHomeDocument } from './HtmlHomeTypes';
import { renderCalendarHomeDocument, shouldRenderCalendarHomeDocument } from './HtmlCalendarHomeRenderer';
import { renderFoodHomeDocument, shouldRenderFoodHomeDocument } from './HtmlFoodHomeRenderer';
import { renderMediaHomeDocument, shouldRenderMediaHomeDocument } from './HtmlMediaHomeRenderer';
import { renderTravelHomeDocument, shouldRenderTravelHomeDocument } from './HtmlTravelHomeRenderer';

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
  --gmail: #c24636;
  --gmail-soft: rgba(194, 70, 54, 0.12);
  --qqmail: #2d78c4;
  --qqmail-soft: rgba(45, 120, 196, 0.12);
  --youtube: #c4302b;
  --youtube-soft: rgba(196, 48, 43, 0.12);
  --bilibili: #2d8fbd;
  --bilibili-soft: rgba(45, 143, 189, 0.12);
  --social-x: #111111;
  --social-x-soft: rgba(17, 17, 17, 0.1);
  --social-slack: #4a154b;
  --social-slack-soft: rgba(74, 21, 75, 0.12);
  --social-wecom: #2368d8;
  --social-wecom-soft: rgba(35, 104, 216, 0.12);
  --mail-inbox-icon: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='22 12 16 12 14 15 10 15 8 12 2 12'/%3E%3Cpath d='M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z'/%3E%3C/svg%3E");
}
* { box-sizing: border-box; }
body {
  margin: 0;
  min-height: 100dvh;
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
.block[data-kind="social-hub-item"],
.block[data-kind="social-hub-connection"],
.block[data-kind="social-hub-draft"] {
  border-color: rgba(42, 124, 255, 0.24);
}
.block[data-kind="social-hub-draft"] {
  background: rgba(36, 126, 94, 0.08);
}
.block[data-source-key="mail-gmail"] {
  --kind-accent: var(--gmail);
  --kind-soft: var(--gmail-soft);
  border-color: rgba(194, 70, 54, 0.45);
}
.block[data-source-key="mail-qq"] {
  --kind-accent: var(--qqmail);
  --kind-soft: var(--qqmail-soft);
  border-color: rgba(45, 120, 196, 0.45);
}
.block[data-source-key="media-youtube"] {
  --kind-accent: var(--youtube);
  --kind-soft: var(--youtube-soft);
  border-color: rgba(196, 48, 43, 0.45);
}
.block[data-source-key="media-bilibili"] {
  --kind-accent: var(--bilibili);
  --kind-soft: var(--bilibili-soft);
  border-color: rgba(45, 143, 189, 0.45);
}
.block[data-source-key="social-x"] {
  --kind-accent: var(--social-x);
  --kind-soft: var(--social-x-soft);
}
.block[data-source-key="social-slack"] {
  --kind-accent: var(--social-slack);
  --kind-soft: var(--social-slack-soft);
}
.block[data-source-key="social-wecom"] {
  --kind-accent: var(--social-wecom);
  --kind-soft: var(--social-wecom-soft);
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
  align-items: center;
  gap: 5px;
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
.kind-tag .mail-source-icon {
  width: 18px;
  height: 18px;
  border-radius: 5px;
  background: white;
  object-fit: cover;
  box-shadow: 0 0 0 1px rgba(33, 27, 23, 0.1);
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
.google-map-preview {
  position: relative;
  overflow: hidden;
  margin-top: 12px;
  border: 1px solid var(--line);
  border-radius: 14px;
  background:
    radial-gradient(circle at 28% 22%, rgba(65, 95, 155, 0.18), transparent 23%),
    radial-gradient(circle at 72% 68%, rgba(135, 98, 59, 0.16), transparent 25%),
    linear-gradient(135deg, rgba(255, 255, 255, 0.94), rgba(237, 242, 247, 0.92));
  aspect-ratio: 16 / 9;
}
.google-map-preview::before {
  content: "";
  position: absolute;
  inset: 0;
  background:
    linear-gradient(90deg, rgba(33, 27, 23, 0.05) 1px, transparent 1px),
    linear-gradient(0deg, rgba(33, 27, 23, 0.05) 1px, transparent 1px);
  background-size: 34px 34px;
  pointer-events: none;
}
.google-map-preview::after {
  content: "Maps";
  position: absolute;
  left: 14px;
  top: 14px;
  z-index: 2;
  border-radius: 10px;
  padding: 8px 10px;
  background: rgba(255, 255, 255, 0.82);
  color: #2563af;
  font-weight: 760;
  box-shadow: 0 8px 18px rgba(44, 34, 26, 0.1);
}
.google-map-preview iframe {
  display: block;
  position: relative;
  z-index: 1;
  width: 100%;
  height: 100%;
  border: 0;
  opacity: 0.18;
}
.media-player {
  overflow: hidden;
  margin-top: 12px;
  border: 1px solid var(--line);
  border-radius: 14px;
  background: #0f0d0b;
  aspect-ratio: 16 / 9;
  box-shadow: 0 12px 28px rgba(20, 14, 10, 0.16);
}
.media-player iframe {
  display: block;
  width: 100%;
  height: 100%;
  border: 0;
  background: #0f0d0b;
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
body[data-scene] {
  --scene-accent: #995f4c;
  --scene-accent-2: #476f9f;
  --scene-bg: #f5f2ee;
  --scene-panel: rgba(255, 255, 255, 0.78);
  --scene-image: url('https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=1200&q=80');
  background:
    radial-gradient(circle at 12% 0%, rgba(255, 255, 255, 0.9), transparent 31%),
    linear-gradient(180deg, rgba(255, 255, 255, 0.5), transparent 44%),
    var(--scene-bg);
}
body[data-scene="gmail"] {
  --scene-accent: #c24636;
  --scene-accent-2: #476f9f;
  --scene-bg: #f7f3ee;
  --scene-image: url('https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=1200&q=80');
}
body[data-scene] .shell {
  padding: 12px 12px calc(96px + env(safe-area-inset-bottom, 0px));
}
body[data-scene] .hero {
  position: relative;
  isolation: isolate;
  display: grid;
  gap: 14px;
  overflow: hidden;
  min-height: 312px;
  border: 1px solid rgba(33, 27, 23, 0.1);
  border-radius: 28px;
  padding: 18px;
  background:
    linear-gradient(142deg, rgba(24, 20, 16, 0.86), rgba(24, 20, 16, 0.46) 52%, rgba(255, 255, 255, 0.06)),
    var(--scene-image) center/cover;
  color: #fffaf4;
  box-shadow: 0 24px 54px rgba(44, 34, 26, 0.18);
}
body[data-scene] .hero::after {
  content: "";
  position: absolute;
  inset: auto -16% -22% 18%;
  height: 46%;
  border-radius: 999px;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.38), transparent 64%);
  filter: blur(8px);
  z-index: -1;
}
.hero-copy {
  position: relative;
  z-index: 1;
}
body[data-scene] .eyebrow {
  display: inline-flex;
  width: fit-content;
  border: 1px solid rgba(255, 255, 255, 0.26);
  border-radius: 999px;
  padding: 7px 10px;
  background: rgba(255, 255, 255, 0.12);
  color: rgba(255, 250, 244, 0.88);
  backdrop-filter: blur(12px);
  -webkit-backdrop-filter: blur(12px);
}
body[data-scene] h1 {
  max-width: 8.8em;
  color: #fffaf4;
  font-size: 34px;
  font-weight: 880;
  letter-spacing: 0;
}
body[data-scene] .hero .subtitle {
  max-width: 25em;
  color: rgba(255, 250, 244, 0.84);
  font-size: 14px;
}
.hero-stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 8px;
  margin-top: 16px;
}
.hero-stat {
  min-width: 0;
  border: 1px solid rgba(255, 255, 255, 0.18);
  border-radius: 16px;
  padding: 9px 10px;
  background: rgba(255, 255, 255, 0.12);
  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);
}
.hero-stat .label {
  color: rgba(255, 250, 244, 0.66);
}
.hero-stat .value {
  color: #fffaf4;
  font-size: 16px;
}
.scene-visual {
  position: relative;
  z-index: 1;
  align-self: end;
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.24);
  border-radius: 22px;
  padding: 12px;
  background:
    linear-gradient(135deg, rgba(255, 255, 255, 0.22), rgba(255, 255, 255, 0.08)),
    rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(18px) saturate(160%);
  -webkit-backdrop-filter: blur(18px) saturate(160%);
}
.scene-visual-title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  color: rgba(255, 250, 244, 0.92);
  font-size: 12px;
  font-weight: 760;
}
.scene-orb {
  width: 34px;
  height: 34px;
  flex: 0 0 auto;
  border-radius: 14px;
  background: linear-gradient(135deg, var(--scene-accent), var(--scene-accent-2));
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.34);
}
.mini-stack {
  display: grid;
  gap: 8px;
  margin-top: 10px;
}
.mini-row {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  gap: 9px;
  align-items: center;
  border-radius: 15px;
  padding: 9px;
  background: rgba(255, 250, 244, 0.88);
  color: #211b17;
}
.mini-avatar {
  display: grid;
  place-items: center;
  width: 32px;
  height: 32px;
  border-radius: 12px;
  background: rgba(255, 250, 244, 0.86);
  color: var(--scene-accent);
  font-weight: 860;
}
.mini-avatar img {
  width: 24px;
  height: 24px;
  border-radius: 7px;
}
.mini-title {
  overflow: hidden;
  color: #211b17;
  font-size: 12px;
  font-weight: 780;
  line-height: 1.2;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.mini-subtitle {
  overflow: hidden;
  margin-top: 3px;
  color: #786e66;
  font-size: 10px;
  line-height: 1.25;
  text-overflow: ellipsis;
  white-space: nowrap;
}
body[data-scene="gmail"] .scene-gmail .gmail-hero {
  grid-template-columns: 1fr;
  min-height: 0;
  align-items: stretch;
  background:
    linear-gradient(120deg, rgba(39, 32, 27, 0.9), rgba(39, 32, 27, 0.48) 44%, rgba(194, 70, 54, 0.22)),
    var(--scene-image) center/cover;
}
.scene-gmail .eyebrow {
  display: none;
}
.mail-rail {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  align-content: start;
  gap: 0;
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 999px;
  padding: 4px;
  background: rgba(255, 250, 244, 0.16);
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.22);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
}
.mail-rail::before {
  content: "";
  position: absolute;
  top: 4px;
  bottom: 4px;
  left: 4px;
  width: calc((100% - 8px) / 3);
  border-radius: 999px;
  background: rgba(255, 250, 244, 0.9);
  box-shadow: 0 10px 22px rgba(36, 24, 18, 0.16);
  transition: transform 220ms cubic-bezier(0.16, 1, 0.3, 1);
}
.mail-rail[data-mail-filter="mail-gmail"]::before {
  transform: translateX(100%);
}
.mail-rail[data-mail-filter="mail-qq"]::before {
  transform: translateX(200%);
}
.mail-folder {
  appearance: none;
  -webkit-appearance: none;
  position: relative;
  z-index: 1;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  min-width: 0;
  overflow: hidden;
  border: 0;
  border-radius: 999px;
  padding: 8px 5px;
  background: transparent;
  color: rgba(255, 250, 244, 0.88);
  font-size: 11px;
  font-weight: 720;
  font-family: inherit;
  text-align: center;
  text-overflow: ellipsis;
  white-space: nowrap;
  cursor: pointer;
  transition: color 180ms ease, transform 180ms ease;
}
.mail-folder:focus-visible {
  outline: 2px solid rgba(255, 250, 244, 0.9);
  outline-offset: 2px;
}
.mail-folder.primary {
  background: transparent;
  color: #c24636;
}
.mail-folder:active {
  transform: scale(0.98);
}
.mail-folder-icon {
  width: 16px;
  height: 16px;
  flex: 0 0 auto;
  border-radius: 4px;
  object-fit: contain;
}
.mail-folder-icon.inbox {
  background: currentColor;
  -webkit-mask: var(--mail-inbox-icon) center/contain no-repeat;
  mask: var(--mail-inbox-icon) center/contain no-repeat;
}
.mail-copy {
  position: relative;
  align-self: end;
  padding-top: 0;
}
.mail-hero-icon {
  display: inline-block;
  width: 40px;
  height: 40px;
  margin-left: 12px;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23fffaf4' stroke-width='2.35' stroke-linecap='round' stroke-linejoin='round'%3E%3Crect width='20' height='16' x='2' y='4' rx='2'/%3E%3Cpath d='m22 7-8.991 5.727a2 2 0 0 1-2.018 0L2 7'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-size: 100% 100%;
  filter: drop-shadow(0 3px 4px rgba(0, 0, 0, 0.26));
  opacity: 0.96;
  vertical-align: -6px;
}
.mail-deck {
  grid-column: auto;
  position: relative;
  z-index: 1;
  isolation: isolate;
  display: grid;
  gap: 8px;
  border: 1px solid rgba(255, 255, 255, 0.24);
  border-radius: 22px;
  padding: 12px 11px 13px;
  background:
    linear-gradient(145deg, rgba(255, 250, 244, 0.94), rgba(255, 250, 244, 0.78));
  color: #211b17;
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.5),
    0 18px 38px rgba(36, 24, 18, 0.16);
}
.mail-deck::before,
.mail-deck::after {
  content: "";
  position: absolute;
  left: 18px;
  right: 18px;
  bottom: -8px;
  height: 26px;
  border-radius: 0 0 20px 20px;
  background: rgba(255, 250, 244, 0.5);
  z-index: -1;
  filter: blur(0.2px);
}
.mail-deck::after {
  left: 32px;
  right: 32px;
  bottom: -14px;
  opacity: 0.46;
}
.mail-deck-title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  color: #c24636;
  font-size: 12px;
  font-weight: 820;
}
.mail-deck-kicker {
  color: rgba(33, 27, 23, 0.44);
  font-size: 10px;
  font-weight: 680;
}
.mail-thread {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  gap: 9px;
  align-items: center;
  border-radius: 15px;
  padding: 9px;
  background: rgba(255, 255, 255, 0.82);
  box-shadow: 0 8px 16px rgba(36, 24, 18, 0.06);
}
.mail-thread.depth-1 {
  margin: -1px 6px 0;
  opacity: 0.92;
}
.mail-thread.depth-2 {
  margin: -1px 14px 0;
  opacity: 0.82;
}
.mail-thread-dot {
  width: 10px;
  height: 10px;
  border-radius: 999px;
  background: #c24636;
}
.mail-thread-meta {
  color: #786e66;
  font-size: 10px;
  white-space: nowrap;
}
body[data-scene="gmail"] .section {
  margin-top: 18px;
}
body[data-scene="gmail"] .block {
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.9);
  box-shadow: 0 8px 22px rgba(194, 70, 54, 0.08);
}
body[data-scene="gmail"] .block-top {
  align-items: center;
}
body[data-scene="gmail"] .mini-row {
  grid-template-columns: auto minmax(0, 1fr);
  border-left: 4px solid rgba(194, 70, 54, 0.72);
}
body[data-scene] .chipbar {
  margin-top: 12px;
  border: 1px solid rgba(33, 27, 23, 0.08);
  border-radius: 999px;
  padding: 8px;
  background: rgba(255, 255, 255, 0.66);
}
body[data-scene] .section {
  margin-top: 14px;
}
body[data-scene] .section-head {
  margin: 0 2px 10px;
}
body[data-scene] .block,
body[data-scene] .timeline-item,
body[data-scene] .history-item,
body[data-scene] .empty {
  border-radius: 22px;
  background:
    linear-gradient(145deg, rgba(255, 255, 255, 0.92), rgba(255, 255, 255, 0.74)),
    var(--panel);
  box-shadow: 0 18px 42px rgba(44, 34, 26, 0.1);
}
body[data-scene] .block {
  padding: 14px;
}
body[data-scene] .block::before {
  width: 5px;
  background: linear-gradient(180deg, var(--kind-accent), transparent);
}
body[data-scene="gmail"] .block {
  border-color: rgba(194, 70, 54, 0.2);
}
body[data-scene="gmail"] .details {
  border-top-color: rgba(194, 70, 54, 0.14);
}
body[data-scene="gmail"] .mail-tech-details {
  margin-top: 10px;
  border: 1px solid rgba(194, 70, 54, 0.12);
  border-radius: 16px;
  padding: 0;
  background: rgba(255, 250, 244, 0.62);
}
body[data-scene="gmail"] .mail-tech-details > summary {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 12px;
  color: #9b3f34;
  font-size: 12px;
  font-weight: 760;
  list-style: none;
}
body[data-scene="gmail"] .mail-tech-details > summary::-webkit-details-marker {
  display: none;
}
body[data-scene="gmail"] .mail-tech-details > summary::after {
  content: "+";
  color: rgba(155, 63, 52, 0.72);
  font-size: 16px;
  line-height: 1;
}
body[data-scene="gmail"] .mail-tech-details[open] > summary::after {
  content: "-";
}
body[data-scene="gmail"] .mail-tech-body {
  border-top: 1px solid rgba(194, 70, 54, 0.1);
  padding: 0 12px 12px;
}
body[data-scene] .kind-tag {
  border-radius: 999px;
  padding: 6px 8px;
  background: var(--kind-soft);
}
body[data-scene] .expand-button {
  border: 0;
  border-bottom: 1px solid currentColor;
  border-radius: 0;
  min-width: 0;
  min-height: 0;
  padding: 3px 0;
  background: transparent;
  box-shadow: none;
  font-size: 11px;
}
body[data-scene] .actions {
  gap: 7px;
}
body[data-scene] .action {
  border-color: transparent;
  background: var(--scene-accent);
  color: #fffaf4;
  box-shadow: 0 10px 22px rgba(44, 34, 26, 0.14);
}
body[data-scene] .action.secondary {
  border-color: rgba(33, 27, 23, 0.1);
  background: rgba(255, 255, 255, 0.78);
  color: var(--scene-accent);
}
body[data-scene] .credential {
  border: 1px solid rgba(46, 111, 143, 0.22);
  border-radius: 18px;
  background:
    linear-gradient(135deg, rgba(46, 111, 143, 0.12), rgba(161, 107, 31, 0.08)),
    rgba(255, 255, 255, 0.72);
}
body[data-scene] .credential input {
  border-radius: 14px;
}
body[data-scene] .raw {
  border: 1px solid rgba(33, 27, 23, 0.08);
  background: rgba(255, 255, 255, 0.66);
}
body[data-scene] .google-map-preview,
body[data-scene] .media-player {
  border-radius: 18px;
}
@media (prefers-reduced-motion: no-preference) {
  body[data-scene] .hero,
  body[data-scene] .block {
    animation: scene-rise 420ms cubic-bezier(0.16, 1, 0.3, 1) both;
  }
}
@keyframes scene-rise {
  from { opacity: 0; transform: translateY(14px); }
  to { opacity: 1; transform: translateY(0); }
}
@media (min-width: 620px) {
  .shell { padding: 24px 22px calc(112px + env(safe-area-inset-bottom, 0px)); }
  h1 { font-size: 34px; }
  .metrics { grid-template-columns: repeat(3, minmax(0, 1fr)); }
  body[data-scene] .shell { padding: 18px 18px calc(112px + env(safe-area-inset-bottom, 0px)); }
  body[data-scene] .hero {
    grid-template-columns: minmax(0, 1.1fr) minmax(230px, 0.72fr);
    min-height: 292px;
  }
  body[data-scene="gmail"] .scene-gmail .gmail-hero {
    grid-template-columns: 82px minmax(0, 0.9fr) minmax(230px, 1fr);
  }
  .mail-rail {
    grid-column: 1;
    grid-row: 1;
    grid-template-columns: 1fr;
  }
  .mail-rail::before {
    top: 4px;
    bottom: auto;
    right: 4px;
    width: auto;
    height: calc((100% - 8px) / 3);
  }
  .mail-rail[data-mail-filter="mail-gmail"]::before {
    transform: translateY(100%);
  }
  .mail-rail[data-mail-filter="mail-qq"]::before {
    transform: translateY(200%);
  }
  .mail-copy {
    grid-column: 2;
    grid-row: 1;
  }
  .scene-gmail .mail-deck {
    grid-column: 3;
    grid-row: 1;
    align-self: end;
  }
  .mail-copy {
    padding-top: 0;
  }
  body[data-scene] .scene-visual { align-self: center; }
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
  var localState = { travel: 'all', food: 'all', mail: 'all', trainFastest: false, trainAvailable: false, trainShowMore: false, expandedKey: '' };
  function text(value) {
    return value === undefined || value === null ? '' : String(value);
  }
  function list(value) {
    return Array.isArray(value) ? value : [];
  }
  var isBusy = text(data.isBusy).toLowerCase() === 'true';
  var scene = sceneKey();
  if (document.body) {
    if (isEnhancedScene()) {
      document.body.setAttribute('data-scene', scene);
    } else {
      document.body.removeAttribute('data-scene');
    }
  }
  var MAIL_ICON_GMAIL = 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA2NCA2NCI+PHJlY3Qgd2lkdGg9IjY0IiBoZWlnaHQ9IjY0IiByeD0iMTUiIGZpbGw9IiNmZmYiLz48cGF0aCBkPSJNMTIgMjB2MjhoNDBWMjBMMzIgMzUgMTIgMjBaIiBmaWxsPSIjZmZmIiBzdHJva2U9IiNkOWRkZTMiIHN0cm9rZS13aWR0aD0iMyIvPjxwYXRoIGQ9Ik0xMiAyMGwyMCAxNSAyMC0xNSIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjZWE0MzM1IiBzdHJva2Utd2lkdGg9IjciIHN0cm9rZS1saW5lam9pbj0icm91bmQiLz48cGF0aCBkPSJNMTIgMjB2MjgiIHN0cm9rZT0iIzQyODVmNCIgc3Ryb2tlLXdpZHRoPSI3Ii8+PHBhdGggZD0iTTUyIDIwdjI4IiBzdHJva2U9IiMzNGE4NTMiIHN0cm9rZS13aWR0aD0iNyIvPjxwYXRoIGQ9Ik0xMiA0OGg0MCIgc3Ryb2tlPSIjZmJiYzA1IiBzdHJva2Utd2lkdGg9IjciLz48L3N2Zz4=';
  var MAIL_ICON_QQ = 'data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA2NCA2NCI+PHJlY3Qgd2lkdGg9IjY0IiBoZWlnaHQ9IjY0IiByeD0iMTUiIGZpbGw9IiMyZDc4YzQiLz48cGF0aCBkPSJNMTQgMjFoMzZhNCA0IDAgMCAxIDQgNHYyNGE0IDQgMCAwIDEtNCA0SDE0YTQgNCAwIDAgMS00LTRWMjVhNCA0IDAgMCAxIDQtNFoiIGZpbGw9IiNmZmYiLz48cGF0aCBkPSJNMTQgMjRsMTggMTUgMTgtMTUiIGZpbGw9Im5vbmUiIHN0cm9rZT0iIzJkNzhjNCIgc3Ryb2tlLXdpZHRoPSI1IiBzdHJva2UtbGluZWpvaW49InJvdW5kIi8+PHRleHQgeD0iMzIiIHk9IjQ4IiBmaWxsPSIjMmQ3OGM0IiBmb250LWZhbWlseT0iQXJpYWwsc2Fucy1zZXJpZiIgZm9udC1zaXplPSIxNCIgZm9udC13ZWlnaHQ9IjcwMCIgdGV4dC1hbmNob3I9Im1pZGRsZSI+UVE8L3RleHQ+PC9zdmc+';
  var MEDIA_ICON_YOUTUBE = 'data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 64 64%22%3E%3Crect width=%2264%22 height=%2264%22 rx=%2215%22 fill=%22%23c4302b%22/%3E%3Cpath d=%22M26 21v22l20-11z%22 fill=%22%23fff%22/%3E%3C/svg%3E';
  var MEDIA_ICON_BILIBILI = 'data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 64 64%22%3E%3Crect width=%2264%22 height=%2264%22 rx=%2215%22 fill=%22%232d8fbd%22/%3E%3Crect x=%2211%22 y=%2220%22 width=%2242%22 height=%2230%22 rx=%227%22 fill=%22%23fff%22/%3E%3Cpath d=%22M23 13l7 7M41 13l-7 7%22 stroke=%22%23fff%22 stroke-width=%224%22 stroke-linecap=%22round%22/%3E%3Ccircle cx=%2225%22 cy=%2235%22 r=%223%22 fill=%22%232d8fbd%22/%3E%3Ccircle cx=%2239%22 cy=%2235%22 r=%223%22 fill=%22%232d8fbd%22/%3E%3C/svg%3E';
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
  function sceneKey() {
    var kind = text(data.kind);
    return kind.length > 0 ? kind : 'generic';
  }
  function blockKindLabel(value) {
    var kind = text(value);
    if (kind === 'travel-option') { return '出行方案'; }
    if (kind === 'train-option') { return '高铁'; }
    if (kind === 'flight-option') { return '航班'; }
    if (kind === 'food-result') { return '餐饮'; }
    if (kind === 'dynamic-tool-connect') { return '授权'; }
    if (kind === 'generic-tool-result') { return '工具结果'; }
    if (kind === 'social-hub-item') { return '社交'; }
    if (kind === 'social-hub-draft') { return '草稿'; }
    if (kind === 'social-hub-connection') { return '连接'; }
    return kind;
  }
  function blockTagLabel(block) {
    if (text(block && block.kind) === 'food-result' && text(block && block.source).length > 0) {
      return text(block && block.source);
    }
    if (text(block && block.kind) === 'generic-tool-result' && text(block && block.source).length > 0) {
      return text(block && block.source);
    }
    return blockKindLabel(block && block.kind);
  }
  function mailIconData(key) {
    if (key === 'mail-gmail') { return MAIL_ICON_GMAIL; }
    if (key === 'mail-qq') { return MAIL_ICON_QQ; }
    if (key === 'media-youtube') { return MEDIA_ICON_YOUTUBE; }
    if (key === 'media-bilibili') { return MEDIA_ICON_BILIBILI; }
    return '';
  }
  function addBlockTag(parent, block, key) {
    var tag = add(parent, 'div', 'kind-tag');
    var icon = mailIconData(key);
    if (icon.length > 0) {
      var img = document.createElement('img');
      img.className = 'mail-source-icon';
      img.src = icon;
      img.alt = '';
      img.setAttribute('aria-hidden', 'true');
      tag.appendChild(img);
    }
    add(tag, 'span', '', blockTagLabel(block));
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
    if (raw.indexOf('gmail') >= 0) {
      return 'mail-gmail';
    }
    if (raw.indexOf('qq mail') >= 0 || raw.indexOf('qq邮箱') >= 0 || raw.indexOf('provider qq') >= 0) {
      return 'mail-qq';
    }
    if (raw.indexOf('youtube') >= 0 || raw.indexOf('youtu.be') >= 0) {
      return 'media-youtube';
    }
    if (raw.indexOf('bilibili') >= 0 || raw.indexOf('哔哩哔哩') >= 0 || raw.indexOf('b 站') >= 0 || raw.indexOf('b站') >= 0) {
      return 'media-bilibili';
    }
    if (kind.indexOf('social-hub') === 0) {
      var platform = [text(block && block.source), metricValue(block, ['platform'])].join(' ').toLowerCase();
      if (platform.indexOf('slack') >= 0) { return 'social-slack'; }
      if (platform.indexOf('wecom') >= 0 || platform.indexOf('wework') >= 0 || platform.indexOf('企业微信') >= 0) { return 'social-wecom'; }
      if (platform === 'x' || platform.indexOf(' x') >= 0 || platform.indexOf('twitter') >= 0) { return 'social-x'; }
    }
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
  function applyExpandedState() {
    Array.prototype.slice.call(document.querySelectorAll('[data-expandable="true"]')).forEach(function (item) {
      var expanded = (item.getAttribute('data-card-key') || '') === localState.expandedKey;
      item.classList.toggle('expanded', expanded);
      updateExpandLabel(item);
    });
  }
  function setExpandedCard(card) {
    var key = card.getAttribute('data-card-key') || '';
    localState.expandedKey = localState.expandedKey === key ? '' : key;
    applyExpandedState();
  }
  function expandCard(card) {
    localState.expandedKey = card.getAttribute('data-card-key') || '';
    applyExpandedState();
  }
  function statusLabel(value) {
    var raw = text(value);
    var key = raw.toLowerCase();
    if (key === 'ready' || key === 'success' || key === 'available') { return '已完成'; }
    if (key === 'pending' || key === 'thinking') { return '执行中'; }
    if (key === 'tool') { return '工具结果'; }
    if (key === 'model') { return '模型结果'; }
    if (key === 'welcome') { return '待输入'; }
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
  function sceneSectionTitle() {
    if (scene === 'gmail') { return '邮件线程'; }
    if (scene === 'social') { return '消息卡片'; }
    if (scene === 'thinking') { return '执行状态'; }
    if (scene === 'welcome') { return '起始面板'; }
    return '结果看板';
  }
  function sceneVisualTitle() {
    if (scene === 'gmail') { return '收件预览舱'; }
    if (scene === 'social') { return 'Message Flow'; }
    if (scene === 'thinking') { return 'Running'; }
    if (scene === 'welcome') { return 'Ready'; }
    return 'Result Board';
  }
  function previewBlocks() {
    var blocks = list(data.blocks).slice(0, 3);
    if (blocks.length > 0) { return blocks; }
    var timeline = list(data.timeline).slice(0, 3);
    if (timeline.length > 0) {
      return timeline.map(function (item, index) {
        return {
          id: 'timeline-' + String(index),
          title: text(item.title) === 'prompt' ? '用户请求' : text(item.title),
          subtitle: text(item.subtitle),
          status: text(item.status),
          source: ''
        };
      });
    }
    return [{
      id: 'empty',
      title: heroTitle(),
      subtitle: emptyCopy(),
      status: statusLabel(data.source),
      source: ''
    }];
  }
  function previewInitial(block, index) {
    var raw = text(block && block.title).trim();
    if (scene === 'gmail') { return '@'; }
    if (scene === 'social') { return raw.length > 0 ? raw.substring(0, 1) : '聊'; }
    if (scene === 'thinking') { return String(index + 1); }
    return raw.length > 0 ? raw.substring(0, 1) : '#';
  }
  function previewSubtitle(block) {
    return text(block && block.subtitle) || text(block && block.source) || statusLabel(block && block.status);
  }
  function addHeroStats(parent) {
    var stats = add(parent, 'div', 'hero-stats');
    var blocks = list(data.blocks);
    addHeroStat(stats, '结果', blocks.length > 0 ? String(blocks.length) + ' 条' : '待返回');
    addHeroStat(stats, '状态', isBusy ? '执行中' : statusLabel(data.source || data.kind));
    addHeroStat(stats, '动作', list(data.actions).length > 0 ? String(list(data.actions).length) + ' 个' : '按卡片');
  }
  function addHeroStat(parent, label, value) {
    var node = add(parent, 'div', 'hero-stat');
    add(node, 'div', 'label', label);
    add(node, 'div', 'value', value);
  }
  function sceneClassName() {
    return 'scene-' + scene.replace(/[^a-z0-9-]/g, '');
  }
  function isEnhancedScene() {
    return scene === 'gmail';
  }
  function addLegacyHero(parent) {
    var hero = add(parent, 'header', 'hero');
    var eyebrow = text(data.kind) === 'welcome' ? '' : kindLabel(data.kind);
    if (eyebrow.length > 0) { add(hero, 'div', 'eyebrow', eyebrow); }
    add(hero, 'h1', '', heroTitle());
    add(hero, 'p', 'subtitle', heroSubtitle());
    addActions(hero, data.actions);
  }
  function addHeroCopy(parent, className) {
    var heroCopy = add(parent, 'div', className || 'hero-copy');
    var eyebrow = text(data.kind) === 'welcome' || scene === 'gmail' ? '' : kindLabel(data.kind);
    if (eyebrow.length > 0) { add(heroCopy, 'div', 'eyebrow', eyebrow); }
    add(heroCopy, 'h1', '', heroTitle());
    add(heroCopy, 'p', 'subtitle', heroSubtitle());
    addActions(heroCopy, data.actions);
    return heroCopy;
  }
  function addMailThread(parent, block, index) {
    var row = add(parent, 'div', 'mail-thread depth-' + String(index));
    add(row, 'span', 'mail-thread-dot');
    var copy = add(row, 'div', 'mini-copy');
    add(copy, 'div', 'mini-title', text(block && block.title) || '邮件线程');
    add(copy, 'div', 'mini-subtitle', previewSubtitle(block));
    add(row, 'span', 'mail-thread-meta', index === 0 ? '新' : statusLabel(block && block.status));
  }
  function addMailFolderIcon(parent, key) {
    if (key === 'inbox') {
      add(parent, 'span', 'mail-folder-icon inbox');
      return;
    }
    var icon = key === 'gmail' ? MAIL_ICON_GMAIL : (key === 'qq' ? MAIL_ICON_QQ : '');
    if (icon.length === 0) { return; }
    var img = document.createElement('img');
    img.className = 'mail-folder-icon';
    img.src = icon;
    img.alt = '';
    img.setAttribute('aria-hidden', 'true');
    parent.appendChild(img);
  }
  function addGmailHero(parent) {
    var hero = add(parent, 'header', 'hero gmail-hero');
    var copy = addHeroCopy(hero, 'hero-copy mail-copy');
    var titleNode = copy.querySelector('h1') || copy;
    var icon = add(titleNode, 'span', 'mail-hero-icon');
    icon.setAttribute('aria-hidden', 'true');
    var deck = add(hero, 'aside', 'mail-deck');
    var title = add(deck, 'div', 'mail-deck-title');
    add(title, 'span', '', '收件预览舱');
    add(title, 'span', 'mail-deck-kicker', String(list(data.blocks).length || previewBlocks().length) + ' 封');
    previewBlocks().slice(0, 3).forEach(function (block, index) {
      addMailThread(deck, block, index);
    });
    var rail = add(hero, 'nav', 'mail-rail');
    rail.setAttribute('data-mail-filter', localState.mail);
    [
      ['收件箱', 'mail_filter_all', 'inbox'],
      ['Gmail', 'mail_filter_gmail', 'gmail'],
      ['QQ Mail', 'mail_filter_qq', 'qq']
    ].forEach(function (item, index) {
      var button = add(rail, 'button', index === 0 ? 'mail-folder primary' : 'mail-folder');
      button.type = 'button';
      addMailFolderIcon(button, item[2]);
      add(button, 'span', '', item[0]);
      button.setAttribute('data-mail-filter', item[1] === 'mail_filter_all' ? 'all' : (item[1] === 'mail_filter_gmail' ? 'mail-gmail' : 'mail-qq'));
      button.addEventListener('click', function () {
        handleLocalAction({ id: item[1] });
      });
    });
  }
  function renderSceneHero(parent) {
    if (!isEnhancedScene()) { addLegacyHero(parent); return; }
    if (scene === 'gmail') { addGmailHero(parent); return; }
    addLegacyHero(parent);
  }
  function addSceneVisual(parent) {
    var visual = add(parent, 'aside', 'scene-visual');
    visual.setAttribute('aria-hidden', 'true');
    var head = add(visual, 'div', 'scene-visual-title');
    add(head, 'span', '', sceneVisualTitle());
    add(head, 'span', 'scene-orb');
    var stack = add(visual, 'div', 'mini-stack');
    previewBlocks().forEach(function (block, index) {
      var row = add(stack, 'div', 'mini-row');
      var avatar = add(row, 'div', 'mini-avatar', previewInitial(block, index));
      if (scene === 'gmail' && sourceKey(block) === 'mail-gmail') {
        avatar.textContent = '';
        var icon = document.createElement('img');
        icon.src = MAIL_ICON_GMAIL;
        icon.alt = '';
        icon.setAttribute('aria-hidden', 'true');
        avatar.appendChild(icon);
      }
      var copy = add(row, 'div', 'mini-copy');
      add(copy, 'div', 'mini-title', text(block && block.title) || sceneSectionTitle());
      add(copy, 'div', 'mini-subtitle', previewSubtitle(block));
    });
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
  function isGoogleMapsBlock(block) {
    var raw = [
      text(block && block.source),
      metricValue(block, ['source', 'toolName']),
      text(block && block.title)
    ].join(' ').toLowerCase();
    return raw.indexOf('google places') >= 0 ||
      raw.indexOf('google maps') >= 0 ||
      raw.indexOf('maps.place.') >= 0;
  }
  function validMapLocation(value) {
    return /^-?[0-9]+(?:\\.[0-9]+)?\\s*,\\s*-?[0-9]+(?:\\.[0-9]+)?$/.test(text(value));
  }
  function googleMapLocation(block) {
    var location = metricValue(block, ['Map Location', 'Google Maps Location']);
    return validMapLocation(location) ? location.replace(/\\s+/g, '') : '';
  }
  function googleMapEmbedUrl(block) {
    var url = metricValue(block, ['Maps URL', 'Google Maps URL']);
    if (url.length > 0) {
      return url + (url.indexOf('?') >= 0 ? '&' : '?') + 'output=embed';
    }
    var location = googleMapLocation(block);
    return location.length > 0 ? 'https://www.google.com/maps?q=' + encodeURIComponent(location) + '&output=embed' : '';
  }
  function addGoogleMapPreview(parent, block) {
    if (!isGoogleMapsBlock(block)) { return; }
    var embedUrl = googleMapEmbedUrl(block);
    if (embedUrl.length === 0) { return; }
    var preview = add(parent, 'div', 'google-map-preview');
    var iframe = document.createElement('iframe');
    iframe.title = 'Google Maps preview';
    iframe.setAttribute('loading', 'lazy');
    iframe.setAttribute('referrerpolicy', 'no-referrer-when-downgrade');
    iframe.src = embedUrl;
    preview.appendChild(iframe);
  }
  function isAllowedMediaEmbedUrl(url) {
    var raw = text(url);
    return raw.indexOf('https://www.youtube.com/embed/') === 0 ||
      raw.indexOf('https://player.bilibili.com/player.html?') === 0;
  }
  function addMediaEmbed(parent, block) {
    var media = block && block.mediaEmbed ? block.mediaEmbed : null;
    if (!media) { return; }
    var embedUrl = text(media.embedUrl);
    if (!isAllowedMediaEmbedUrl(embedUrl)) { return; }
    var preview = add(parent, 'div', 'media-player');
    preview.addEventListener('click', function (event) {
      event.stopPropagation();
    });
    var iframe = document.createElement('iframe');
    iframe.title = text(media.title) || 'media player';
    iframe.setAttribute('loading', 'lazy');
    iframe.setAttribute('allowfullscreen', 'true');
    iframe.setAttribute('allow', 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share');
    iframe.setAttribute('referrerpolicy', 'origin-when-cross-origin');
    iframe.src = embedUrl;
    preview.appendChild(iframe);
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
    if (id === 'mail_filter_all') { localState.mail = 'all'; applyLocalView(); return true; }
    if (id === 'mail_filter_gmail') { localState.mail = 'mail-gmail'; applyLocalView(); return true; }
    if (id === 'mail_filter_qq') { localState.mail = 'mail-qq'; applyLocalView(); return true; }
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
  function updateMailFilterButtons() {
    var rail = document.querySelector('.mail-rail');
    if (rail) {
      rail.setAttribute('data-mail-filter', localState.mail);
    }
    Array.prototype.slice.call(document.querySelectorAll('.mail-folder[data-mail-filter]')).forEach(function (button) {
      button.classList.toggle('primary', (button.getAttribute('data-mail-filter') || '') === localState.mail);
    });
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
      if (kind === 'generic-tool-result' && localState.mail !== 'all') {
        visible = (card.getAttribute('data-source-key') || '') === localState.mail;
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
    updateMailFilterButtons();
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
  function addMailExpandedDetails(parent, block) {
    addActions(parent, block.actions);
    var hasTechDetails = list(block && block.metrics).length > 0 ||
      list(block && block.rows).length > 0 ||
      text(block && block.rawPreview).length > 0;
    if (!hasTechDetails) { return; }
    var wrap = document.createElement('details');
    wrap.className = 'mail-tech-details';
    wrap.addEventListener('click', function (event) {
      event.stopPropagation();
    });
    parent.appendChild(wrap);
    add(wrap, 'summary', '', '详情');
    var body = add(wrap, 'div', 'mail-tech-body');
    addPairs(body, block.metrics, 'metrics');
    addPairs(body, block.rows, 'rows');
    if (text(block.rawPreview).length > 0) {
      add(body, 'pre', 'raw', block.rawPreview);
    }
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
  var shell = add(app, 'main', isEnhancedScene() ? 'shell ' + sceneClassName() : 'shell');
  renderSceneHero(shell);
  var chips = list(data.chips).slice();
  if (chips.length > 0) {
    var chipbar = add(shell, 'nav', 'chipbar');
    chips.forEach(function (chip) {
      add(chipbar, 'span', 'chip', [text(chip.label), text(chip.value)].filter(Boolean).join(' · '));
    });
  }
  var blocks = list(data.blocks);
  if (blocks.length > 0) {
    var blocksSection = add(shell, 'section', isEnhancedScene() ? 'section blocks-' + scene : 'section');
    var blocksHead = add(blocksSection, 'div', 'section-head');
    add(blocksHead, 'h2', '', isEnhancedScene() ? sceneSectionTitle() : '任务结果');
    var countNode = add(blocksHead, 'div', 'meta', String(blocks.length) + ' 条');
    countNode.id = 'block-count';
    var filterEmpty = add(blocksSection, 'div', 'empty filter-empty', '当前筛选下暂无匹配结果。');
    filterEmpty.id = 'filter-empty';
    var trainIndex = 0;
    blocks.forEach(function (block, index) {
      var card = add(blocksSection, 'article', 'block');
      card.style.setProperty('--card-index', String(index));
      card.style.animationDelay = String(Math.min(index, 6) * 42) + 'ms';
      var expandable = isExpandable(block);
      var blockSourceKey = sourceKey(block);
      card.setAttribute('data-kind', text(block.kind));
      card.setAttribute('data-source-key', blockSourceKey);
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
      if (block && block.mediaEmbed && text(block.mediaEmbed.embedUrl).length > 0) {
        card.setAttribute('data-has-media', 'true');
      }
      card.setAttribute('data-distance', metricValue(block, ['distance']));
      card.setAttribute('data-duration', metricValue(block, ['duration']));
      card.setAttribute('data-availability', [
        metricValue(block, ['availability', 'status']),
        metricValue(block, ['seats', 'business', 'first', 'second', 'noSeat', 'hardSeat', 'sleeperSoft'])
      ].join(' '));
      var top = add(card, 'div', 'block-top');
      var titleWrap = add(top, 'div', 'block-title');
      addBlockTag(titleWrap, block, blockSourceKey);
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
      addGoogleMapPreview(card, block);
      var detailHost = expandable ? add(card, 'div', 'details') : card;
      addMediaEmbed(detailHost, block);
      if (scene === 'gmail' && text(block.kind) === 'generic-tool-result') {
        addMailExpandedDetails(detailHost, block);
      } else {
        addActions(detailHost, block.actions);
        addPairs(detailHost, block.metrics, 'metrics');
        addPairs(detailHost, block.rows, 'rows');
        if (text(block.rawPreview).length > 0) {
          add(detailHost, 'pre', 'raw', block.rawPreview);
        }
      }
      addCredentialForm(detailHost, block);
    });
    var firstMediaCard = blocksSection.querySelector('[data-has-media="true"]');
    if (firstMediaCard && !localState.expandedKey) {
      expandCard(firstMediaCard);
    }
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
    add(historyHead, 'h2', '', '上下文');
    history.forEach(function (item) {
      var node = add(historySection, 'article', 'history-item');
      add(node, 'div', 'meta', text(item.role));
      add(node, 'p', 'subtitle', text(item.content));
    });
  }
})();
`;

export function renderHtmlHomeDocument(document: HtmlHomeDocument, isBusy: boolean = false): string {
  if (shouldRenderCalendarHomeDocument(document)) {
    return renderCalendarHomeDocument(document, isBusy);
  }
  if (shouldRenderMediaHomeDocument(document)) {
    return renderMediaHomeDocument(document, isBusy);
  }
  if (shouldRenderTravelHomeDocument(document)) {
    return renderTravelHomeDocument(document, isBusy);
  }
  if (shouldRenderFoodHomeDocument(document)) {
    return renderFoodHomeDocument(document, isBusy);
  }
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
  const enhancedScene: boolean = document.kind === 'gmail';
  const bodyScene = enhancedScene ? ` data-scene="${escapeHtmlText(document.kind)}"` : '';
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${title}</title>
<style>${HTML_HOME_CSS}</style>
</head>
<body${bodyScene}>
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
