import { HtmlHomeBlock, HtmlHomeDocument, HtmlHomeMetric } from './HtmlHomeTypes';

type CalendarTextValue = Object | string | number | boolean | null | undefined;

interface CalendarHomeEvent {
  id: string;
  title: string;
  subtitle: string;
  status: string;
  source: string;
  toolName: string;
  eventId: string;
  startRaw: string;
  endRaw: string;
  windowStartRaw: string;
  windowEndRaw: string;
  link: string;
  isEmptyResult: boolean;
  dateKey: string;
  dateLabel: string;
  startLabel: string;
  endLabel: string;
  timeRange: string;
  durationLabel: string;
  top: number;
  height: number;
}

const DAY_NAMES: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
const HOUR_START: number = 8;
const HOUR_END: number = 21;

const CALENDAR_HOME_CSS: string = `
:root {
  color-scheme: light;
  --paper: #f7f2ea;
  --ink: #1f1a15;
  --muted: #746a60;
  --line: rgba(31, 26, 21, 0.12);
  --panel: rgba(255, 251, 244, 0.94);
  --panel-strong: #fffaf2;
  --accent: #2f6f78;
  --accent-2: #b36b45;
  --success: #34785f;
  --danger: #b3483d;
  --shadow: 0 18px 42px rgba(42, 31, 20, 0.13);
}
* { box-sizing: border-box; }
body {
  margin: 0;
  min-height: 100vh;
  background:
    linear-gradient(180deg, rgba(255, 251, 244, 0.78) 0%, rgba(247, 242, 234, 0.96) 56%, var(--paper) 100%),
    var(--paper);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", "Helvetica Neue", Arial, sans-serif;
  letter-spacing: 0;
  -webkit-font-smoothing: antialiased;
}
button, a { font: inherit; }
button { cursor: pointer; }
h1, h2, h3, p { margin: 0; }
.calendar-shell {
  width: min(100%, 840px);
  min-height: 100vh;
  margin: 0 auto;
  padding-bottom: calc(96px + env(safe-area-inset-bottom, 0px));
}
.calendar-hero {
  position: relative;
  display: grid;
  gap: 16px;
  min-height: 302px;
  overflow: hidden;
  padding: 22px 15px 16px;
  background:
    linear-gradient(180deg, rgba(31, 26, 21, 0.10) 0%, rgba(31, 26, 21, 0.28) 40%, rgba(247, 242, 234, 0.97) 100%),
    linear-gradient(115deg, rgba(47, 111, 120, 0.52), rgba(179, 107, 69, 0.42)),
    url('https://images.unsplash.com/photo-1506784983877-45594efa4cbe?auto=format&fit=crop&w=1400&q=80') center/cover;
}
.calendar-hero::after {
  content: "";
  position: absolute;
  inset: auto 0 0;
  height: 72px;
  background: linear-gradient(180deg, rgba(247, 242, 234, 0), var(--paper));
}
.calendar-hero-copy,
.calendar-confirmation {
  position: relative;
  z-index: 1;
}
.calendar-kicker {
  display: inline-flex;
  width: fit-content;
  border: 1px solid rgba(255, 250, 242, 0.42);
  border-radius: 999px;
  padding: 8px 11px;
  background: rgba(255, 250, 242, 0.78);
  color: var(--accent);
  font-size: 12px;
  font-weight: 840;
  line-height: 1;
  box-shadow: 0 10px 22px rgba(42, 31, 20, 0.12);
  backdrop-filter: blur(14px);
  -webkit-backdrop-filter: blur(14px);
}
.calendar-hero h1 {
  margin-top: 14px;
  max-width: 9.4em;
  overflow-wrap: anywhere;
  font-family: Georgia, "Times New Roman", "Songti SC", serif;
  font-size: 42px;
  line-height: 0.98;
  font-weight: 760;
  color: #fffaf2;
  text-shadow: 0 2px 16px rgba(31, 26, 21, 0.24);
}
.calendar-hero p {
  margin-top: 10px;
  max-width: 34em;
  color: rgba(255, 250, 242, 0.86);
  font-size: 14px;
  line-height: 1.55;
  overflow-wrap: anywhere;
}
.calendar-hero-stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 8px;
  margin-top: 16px;
}
.calendar-stat {
  min-width: 0;
  border: 1px solid rgba(255, 250, 242, 0.34);
  border-radius: 16px;
  padding: 10px;
  background: rgba(255, 250, 242, 0.76);
  box-shadow: 0 12px 28px rgba(42, 31, 20, 0.10);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
}
.calendar-stat span {
  display: block;
  color: var(--muted);
  font-size: 10px;
  font-weight: 760;
}
.calendar-stat strong {
  display: block;
  margin-top: 5px;
  color: var(--ink);
  font-size: 14px;
  line-height: 1.16;
  overflow-wrap: anywhere;
}
.calendar-confirmation {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 12px;
  align-items: end;
  border: 1px solid rgba(255, 250, 242, 0.40);
  border-radius: 24px;
  padding: 14px;
  background: rgba(255, 250, 242, 0.88);
  box-shadow: var(--shadow);
  backdrop-filter: blur(18px);
  -webkit-backdrop-filter: blur(18px);
}
.calendar-confirmation h2 {
  color: var(--success);
  font-size: 13px;
  font-weight: 860;
}
.calendar-confirmation p {
  margin-top: 5px;
  color: var(--ink);
  font-size: 20px;
  font-weight: 860;
  line-height: 1.16;
}
.calendar-time-capsule {
  position: relative;
  overflow: hidden;
  min-width: 112px;
  border: 1px solid rgba(255, 250, 242, 0.48);
  border-radius: 20px;
  padding: 12px;
  background:
    linear-gradient(145deg, rgba(43, 108, 116, 0.94), rgba(181, 108, 65, 0.82)),
    url('https://images.unsplash.com/photo-1484480974693-6ca0a78fb36b?auto=format&fit=crop&w=640&q=80') center/cover;
  color: #fffaf2;
  text-align: right;
  box-shadow: 0 14px 28px rgba(42, 31, 20, 0.16);
}
.calendar-time-capsule strong {
  display: block;
  font-size: 18px;
  line-height: 1.05;
  text-shadow: 0 1px 10px rgba(22, 20, 16, 0.25);
}
.calendar-time-capsule span {
  display: block;
  margin-top: 6px;
  color: rgba(255, 250, 242, 0.82);
  font-size: 11px;
}
.calendar-view-switch {
  position: sticky;
  top: 0;
  z-index: 8;
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding: 12px 14px;
  border-bottom: 1px solid rgba(31, 26, 21, 0.06);
  background: rgba(247, 242, 234, 0.93);
  backdrop-filter: blur(18px);
  -webkit-backdrop-filter: blur(18px);
  scrollbar-width: none;
}
.calendar-view-switch::-webkit-scrollbar { display: none; }
.calendar-view-button {
  flex: 0 0 auto;
  min-width: 56px;
  min-height: 38px;
  border: 1px solid var(--line);
  border-radius: 999px;
  padding: 9px 14px;
  background: rgba(255, 250, 242, 0.92);
  color: var(--ink);
  font-size: 13px;
  font-weight: 840;
  line-height: 1;
  box-shadow: 0 8px 18px rgba(42, 31, 20, 0.06);
}
.calendar-view-button.active {
  border-color: var(--ink);
  background: var(--ink);
  color: var(--panel-strong);
}
.calendar-board {
  padding: 0 14px;
}
.calendar-view {
  display: none;
  margin-top: 12px;
}
.calendar-view.active {
  display: block;
}
.calendar-section-title {
  display: flex;
  align-items: end;
  justify-content: space-between;
  gap: 12px;
  margin: 0 2px 10px;
}
.calendar-section-title h2 {
  font-size: 19px;
  line-height: 1.12;
}
.calendar-section-title span {
  color: var(--muted);
  font-size: 12px;
  font-weight: 720;
}
.calendar-day-stage {
  display: grid;
  grid-template-columns: 54px minmax(0, 1fr);
  min-height: 650px;
  overflow: hidden;
  border: 1px solid var(--line);
  border-radius: 26px;
  background: var(--panel);
  box-shadow: var(--shadow);
}
.calendar-hours {
  border-right: 1px solid rgba(31, 26, 21, 0.08);
  background: rgba(255, 250, 242, 0.74);
}
.calendar-hour {
  height: 50px;
  padding: 7px 8px 0 0;
  color: var(--muted);
  font-size: 11px;
  font-weight: 760;
  text-align: right;
}
.calendar-lanes {
  position: relative;
  min-height: 650px;
  background:
    repeating-linear-gradient(180deg, rgba(31, 26, 21, 0.055) 0, rgba(31, 26, 21, 0.055) 1px, transparent 1px, transparent 50px);
}
.calendar-event-block {
  position: absolute;
  left: 10px;
  right: 10px;
  top: var(--event-top);
  min-height: 62px;
  height: var(--event-height);
  overflow: hidden;
  border: 1px solid rgba(47, 111, 120, 0.22);
  border-left: 5px solid var(--accent);
  border-radius: 18px;
  padding: 10px 11px;
  background:
    linear-gradient(135deg, rgba(47, 111, 120, 0.13), rgba(179, 107, 69, 0.08)),
    #fffaf2;
  color: var(--ink);
  box-shadow: 0 14px 26px rgba(42, 31, 20, 0.12);
  text-align: left;
}
.calendar-event-block h3,
.calendar-chip h3,
.calendar-undated-card h3 {
  overflow: hidden;
  font-size: 14px;
  line-height: 1.18;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.calendar-event-block p,
.calendar-chip p,
.calendar-undated-card p {
  margin-top: 5px;
  overflow: hidden;
  color: var(--muted);
  font-size: 11px;
  line-height: 1.25;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.calendar-week-grid {
  display: grid;
  grid-template-columns: repeat(7, minmax(92px, 1fr));
  gap: 8px;
  overflow-x: auto;
  padding-bottom: 4px;
}
.calendar-week-day,
.calendar-month-day,
.calendar-undated-card,
.calendar-detail-drawer {
  border: 1px solid var(--line);
  background: var(--panel);
  box-shadow: 0 12px 30px rgba(42, 31, 20, 0.08);
}
.calendar-week-day {
  min-height: 180px;
  border-radius: 20px;
  padding: 10px;
}
.calendar-week-day.current {
  border-color: rgba(47, 111, 120, 0.42);
  background: linear-gradient(180deg, rgba(47, 111, 120, 0.10), rgba(255, 250, 242, 0.94));
}
.calendar-day-name {
  color: var(--muted);
  font-size: 11px;
  font-weight: 780;
}
.calendar-day-number {
  margin-top: 3px;
  font-size: 20px;
  font-weight: 880;
}
.calendar-load {
  height: 5px;
  margin: 10px 0;
  overflow: hidden;
  border-radius: 999px;
  background: rgba(31, 26, 21, 0.08);
}
.calendar-load i {
  display: block;
  width: var(--load-width);
  height: 100%;
  border-radius: inherit;
  background: linear-gradient(90deg, var(--accent), var(--accent-2));
}
.calendar-chip {
  display: block;
  width: 100%;
  margin-top: 7px;
  border: 0;
  border-radius: 14px;
  padding: 8px;
  background: rgba(47, 111, 120, 0.12);
  color: var(--ink);
  text-align: left;
}
.calendar-month-grid {
  display: grid;
  grid-template-columns: repeat(7, minmax(0, 1fr));
  gap: 7px;
}
.calendar-month-label {
  color: var(--muted);
  font-size: 11px;
  font-weight: 820;
  text-align: center;
}
.calendar-month-day {
  min-height: 78px;
  border-radius: 16px;
  padding: 8px;
}
.calendar-month-day.muted {
  opacity: 0.42;
}
.calendar-month-day.has-events {
  border-color: rgba(47, 111, 120, 0.34);
}
.calendar-month-day strong {
  display: block;
  font-size: 13px;
}
.calendar-month-dot {
  display: inline-block;
  width: 7px;
  height: 7px;
  margin: 9px 4px 0 0;
  border-radius: 999px;
  background: var(--accent);
}
.calendar-month-title {
  display: block;
  overflow: hidden;
  margin-top: 6px;
  color: var(--muted);
  font-size: 10px;
  line-height: 1.2;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.calendar-undated {
  display: grid;
  gap: 9px;
  margin-top: 12px;
}
.calendar-undated-card {
  border-radius: 20px;
  padding: 12px;
}
.calendar-empty {
  border: 1px dashed rgba(47, 111, 120, 0.34);
  border-radius: 22px;
  padding: 18px;
  background: rgba(255, 250, 242, 0.76);
  color: var(--muted);
  font-size: 13px;
  line-height: 1.5;
}
.calendar-detail-drawer {
  margin: 14px;
  border-radius: 24px;
  padding: 14px;
}
.calendar-detail-drawer h2 {
  font-size: 18px;
  line-height: 1.2;
  overflow-wrap: anywhere;
}
.calendar-detail-drawer p {
  margin-top: 7px;
  color: var(--muted);
  font-size: 13px;
  line-height: 1.45;
  overflow-wrap: anywhere;
}
.calendar-detail-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
  margin-top: 12px;
}
.calendar-detail-cell {
  min-width: 0;
  border-radius: 16px;
  padding: 10px;
  background: rgba(31, 26, 21, 0.05);
}
.calendar-detail-cell span {
  display: block;
  color: var(--muted);
  font-size: 10px;
  font-weight: 780;
}
.calendar-detail-cell strong {
  display: block;
  overflow-wrap: anywhere;
  margin-top: 5px;
  font-size: 13px;
  line-height: 1.25;
}
.calendar-open-link {
  display: inline-flex;
  margin-top: 12px;
  border-radius: 999px;
  padding: 10px 13px;
  background: var(--ink);
  color: var(--panel-strong);
  font-size: 12px;
  font-weight: 820;
  text-decoration: none;
}
@media (min-width: 680px) {
  .calendar-hero {
    grid-template-columns: minmax(0, 1fr) minmax(260px, 0.58fr);
    align-items: end;
    min-height: 316px;
    padding: 28px 24px 18px;
  }
  .calendar-confirmation { align-self: end; }
  .calendar-board { padding: 0 18px; }
  .calendar-detail-drawer { margin: 16px 18px; }
}
`;

const CALENDAR_HOME_JS: string = `
(function () {
  var shell = document.querySelector('.calendar-shell');
  if (!shell) { return; }
  var buttons = Array.prototype.slice.call(document.querySelectorAll('[data-calendar-view]'));
  var views = Array.prototype.slice.call(document.querySelectorAll('.calendar-view'));
  function setView(view) {
    buttons.forEach(function (button) {
      button.classList.toggle('active', button.getAttribute('data-calendar-view') === view);
    });
    views.forEach(function (node) {
      node.classList.toggle('active', node.getAttribute('data-view') === view);
    });
  }
  buttons.forEach(function (button) {
    button.addEventListener('click', function () {
      setView(button.getAttribute('data-calendar-view') || 'day');
    });
  });
  var drawer = document.querySelector('.calendar-detail-drawer');
  function pick(card) {
    if (!drawer || !card) { return; }
    var title = card.getAttribute('data-title') || '日程';
    var time = card.getAttribute('data-time') || '时间待确认';
    var source = card.getAttribute('data-source') || 'Google Calendar API';
    var eventId = card.getAttribute('data-event-id') || '';
    var link = card.getAttribute('data-link') || '';
    drawer.querySelector('[data-detail-title]').textContent = title;
    drawer.querySelector('[data-detail-time]').textContent = time;
    drawer.querySelector('[data-detail-source]').textContent = source;
    drawer.querySelector('[data-detail-id]').textContent = eventId.length > 0 ? eventId : '未返回';
    var open = drawer.querySelector('[data-detail-link]');
    if (open) {
      open.style.display = link.length > 0 ? 'inline-flex' : 'none';
      open.setAttribute('href', link);
    }
  }
  Array.prototype.slice.call(document.querySelectorAll('[data-calendar-event]')).forEach(function (card) {
    card.addEventListener('click', function () { pick(card); });
  });
  var first = document.querySelector('[data-calendar-event]');
  if (first) { pick(first); }
  setView('day');
})();
`;

function textOf(value: CalendarTextValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value.toString();
  }
  return JSON.stringify(value);
}

function escapeHtmlText(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function escapeAttribute(value: string): string {
  return escapeHtmlText(value);
}

function metricValue(metrics: HtmlHomeMetric[], label: string): string {
  for (let index = 0; index < metrics.length; index++) {
    if (metrics[index].label === label) {
      return metrics[index].value;
    }
  }
  return '';
}

function rowValue(block: HtmlHomeBlock, label: string): string {
  for (let index = 0; index < block.rows.length; index++) {
    if (block.rows[index].label === label) {
      return block.rows[index].value;
    }
  }
  return '';
}

function calendarToolName(block: HtmlHomeBlock): string {
  return metricValue(block.metrics, 'toolName');
}

function includesCalendarText(value: string): boolean {
  return value.indexOf('Google Calendar') >= 0 || value.indexOf('谷歌日历') >= 0;
}

function isCalendarBlock(block: HtmlHomeBlock): boolean {
  const toolName = calendarToolName(block);
  if (toolName.indexOf('calendar.') === 0) {
    return true;
  }
  if (textOf(block.toolId).indexOf('calendar.') === 0) {
    return true;
  }
  return includesCalendarText(textOf(block.source)) || includesCalendarText(metricValue(block.metrics, 'source'));
}

function pad2(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}

function validDate(value: string): Date | null {
  if (value.length === 0) {
    return null;
  }
  const date = new Date(value);
  return isNaN(date.getTime()) ? null : date;
}

function dateKeyOf(date: Date | null): string {
  if (date === null) {
    return '';
  }
  return date.getFullYear().toString() + '-' + pad2(date.getMonth() + 1) + '-' + pad2(date.getDate());
}

function formatDateLabel(date: Date | null): string {
  if (date === null) {
    return '时间待确认';
  }
  return (date.getMonth() + 1).toString() + '月' + date.getDate().toString() + '日 ' + DAY_NAMES[date.getDay()];
}

function formatTimeLabel(raw: string, date: Date | null): string {
  if (raw.length === 0 || date === null) {
    return '待确认';
  }
  if (raw.indexOf('T') < 0) {
    return '全天';
  }
  return pad2(date.getHours()) + ':' + pad2(date.getMinutes());
}

function durationLabel(start: Date | null, end: Date | null): string {
  if (start === null || end === null) {
    return '时长待确认';
  }
  const minutes = Math.max(0, Math.round((end.getTime() - start.getTime()) / 60000));
  if (minutes === 0) {
    return '0分钟';
  }
  if (minutes < 60) {
    return minutes.toString() + '分钟';
  }
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  return rest === 0 ? hours.toString() + '小时' : hours.toString() + '小时' + rest.toString() + '分钟';
}

function eventTop(start: Date | null): number {
  if (start === null) {
    return 0;
  }
  const minutes = (start.getHours() - HOUR_START) * 60 + start.getMinutes();
  return Math.max(0, Math.min((HOUR_END - HOUR_START) * 50 - 42, Math.round(minutes * 50 / 60)));
}

function eventHeight(start: Date | null, end: Date | null): number {
  if (start === null || end === null) {
    return 62;
  }
  const minutes = Math.max(30, Math.round((end.getTime() - start.getTime()) / 60000));
  return Math.max(62, Math.min(180, Math.round(minutes * 50 / 60)));
}

function calendarEventFromBlock(block: HtmlHomeBlock): CalendarHomeEvent {
  const startRaw = rowValue(block, 'Start');
  const endRaw = rowValue(block, 'End');
  const windowStartRaw = rowValue(block, 'Window Start');
  const windowEndRaw = rowValue(block, 'Window End');
  const start = validDate(startRaw);
  const end = validDate(endRaw);
  const startLabel = formatTimeLabel(startRaw, start);
  const endLabel = formatTimeLabel(endRaw, end);
  const isEmptyResult = block.title.indexOf('没有找到') >= 0 && startRaw.length === 0 && windowStartRaw.length > 0;
  return {
    id: block.id,
    title: block.title.length > 0 ? block.title : '未命名日程',
    subtitle: textOf(block.subtitle),
    status: textOf(block.status),
    source: textOf(block.source).length > 0 ? textOf(block.source) : 'Google Calendar API',
    toolName: calendarToolName(block),
    eventId: rowValue(block, 'Event ID'),
    startRaw: startRaw,
    endRaw: endRaw,
    windowStartRaw: windowStartRaw,
    windowEndRaw: windowEndRaw,
    link: rowValue(block, 'Link'),
    isEmptyResult: isEmptyResult,
    dateKey: dateKeyOf(start),
    dateLabel: formatDateLabel(start),
    startLabel: startLabel,
    endLabel: endLabel,
    timeRange: startLabel + ' - ' + endLabel,
    durationLabel: durationLabel(start, end),
    top: eventTop(start),
    height: eventHeight(start, end)
  };
}

function calendarEvents(document: HtmlHomeDocument): CalendarHomeEvent[] {
  const events: CalendarHomeEvent[] = [];
  document.blocks.forEach((block: HtmlHomeBlock) => {
    if (isCalendarBlock(block)) {
      events.push(calendarEventFromBlock(block));
    }
  });
  return events;
}

function timedEvents(events: CalendarHomeEvent[]): CalendarHomeEvent[] {
  return events.filter((event: CalendarHomeEvent) => !event.isEmptyResult && event.dateKey.length > 0 && event.startLabel !== '全天');
}

function primaryEvent(events: CalendarHomeEvent[]): CalendarHomeEvent | null {
  const realEvents = events.filter((event: CalendarHomeEvent) => !event.isEmptyResult);
  return realEvents.length === 0 ? null : realEvents[0];
}

function isCreateDocument(events: CalendarHomeEvent[], document: HtmlHomeDocument): boolean {
  if (document.subtitle.indexOf('已直接写入真实 Google Calendar') >= 0) {
    return true;
  }
  for (let index = 0; index < events.length; index++) {
    if (events[index].toolName === 'calendar.event.create') {
      return true;
    }
  }
  return false;
}

function eventCountLabel(events: CalendarHomeEvent[]): string {
  const dated = timedEvents(events).length;
  return dated > 0 ? dated.toString() + ' 个日程' : '无定时日程';
}

function targetDate(events: CalendarHomeEvent[], generatedAt: string): Date {
  for (let index = 0; index < events.length; index++) {
    const date = validDate(events[index].startRaw);
    if (date !== null) {
      return date;
    }
  }
  for (let index = 0; index < events.length; index++) {
    const date = validDate(events[index].windowStartRaw);
    if (date !== null) {
      return date;
    }
  }
  const generated = validDate(generatedAt);
  return generated === null ? new Date() : generated;
}

function eventDataAttrs(event: CalendarHomeEvent): string {
  return ' data-calendar-event="' + escapeAttribute(event.id) + '"' +
    ' data-title="' + escapeAttribute(event.title) + '"' +
    ' data-time="' + escapeAttribute(event.dateLabel + ' ' + event.timeRange) + '"' +
    ' data-source="' + escapeAttribute(event.source) + '"' +
    ' data-event-id="' + escapeAttribute(event.eventId) + '"' +
    ' data-link="' + escapeAttribute(event.link) + '"';
}

function stat(label: string, value: string): string {
  return '<div class="calendar-stat"><span>' + escapeHtmlText(label) + '</span><strong>' +
    escapeHtmlText(value) + '</strong></div>';
}

function confirmation(event: CalendarHomeEvent | null): string {
  if (event === null) {
    return '';
  }
  return '<aside class="calendar-confirmation">' +
    '<div><h2>已写入 Google Calendar</h2><p>' + escapeHtmlText(event.title) + '</p></div>' +
    '<div class="calendar-time-capsule"><strong>' + escapeHtmlText(event.startLabel) + '</strong><strong>' +
    escapeHtmlText(event.endLabel) + '</strong><span>' + escapeHtmlText(event.durationLabel) + '</span></div>' +
    '</aside>';
}

function hero(document: HtmlHomeDocument, events: CalendarHomeEvent[], isCreate: boolean, isBusy: boolean): string {
  const first = primaryEvent(events);
  const target = targetDate(events, document.generatedAt);
  const state = isBusy ? '同步中' : (isCreate ? '已写入' : '已同步');
  return '<header class="calendar-hero">' +
    '<section class="calendar-hero-copy">' +
    '<span class="calendar-kicker">Google Calendar API · ' + escapeHtmlText(state) + '</span>' +
    '<h1>' + escapeHtmlText(document.title.length > 0 ? document.title : 'Google Calendar') + '</h1>' +
    '<p>' + escapeHtmlText(document.subtitle.length > 0 ? document.subtitle : '来自真实 Google Calendar 的日程结果。') + '</p>' +
    '<div class="calendar-hero-stats">' +
    stat('日期', formatDateLabel(target)) +
    stat('结果', eventCountLabel(events)) +
    stat('下一项', first === null ? '暂无' : first.timeRange) +
    '</div></section>' +
    (isCreate ? confirmation(first) : '') +
    '</header>';
}

function viewSwitch(): string {
  return '<nav class="calendar-view-switch" aria-label="Calendar view switch">' +
    '<button type="button" class="calendar-view-button active" data-calendar-view="day">天</button>' +
    '<button type="button" class="calendar-view-button" data-calendar-view="week">周</button>' +
    '<button type="button" class="calendar-view-button" data-calendar-view="month">月</button>' +
    '</nav>';
}

function dayView(events: CalendarHomeEvent[], target: Date): string {
  const dated = timedEvents(events);
  const hours: string[] = [];
  for (let hour = HOUR_START; hour < HOUR_END; hour++) {
    hours.push('<div class="calendar-hour">' + pad2(hour) + ':00</div>');
  }
  const blocks = dated.map((event: CalendarHomeEvent): string => {
    return '<button type="button" class="calendar-event-block" style="--event-top:' + event.top.toString() +
      'px;--event-height:' + event.height.toString() + 'px;"' + eventDataAttrs(event) + '>' +
      '<h3>' + escapeHtmlText(event.title) + '</h3><p>' + escapeHtmlText(event.timeRange + ' · ' + event.durationLabel) +
      '</p></button>';
  }).join('');
  return '<section class="calendar-view calendar-view-day active" data-view="day">' +
    '<div class="calendar-section-title"><h2>日视图</h2><span>' + escapeHtmlText(formatDateLabel(target)) + '</span></div>' +
    (dated.length === 0 ? '<div class="calendar-empty">这个时间窗没有可放入时间轴的日程；如果 Google Calendar 返回了空结果，这里不会补造事件。</div>' :
      '<div class="calendar-day-stage"><div class="calendar-hours">' + hours.join('') + '</div><div class="calendar-lanes">' + blocks + '</div></div>') +
    undatedList(events) +
    '</section>';
}

function startOfWeek(date: Date): Date {
  const copy = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const day = copy.getDay() === 0 ? 7 : copy.getDay();
  copy.setDate(copy.getDate() - day + 1);
  return copy;
}

function eventsForDate(events: CalendarHomeEvent[], dateKey: string): CalendarHomeEvent[] {
  return events.filter((event: CalendarHomeEvent) => event.dateKey === dateKey);
}

function weekView(events: CalendarHomeEvent[], target: Date): string {
  const start = startOfWeek(target);
  const days: string[] = [];
  for (let offset = 0; offset < 7; offset++) {
    const day = new Date(start.getFullYear(), start.getMonth(), start.getDate() + offset);
    const key = dateKeyOf(day);
    const dayEvents = eventsForDate(events, key);
    const load = Math.min(100, dayEvents.length * 28);
    const chips = dayEvents.map((event: CalendarHomeEvent): string => {
      return '<button type="button" class="calendar-chip"' + eventDataAttrs(event) + '><h3>' +
        escapeHtmlText(event.title) + '</h3><p>' + escapeHtmlText(event.timeRange) + '</p></button>';
    }).join('');
    days.push('<article class="calendar-week-day' + (key === dateKeyOf(target) ? ' current' : '') + '">' +
      '<div class="calendar-day-name">' + DAY_NAMES[day.getDay()] + '</div>' +
      '<div class="calendar-day-number">' + day.getDate().toString() + '</div>' +
      '<div class="calendar-load"><i style="--load-width:' + load.toString() + '%"></i></div>' +
      (chips.length > 0 ? chips : '<p class="calendar-month-title">无返回日程</p>') +
      '</article>');
  }
  return '<section class="calendar-view calendar-view-week" data-view="week">' +
    '<div class="calendar-section-title"><h2>周视图</h2><span>仅展示当前返回的事件</span></div>' +
    '<div class="calendar-week-grid">' + days.join('') + '</div></section>';
}

function monthView(events: CalendarHomeEvent[], target: Date): string {
  const labels = ['一', '二', '三', '四', '五', '六', '日'].map((label: string): string => {
    return '<div class="calendar-month-label">' + label + '</div>';
  }).join('');
  const first = new Date(target.getFullYear(), target.getMonth(), 1);
  const startOffset = first.getDay() === 0 ? 6 : first.getDay() - 1;
  const gridStart = new Date(target.getFullYear(), target.getMonth(), 1 - startOffset);
  const cells: string[] = [];
  for (let index = 0; index < 42; index++) {
    const day = new Date(gridStart.getFullYear(), gridStart.getMonth(), gridStart.getDate() + index);
    const key = dateKeyOf(day);
    const dayEvents = eventsForDate(events, key);
    const dots = dayEvents.slice(0, 3).map((_event: CalendarHomeEvent): string => '<i class="calendar-month-dot"></i>').join('');
    const firstTitle = dayEvents.length > 0 ? '<span class="calendar-month-title">' + escapeHtmlText(dayEvents[0].title) + '</span>' : '';
    cells.push('<article class="calendar-month-day' + (day.getMonth() === target.getMonth() ? '' : ' muted') +
      (dayEvents.length > 0 ? ' has-events' : '') + '"><strong>' + day.getDate().toString() + '</strong>' +
      dots + firstTitle + '</article>');
  }
  return '<section class="calendar-view calendar-view-month" data-view="month">' +
    '<div class="calendar-section-title"><h2>月视图</h2><span>' + (target.getMonth() + 1).toString() + '月</span></div>' +
    '<div class="calendar-month-grid">' + labels + cells.join('') + '</div></section>';
}

function undatedList(events: CalendarHomeEvent[]): string {
  const undated = events.filter((event: CalendarHomeEvent) => event.dateKey.length === 0);
  if (undated.length === 0) {
    return '';
  }
  return '<div class="calendar-undated">' + undated.map((event: CalendarHomeEvent): string => {
    return '<button type="button" class="calendar-undated-card"' + eventDataAttrs(event) + '><h3>' +
      escapeHtmlText(event.title) + '</h3><p>' + escapeHtmlText(event.subtitle.length > 0 ? event.subtitle : event.source) +
      '</p></button>';
  }).join('') + '</div>';
}

function detailDrawer(events: CalendarHomeEvent[]): string {
  const first = primaryEvent(events);
  const title = first === null ? '暂无日程' : first.title;
  const time = first === null ? '等待 Google Calendar 返回' : first.dateLabel + ' ' + first.timeRange;
  const source = first === null ? 'Google Calendar API' : first.source;
  const eventId = first === null || first.eventId.length === 0 ? '未返回' : first.eventId;
  const link = first === null ? '' : first.link;
  return '<aside class="calendar-detail-drawer">' +
    '<h2 data-detail-title>' + escapeHtmlText(title) + '</h2>' +
    '<p data-detail-time>' + escapeHtmlText(time) + '</p>' +
    '<div class="calendar-detail-grid">' +
    '<div class="calendar-detail-cell"><span>来源</span><strong data-detail-source>' + escapeHtmlText(source) + '</strong></div>' +
    '<div class="calendar-detail-cell"><span>Event ID</span><strong data-detail-id>' + escapeHtmlText(eventId) + '</strong></div>' +
    '</div>' +
    '<a class="calendar-open-link" data-detail-link href="' + escapeAttribute(link) + '" target="_blank" rel="noreferrer"' +
    (link.length === 0 ? ' style="display:none"' : '') + '>打开 Google Calendar</a>' +
    '</aside>';
}

function calendarHtml(document: HtmlHomeDocument, events: CalendarHomeEvent[], isBusy: boolean): string {
  const title = document.title.length > 0 ? document.title : 'Google Calendar';
  const target = targetDate(events, document.generatedAt);
  const createMode = isCreateDocument(events, document);
  return '<!DOCTYPE html>\n<html lang="zh-CN">\n<head>\n<meta charset="UTF-8" />\n' +
    '<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover" />\n' +
    '<title>' + escapeHtmlText(title) + '</title>\n<style>' + CALENDAR_HOME_CSS + '</style>\n</head>\n<body>\n' +
    '<main class="calendar-shell">' +
    hero(document, events, createMode, isBusy) +
    viewSwitch() +
    '<section class="calendar-board">' +
    dayView(events, target) +
    weekView(events, target) +
    monthView(events, target) +
    '</section>' +
    detailDrawer(events) +
    '</main>\n<script>' + CALENDAR_HOME_JS + '</script>\n</body>\n</html>';
}

export function shouldRenderCalendarHomeDocument(document: HtmlHomeDocument): boolean {
  return document.blocks.some((block: HtmlHomeBlock) => isCalendarBlock(block));
}

export function renderCalendarHomeDocument(document: HtmlHomeDocument, isBusy: boolean = false): string {
  return calendarHtml(document, calendarEvents(document), isBusy);
}
