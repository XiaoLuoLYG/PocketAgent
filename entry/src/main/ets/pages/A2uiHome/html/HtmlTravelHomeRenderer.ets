import { HtmlHomeDocument } from './HtmlHomeTypes';

type HtmlTravelTextValue = Object | string | number | boolean | null | undefined;

interface HtmlTravelHomeDocumentWithBusy extends HtmlHomeDocument {
  isBusy?: boolean;
}

const TRAVEL_HOME_CSS: string = `
:root {
  color-scheme: light;
  --void: #f8f2e8;
  --ink: #17120d;
  --muted: #756c62;
  --line: rgba(23, 18, 13, 0.12);
  --panel: rgba(255, 250, 241, 0.9);
  --panel-strong: rgba(255, 250, 241, 0.98);
  --chrome: #8a7d70;
  --rail: #16875b;
  --air: #2f79b7;
  --signal: #d8492f;
  --other: #815f3e;
  --shadow: 0 16px 42px rgba(37, 24, 13, 0.12);
}
* { box-sizing: border-box; }
body {
  margin: 0;
  min-height: 100vh;
  background: var(--void);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Noto Sans SC", "Helvetica Neue", Arial, sans-serif;
  letter-spacing: 0;
  -webkit-font-smoothing: antialiased;
}
button { font: inherit; cursor: pointer; }
button:disabled { cursor: default; opacity: 0.52; }
.itinerary-shell {
  width: min(100%, 820px);
  min-height: 100vh;
  margin: 0 auto;
  padding-bottom: calc(92px + env(safe-area-inset-bottom, 0px));
  overflow: hidden;
}
.route-hero {
  position: relative;
  min-height: 360px;
  padding: 22px 16px 20px;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  isolation: isolate;
}
.route-hero::before {
  content: "";
  position: absolute;
  inset: 0;
  z-index: -2;
  background:
    linear-gradient(180deg, rgba(248, 242, 232, 0.16) 0%, rgba(248, 242, 232, 0.34) 44%, rgba(248, 242, 232, 0.96) 100%),
    url("https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80"),
    linear-gradient(135deg, #f8f2e8, #fffaf1);
  background-size: cover;
  background-position: center;
  transform: scale(1.02);
}
.route-hero::after {
  content: "";
  position: absolute;
  inset: 0;
  z-index: -1;
  background:
    repeating-linear-gradient(90deg, rgba(23, 18, 13, 0.045) 0 1px, transparent 1px 42px),
    repeating-linear-gradient(0deg, rgba(23, 18, 13, 0.035) 0 1px, transparent 1px 38px);
  mask-image: linear-gradient(180deg, rgba(0,0,0,0.82), transparent 72%);
}
.route-kicker {
  width: fit-content;
  max-width: 100%;
  display: inline-flex;
  align-items: center;
  gap: 7px;
  border: 1px solid rgba(23, 18, 13, 0.14);
  border-radius: 999px;
  padding: 8px 11px;
  background: rgba(255, 250, 241, 0.72);
  color: var(--ink);
  font-size: 12px;
  font-weight: 820;
  line-height: 1;
  backdrop-filter: blur(18px);
}
.route-kicker::before {
  content: "";
  width: 14px;
  height: 14px;
  flex: 0 0 auto;
  background-image: url("data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KICA8cGF0aCBkPSJNMTIuOTg2MyAyMS42NTUzQzExLjM3NSAyMS42NTUzIDEwLjAwMzkgMjEuMjI0NiA4Ljg3MzA1IDIwLjM2MzNDNy43NDgwNSAxOS41MDIgNi44ODA4NiAxOC4yMjQ2IDYuMjcxNDggMTYuNTMxMkw0LjY5ODI0IDEyLjEzNjdDNC42NDU1MSAxMS45Nzg1IDQuNjA0NDkgMTEuODExNSA0LjU3NTIgMTEuNjM1N0M0LjU0NTkgMTEuNDYgNC41MzEyNSAxMS4yOTg4IDQuNTMxMjUgMTEuMTUyM0M0LjUzMTI1IDEwLjYzMDkgNC43MDQxIDEwLjIyMzYgNS4wNDk4IDkuOTMwNjZDNS4zOTU1MSA5LjYzNzcgNS44MDg1OSA5LjQ5MTIxIDYuMjg5MDYgOS40OTEyMUM2LjYwNTQ3IDkuNDkxMjEgNi44OTI1OCA5LjU3NjE3IDcuMTUwMzkgOS43NDYwOUM3LjQwODIgOS45MTYwMiA3LjYxNjIxIDEwLjE2OCA3Ljc3NDQxIDEwLjUwMkw4LjI2NjYgMTEuNjYyMUM4LjI4NDE4IDExLjcwMzEgOC4zMDc2MiAxMS43MjM2IDguMzM2OTEgMTEuNzIzNkM4LjM3NzkzIDExLjcyMzYgOC4zOTg0NCAxMS42OTQzIDguMzk4NDQgMTEuNjM1N1Y0LjY2NjAyQzguMzk4NDQgNC4wNjI1IDguNTgzMDEgMy41NzkxIDguOTUyMTUgMy4yMTU4MkM5LjMyMTI5IDIuODQ2NjggOS43OTI5NyAyLjY2MjExIDEwLjM2NzIgMi42NjIxMUMxMC45MzU1IDIuNjYyMTEgMTEuMzk4NCAyLjg0NjY4IDExLjc1NTkgMy4yMTU4MkMxMi4xMTkxIDMuNTc5MSAxMi4zMDA4IDQuMDYyNSAxMi4zMDA4IDQuNjY2MDJWNy4zMjAzMUMxMi40NzA3IDcuMjczNDQgMTIuNjQ2NSA3LjI1IDEyLjgyODEgNy4yNUMxMy4yMTQ4IDcuMjUgMTMuNTQ4OCA3LjM1MjU0IDEzLjgzMDEgNy41NTc2MkMxNC4xMTcyIDcuNzU2ODQgMTQuMzI1MiA4LjAzODA5IDE0LjQ1NDEgOC40MDEzN0MxNC42OTQzIDguMzI1MiAxNC45Mzc1IDguMjg3MTEgMTUuMTgzNiA4LjI4NzExQzE1LjU2NDUgOC4yODcxMSAxNS44OTI2IDguMzgwODYgMTYuMTY4IDguNTY4MzZDMTYuNDQzNCA4Ljc1NTg2IDE2LjYzNjcgOS4wMTM2NyAxNi43NDggOS4zNDE4QzE3LjYwMzUgOS4zNTkzOCAxOC4yNjg2IDkuNjY0MDYgMTguNzQzMiAxMC4yNTU5QzE5LjIyMzYgMTAuODQ3NyAxOS40NjM5IDExLjY2MjEgMTkuNDYzOSAxMi42OTkyVjE0LjgwODZDMTkuNDYzOSAxNi4yMzgzIDE5LjE5NzMgMTcuNDYyOSAxOC42NjQxIDE4LjQ4MjRDMTguMTMwOSAxOS41MDIgMTcuMzc3OSAyMC4yODQyIDE2LjQwNTMgMjAuODI5MUMxNS40Mzg1IDIxLjM3OTkgMTQuMjk4OCAyMS42NTUzIDEyLjk4NjMgMjEuNjU1M1pNMTMuMDMwMyAyMC4xNjExQzE0LjA3MzIgMjAuMTYxMSAxNC45Njk3IDE5Ljk0NDMgMTUuNzE5NyAxOS41MTA3QzE2LjQ2OTcgMTkuMDgzIDE3LjA0MzkgMTguNDU5IDE3LjQ0MjQgMTcuNjM4N0MxNy44NDY3IDE2LjgxODQgMTguMDQ4OCAxNS44MjUyIDE4LjA0ODggMTQuNjU5MlYxMi43NzgzQzE4LjA0ODggMTIuMTU3MiAxNy45NTIxIDExLjY3OTcgMTcuNzU4OCAxMS4zNDU3QzE3LjU2NTQgMTEuMDA1OSAxNy4yOSAxMC44MzU5IDE2LjkzMjYgMTAuODM1OVYxMS43MzI0QzE2LjkzMjYgMTEuOTE0MSAxNi44NjgyIDEyLjA2MzUgMTYuNzM5MyAxMi4xODA3QzE2LjYxNjIgMTIuMjk3OSAxNi40NzI3IDEyLjM1NjQgMTYuMzA4NiAxMi4zNTY0QzE2LjEzMjggMTIuMzU2NCAxNS45Nzc1IDEyLjI5NzkgMTUuODQyOCAxMi4xODA3QzE1LjcxMzkgMTIuMDYzNSAxNS42NDk0IDExLjkxNDEgMTUuNjQ5NCAxMS43MzI0VjEwLjM0MzhDMTUuNjQ5NCAxMC4xMzg3IDE1LjU5MzggOS45Nzc1NCAxNS40ODI0IDkuODYwMzVDMTUuMzc3IDkuNzQzMTYgMTUuMjI0NiA5LjY4NDU3IDE1LjAyNTQgOS42ODQ1N0MxNC44NjEzIDkuNjg0NTcgMTQuNzA2MSA5LjcxNjggMTQuNTU5NiA5Ljc4MTI1VjExLjM4MDlDMTQuNTU5NiAxMS41Njg0IDE0LjQ5NTEgMTEuNzIwNyAxNC4zNjYyIDExLjgzNzlDMTQuMjQzMiAxMS45NDkyIDE0LjA5NjcgMTIuMDA0OSAxMy45MjY4IDEyLjAwNDlDMTMuNzU2OCAxMi4wMDQ5IDEzLjYwNzQgMTEuOTQ5MiAxMy40Nzg1IDExLjgzNzlDMTMuMzQ5NiAxMS43MjA3IDEzLjI4NTIgMTEuNTY4NCAxMy4yODUyIDExLjM4MDlWOS4zMDY2NEMxMy4yODUyIDkuMTAxNTYgMTMuMjI2NiA4Ljk0MDQzIDEzLjEwOTQgOC44MjMyNEMxMi45OTggOC43MDYwNSAxMi44NDg2IDguNjQ3NDYgMTIuNjYxMSA4LjY0NzQ2QzEyLjQ5NzEgOC42NDc0NiAxMi4zMzg5IDguNjc5NjkgMTIuMTg2NSA4Ljc0NDE0VjExLjAyOTNDMTIuMTg2NSAxMS4yMDUxIDEyLjEyMjEgMTEuMzU0NSAxMS45OTMyIDExLjQ3NzVDMTEuODcwMSAxMS42MDA2IDExLjcyMDcgMTEuNjYyMSAxMS41NDQ5IDExLjY2MjFDMTEuMzY5MSAxMS42NjIxIDExLjIxNjggMTEuNjAwNiAxMS4wODc5IDExLjQ3NzVDMTAuOTY0OCAxMS4zNTQ1IDEwLjkwMzMgMTEuMjA1MSAxMC45MDMzIDExLjAyOTNWNC41NzgxMkMxMC45MDMzIDQuNDA4MiAxMC44NTM1IDQuMjczNDQgMTAuNzUzOSA0LjE3MzgzQzEwLjY1NDMgNC4wNjgzNiAxMC41MjI1IDQuMDE1NjIgMTAuMzU4NCA0LjAxNTYyQzEwLjE5NDMgNC4wMTU2MiAxMC4wNTk2IDQuMDY4MzYgOS45NTQxIDQuMTczODNDOS44NTQ0OSA0LjI3MzQ0IDkuODA0NjkgNC40MDgyIDkuODA0NjkgNC41NzgxMkw5Ljc5NTkgMTMuNzYyN0M5Ljc5NTkgMTMuOTkxMiA5LjcyNTU5IDE0LjE3ODcgOS41ODQ5NiAxNC4zMjUyQzkuNDUwMiAxNC40NzE3IDkuMjgwMjcgMTQuNTQ0OSA5LjA3NTIgMTQuNTQ0OUM4LjkwNTI3IDE0LjU0NDkgOC43NDcwNyAxNC41MDEgOC42MDA1OSAxNC40MTMxQzguNDU5OTYgMTQuMzI1MiA4LjMzOTg0IDE0LjE2NyA4LjI0MDIzIDEzLjkzODVMNi45ODM0IDExLjI0OUM2Ljg3MjA3IDEwLjk3MzYgNi42OTYyOSAxMC44MzU5IDYuNDU2MDUgMTAuODM1OUM2LjI5Nzg1IDEwLjgzNTkgNi4xNzE4OCAxMC44ODU3IDYuMDc4MTIgMTAuOTg1NEM1Ljk5MDIzIDExLjA3OTEgNS45NDYyOSAxMS4xOTM0IDUuOTQ2MjkgMTEuMzI4MUM1Ljk0NjI5IDExLjQ0NTMgNS45NjY4IDExLjU2NTQgNi4wMDc4MSAxMS42ODg1TDcuNjE2MjEgMTYuMDM5MUM4LjE2MTEzIDE3LjUwOTggOC44ODc3IDE4LjU2NDUgOS43OTU5IDE5LjIwMzFDMTAuNzEgMTkuODQxOCAxMS43ODgxIDIwLjE2MTEgMTMuMDMwMyAyMC4xNjExWiIgZmlsbD0iYmxhY2siLz4KPC9zdmc+Cg==");
  background-size: contain;
  background-repeat: no-repeat;
  background-position: center;
  opacity: 0.82;
}
.route-hero h1 {
  margin: 15px 0 10px;
  max-width: 9.2em;
  overflow-wrap: anywhere;
  font-family: Georgia, "Times New Roman", "Songti SC", serif;
  font-size: 43px;
  line-height: 0.96;
  font-weight: 760;
}
.route-hero p {
  margin: 0;
  max-width: 30em;
  width: fit-content;
  overflow-wrap: anywhere;
  border: 1px solid rgba(23, 18, 13, 0.1);
  border-radius: 18px;
  padding: 8px 10px;
  background: rgba(255, 250, 241, 0.74);
  color: rgba(23, 18, 13, 0.82);
  font-size: 14px;
  font-weight: 650;
  line-height: 1.55;
  backdrop-filter: blur(14px);
}
.route-map {
  margin-top: 14px;
  border: 1px solid var(--line);
  border-radius: 22px;
  padding: 12px;
  background: rgba(255, 250, 241, 0.82);
  box-shadow: var(--shadow);
  backdrop-filter: blur(20px);
}
.route-cities {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
  gap: 10px;
  align-items: center;
}
.route-city {
  min-width: 0;
  border-radius: 16px;
  padding: 11px 12px;
  background: rgba(23, 18, 13, 0.06);
}
.route-city b {
  display: block;
  overflow-wrap: anywhere;
  font-size: 18px;
  line-height: 1.1;
}
.route-city span {
  display: block;
  margin-top: 5px;
  color: var(--muted);
  font-size: 11px;
  line-height: 1.2;
}
.route-mid {
  position: relative;
  width: 78px;
  height: 42px;
}
.route-mid::before {
  content: "";
  position: absolute;
  left: 12px;
  right: 12px;
  top: 23px;
  height: 7px;
  background: linear-gradient(90deg, var(--rail), var(--air), var(--signal));
  clip-path: polygon(0 38%, calc(100% - 8px) 38%, calc(100% - 8px) 0, 100% 50%, calc(100% - 8px) 100%, calc(100% - 8px) 62%, 0 62%);
}
.route-mid::after {
  content: "";
  position: absolute;
  left: 50%;
  top: 12px;
  width: 30px;
  height: 30px;
  border-radius: 50%;
  border: 1px solid transparent;
  background-color: transparent;
  background-image: url("data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPGcgY2xpcC1wYXRoPSJ1cmwoI2NsaXAwXzQ1ODRfMzE0KSI+CjxwYXRoIGQ9Ik0xNS44MTI1IDE5LjM5NTRDMTUuOTczNSAxOS43OTQgMTYuNDg5MSAxOS44OTg4IDE2Ljc5MzEgMTkuNTk0OUwxNy40NTg2IDE4LjkyOTRDMTcuNzM1OSAxOC42NTIgMTcuODYwMiAxOC4yNTY2IDE3Ljc5MTQgMTcuODcwNEwxNi40MDk5IDEwLjExNDFMMjAuMzE4NCA2LjQ1MzI1QzIxLjU0NTkgNS4yNzgzMyAyMS4yNTM0IDMuNzQzNzcgMjAuNzU1NyAzLjI0NjAxQzIwLjI1NzkgMi43NDgyNSAxOC42NjIyIDIuNTMxOTUgMTcuNTUwNiAzLjY4NTVMMTMuODk1MSA3LjU5OTMyTDYuMTMxNjggNi4yMTA3NkM1Ljc0NTI1IDYuMTQxNjUgNS4zNDk0NSA2LjI2NTkxIDUuMDcxODcgNi41NDM0OUw0LjQwNjM3IDcuMjA4OThDNC4xMDI1MyA3LjUxMjgzIDQuMjA3MjIgOC4wMjgyMSA0LjYwNTU0IDguMTg5NDJMMTAuNzk4NSAxMC42OTU5TDcuMjM1MjMgMTQuNzAyMUw0Ljg1MTI3IDE0LjAxNzdDNC42NDE1NyAxMy45NTc1IDQuNDE1NzIgMTQuMDE1OSA0LjI2MTQ1IDE0LjE3MDFMMy4zMDY3OSAxNS4xMjQ4QzMuMTY1MjQgMTUuMjY2MyAzLjE5OTQgMTUuNTA0MiAzLjM3NTA5IDE1LjYwMDJMNi42MjY4MSAxNy4zNzY4TDguNDAxNTEgMjAuNjI2NUM4LjQ5NzQ3IDIwLjgwMjIgOC43MzUzNiAyMC44MzY0IDguODc2OTMgMjAuNjk0OEw5LjgzMTUzIDE5Ljc0MDJDOS45ODU4IDE5LjU4NTkgMTAuMDQ0MiAxOS4zNjAxIDkuOTgzOTcgMTkuMTUwNEw5LjI5OTYxIDE2Ljc2NjRMMTMuMzEzMyAxMy4yMTA3TDE1LjgxMjUgMTkuMzk1NFoiIHN0cm9rZT0iYmxhY2siIHN0cm9rZS13aWR0aD0iMS41Ii8+CjwvZz4KPGRlZnM+CjxjbGlwUGF0aCBpZD0iY2xpcDBfNDU4NF8zMTQiPgo8cmVjdCB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIGZpbGw9IndoaXRlIi8+CjwvY2xpcFBhdGg+CjwvZGVmcz4KPC9zdmc+Cg==");
  background-repeat: no-repeat;
  background-size: 17px 17px;
  background-position: center;
  box-shadow: none;
  transform: translate(-50%, -50%);
}
.route-stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 8px;
  margin-top: 12px;
}
.route-stat {
  min-width: 0;
  border-radius: 14px;
  padding: 9px;
  background: rgba(23, 18, 13, 0.05);
}
.route-stat span {
  display: block;
  color: var(--muted);
  font-size: 10px;
  line-height: 1;
}
.route-stat b {
  display: block;
  margin-top: 6px;
  overflow-wrap: anywhere;
  font-size: 14px;
  line-height: 1.15;
}
.travel-controls {
  position: sticky;
  top: 0;
  z-index: 8;
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding: 12px 14px;
  background: rgba(248, 242, 232, 0.92);
  border-bottom: 1px solid rgba(23, 18, 13, 0.06);
  backdrop-filter: blur(18px);
  scrollbar-width: none;
}
.travel-controls::-webkit-scrollbar { display: none; }
.travel-control {
  flex: 0 0 auto;
  border: 1px solid var(--line);
  border-radius: 999px;
  min-height: 38px;
  padding: 10px 13px;
  background: rgba(255, 250, 241, 0.92);
  color: var(--ink);
  font-size: 12px;
  font-weight: 760;
  line-height: 1;
  white-space: nowrap;
}
.travel-control.active {
  border-color: var(--ink);
  background: var(--ink);
  color: var(--void);
}
.journey-board {
  display: grid;
  gap: 10px;
  padding: 10px 14px 20px;
}
.journey-empty {
  border: 1px dashed rgba(23, 18, 13, 0.18);
  border-radius: 20px;
  padding: 18px;
  background: var(--panel);
  color: var(--muted);
  line-height: 1.55;
}
.journey-card {
  --source: var(--other);
  position: relative;
  overflow: hidden;
  border: 1px solid var(--line);
  border-radius: 22px;
  padding: 12px;
  background:
    linear-gradient(135deg, rgba(255, 250, 241, 0.98), rgba(255, 247, 231, 0.9)),
    var(--panel);
  box-shadow: 0 12px 30px rgba(37, 24, 13, 0.09);
}
.journey-card[data-source="train"] { --source: var(--rail); }
.journey-card[data-source="flight"] { --source: var(--air); }
.journey-card[data-source="food"] { --source: var(--signal); }
.journey-card::before {
  content: "";
  position: absolute;
  inset: 0 0 auto;
  height: 5px;
  background: linear-gradient(90deg, var(--source), rgba(23, 18, 13, 0.08));
}
.journey-card::after {
  content: "";
  position: absolute;
  right: -48px;
  top: -48px;
  width: 132px;
  height: 132px;
  border-radius: 50%;
  border: 1px solid rgba(23, 18, 13, 0.08);
  background: radial-gradient(circle, rgba(23, 18, 13, 0.06), transparent 68%);
  opacity: 0.72;
  pointer-events: none;
}
.journey-top {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 12px;
  align-items: start;
}
.journey-tag {
  width: fit-content;
  max-width: 100%;
  display: inline-flex;
  align-items: center;
  gap: 5px;
  border-radius: 999px;
  padding: 6px 9px;
  border: 1px solid var(--source);
  background: rgba(255, 250, 241, 0.9);
  color: var(--source);
  font-size: 10px;
  font-weight: 840;
  line-height: 1;
  overflow-wrap: anywhere;
}
.journey-tag::before {
  content: "";
  display: none;
  width: 13px;
  height: 13px;
  flex: 0 0 auto;
  background-size: contain;
  background-repeat: no-repeat;
  background-position: center;
  opacity: 0.82;
}
.journey-tag.train::before {
  display: block;
  background-image: url("data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPGcgY2xpcC1wYXRoPSJ1cmwoI2NsaXAwXzQ1ODRfMzE2KSI+CjxwYXRoIGZpbGwtcnVsZT0iZXZlbm9kZCIgY2xpcC1ydWxlPSJldmVub2RkIiBkPSJNMTIuMDAyOSAwLjYxNDI1OEMxMi44MjkxIDAuNjE0MjU4IDEzLjU4NzkgMC42Mzc2OTUgMTQuMjc5MyAwLjY4NDU3QzE0Ljk3MDcgMC43MjU1ODUgMTUuNDgzNCAwLjc2MzY3MiAxNS44MTc0IDAuNzk4ODI4QzE2LjQ3OTUgMC44ODY3MjMgMTcuMDY1NCAxLjA4MzAyIDE3LjU3NTIgMS4zODc3QzE4LjA5MDcgMS42ODY1MSAxOC41MTg2IDIuMDk2NzUgMTguODU4NCAyLjYxODE2QzE5LjIwNCAzLjEzMzcyIDE5LjQ1NjEgMy43NDYyNSAxOS42MTQzIDQuNDU1MDhDMTkuNzM3MyA0Ljk3MDU5IDE5Ljg0NTcgNS41NDgwNCAxOS45Mzk1IDYuMTg2NTJDMjAuMDM5IDYuODI1MDYgMjAuMTE1MiA3LjUxMzg2IDIwLjE2OCA4LjI1MTk1QzIwLjIyNjUgOC45ODQyMyAyMC4yNTU5IDkuNzUyMTMgMjAuMjU1OSAxMC41NTQ3VjE2LjI1QzIwLjI1NTggMTYuOTQ3MSAyMC4xMTgxIDE3LjU2MjYgMTkuODQyOCAxOC4wOTU3QzE5LjU3MzIgMTguNjIyOSAxOS4xODA1IDE5LjAzMzMgMTguNjY1IDE5LjMyNjJDMTguMTk2MyAxOS41OTU1IDE3LjY0MyAxOS43MzgxIDE3LjAwNTkgMTkuNzU5OEwxOC43MDAyIDIyLjQ5MDJDMTguNzg3OSAyMi42MzA3IDE4LjgyMzIgMjIuNzY4NyAxOC44MDU3IDIyLjkwMzNDMTguNzg4IDIzLjAzNzkgMTguNzI5NCAyMy4xNTI1IDE4LjYyOTkgMjMuMjQ2MUMxOC41MzYyIDIzLjMzOTcgMTguNDEgMjMuMzg2NyAxOC4yNTIgMjMuMzg2N0gxNy43NDIyQzE3LjQ5MDQgMjMuMzg2NyAxNy4yOTM5IDIzLjI3MjIgMTcuMTUzMyAyMy4wNDM5TDE2LjY2MTEgMjIuMjUyOUg3LjMwNzYyTDYuODE3MzggMjMuMDQzOUM2LjY3Njc3IDIzLjI3MjIgNi40ODAzNCAyMy4zODY3IDYuMjI4NTIgMjMuMzg2N0g1LjY4MzU5QzUuNTE5NjcgMjMuMzg2NyA1LjM5MDYgMjMuMzM5NyA1LjI5Njg4IDIzLjI0NjFDNS4yMDMyNCAyMy4xNTgzIDUuMTQ3NTMgMjMuMDQ2NyA1LjEyOTg4IDIyLjkxMjFDNS4xMTgxNyAyMi43ODMzIDUuMTUzNDggMjIuNjUxMiA1LjIzNTM1IDIyLjUxNjZMNi45NTMxMiAxOS43NTg4QzYuMzMwMjIgMTkuNzMxOSA1Ljc4OTY3IDE5LjU4OTEgNS4zMzIwMyAxOS4zMjYyQzQuODIyMzkgMTkuMDMzMyA0LjQyOTY4IDE4LjYyMjkgNC4xNTQzIDE4LjA5NTdDMy44ODQ4MyAxNy41NjI2IDMuNzUwMDYgMTYuOTQ3MSAzLjc1IDE2LjI1VjEwLjQ5MzJDMy43NSA5LjY5MDYxIDMuNzc2MzkgOC45Mjg1NyAzLjgyOTEgOC4yMDgwMUMzLjg4NzY4IDcuNDgxNjMgMy45NjM5IDYuODA0NTUgNC4wNTc2MiA2LjE3NzczQzQuMTU3MiA1LjU0NTExIDQuMjY4NiA0Ljk3MDU4IDQuMzkxNiA0LjQ1NTA4QzQuNTQ5NzcgMy43NDYyNSA0Ljc5ODk0IDMuMTMzNzIgNS4xMzg2NyAyLjYxODE2QzUuNDc4NDcgMi4wOTY3NSA1LjkwMzQxIDEuNjg2NTEgNi40MTMwOSAxLjM4NzdDNi45Mjg2OSAxLjA4MzAyIDcuNTIwNTMgMC44ODY3MjMgOC4xODg0OCAwLjc5ODgyOEM4LjUxNjYgMC43NjM2NzIgOS4wMDg4IDAuNzI1NTg1IDkuNjY1MDQgMC42ODQ1N0MxMC4zMjEzIDAuNjM3Njk1IDExLjEwMDYgMC42MTQyNTggMTIuMDAyOSAwLjYxNDI1OFpNOC44NTA1OSAxOS43NjU2TDguMjEyODkgMjAuNzkzOUgxNS43NTI5TDE1LjExMzMgMTkuNzY1Nkg4Ljg1MDU5Wk0xMi4wMDI5IDIuMDIwNTFDMTEuMTQxNiAyLjAyMDUxIDEwLjQwMDQgMi4wNDEwMiA5Ljc3OTMgMi4wODIwM0M5LjE1ODIyIDIuMTE3MTkgOC42ODY1MiAyLjE1MjM0IDguMzY0MjYgMi4xODc1QzcuOTA3MjUgMi4yNDAyNCA3LjUwMjkyIDIuMzY5MTUgNy4xNTEzNyAyLjU3NDIyQzYuODA1NzYgMi43NzkyOSA2LjUxNTU4IDMuMDYwNjIgNi4yODEyNSAzLjQxNzk3QzYuMDQ2OTkgMy43Njk0NyA1Ljg3Mzk5IDQuMTk3NDMgNS43NjI3IDQuNzAxMTdDNS42NzQ4NSA1LjA3NjA0IDUuNTkyNzQgNS40Nzc3MiA1LjUxNjYgNS45MDUyN0M1LjQ0NjMyIDYuMzMyODcgNS4zODE4MSA2Ljc5MDIyIDUuMzIzMjQgNy4yNzYzN0M1LjI3MDUzIDcuNzU2NjkgNS4yMjY1NSA4LjI2Njc4IDUuMTkxNDEgOC44MDU2NkM1LjE2MjEzIDkuMzQ0NTggNS4xNDc0NiA5LjkwNzQgNS4xNDc0NiAxMC40OTMyVjE2LjE3OTdDNS4xNDc1MiAxNi42MDcyIDUuMjI2NjIgMTYuOTg1NSA1LjM4NDc3IDE3LjMxMzVDNS41NDg4MyAxNy42NDE0IDUuNzk1MDUgMTcuODk5NSA2LjEyMzA1IDE4LjA4NjlDNi40NTcgMTguMjY4NSA2Ljg3OTAxIDE4LjM1OTQgNy4zODg2NyAxOC4zNTk0SDE2LjYwODRDMTcuMTE4MSAxOC4zNTk0IDE3LjU0MDEgMTguMjY4NSAxNy44NzQgMTguMDg2OUMxOC4yMDc5IDE3Ljg5OTUgMTguNDU0MSAxNy42NDE0IDE4LjYxMjMgMTcuMzEzNUMxOC43NzYzIDE2Ljk4NTUgMTguODU4MyAxNi42MDcyIDE4Ljg1ODQgMTYuMTc5N1YxMC41NTQ3QzE4Ljg1ODQgOS45NzQ3OCAxOC44NDA4IDkuNDExOTYgMTguODA1NyA4Ljg2NzE5QzE4Ljc3NjQgOC4zMjI0NCAxOC43MzI0IDcuODAzNTcgMTguNjczOCA3LjMxMTUyQzE4LjYyMTEgNi44MTM2NiAxOC41NTY2IDYuMzQ3NTIgMTguNDgwNSA1LjkxNDA2QzE4LjQwNDMgNS40ODA2NSAxOC4zMjUyIDUuMDc2MDQgMTguMjQzMiA0LjcwMTE3QzE4LjEzMTkgNC4xOTc0MyAxNy45NTg5IDMuNzY5NDcgMTcuNzI0NiAzLjQxNzk3QzE3LjQ5MDMgMy4wNjA2MiAxNy4xOTcyIDIuNzc5MjkgMTYuODQ1NyAyLjU3NDIyQzE2LjQ5NDIgMi4zNjkxNSAxNi4wODY5IDIuMjQwMjQgMTUuNjI0IDIuMTg3NUMxNS4zMDE4IDIuMTUyMzQgMTQuODEyNSAyLjExNzE5IDE0LjE1NjIgMi4wODIwM0MxMy41IDIuMDQxMDIgMTIuNzgyMiAyLjAyMDUxIDEyLjAwMjkgMi4wMjA1MVpNMTYuMTA3NCAxNC42MTUyQzE2LjQ1OSAxNC42MTUyIDE2Ljc0OSAxNC43MzI0IDE2Ljk3NzUgMTQuOTY2OEMxNy4yMTE4IDE1LjIwMTEgMTcuMzI5MSAxNS40ODg0IDE3LjMyOTEgMTUuODI4MUMxNy4zMjkgMTYuMTc5NSAxNy4yMTE4IDE2LjQ3MjggMTYuOTc3NSAxNi43MDdDMTYuNzQzMiAxNi45NDEyIDE2LjQ1MyAxNy4wNTg2IDE2LjEwNzQgMTcuMDU4NkMxNS43NjE4IDE3LjA1ODYgMTUuNDcxNiAxNi45NDEyIDE1LjIzNzMgMTYuNzA3QzE1LjAwMyAxNi40NzI4IDE0Ljg4NTkgMTYuMTc5NSAxNC44ODU3IDE1LjgyODFDMTQuODg1NyAxNS40ODg0IDE1LjAwMzEgMTUuMjAxMSAxNS4yMzczIDE0Ljk2NjhDMTUuNDcxNyAxNC43MzI0IDE1Ljc2MTcgMTQuNjE1MiAxNi4xMDc0IDE0LjYxNTJaTTcuODgwODYgMTQuNjI0QzguMjMyNDIgMTQuNjI0IDguNTIyNDYgMTQuNzM4MyA4Ljc1MDk4IDE0Ljk2NjhDOC45NzkzMyAxNS4xOTUzIDkuMDkzNzUgMTUuNDgyNSA5LjA5Mzc1IDE1LjgyODFDOS4wOTM2NCAxNi4xNzk1IDguOTc2NDUgMTYuNDcyOCA4Ljc0MjE5IDE2LjcwN0M4LjUxMzcxIDE2LjkzNTQgOC4yMjY0NCAxNy4wNDk4IDcuODgwODYgMTcuMDQ5OEM3LjUyOTQyIDE3LjA0OTggNy4yMzkyMiAxNi45MzU0IDcuMDEwNzQgMTYuNzA3QzYuNzg4MTkgMTYuNDcyOCA2LjY3Njg2IDE2LjE3OTUgNi42NzY3NiAxNS44MjgxQzYuNjc2NzYgMTUuNDgyNSA2Ljc5MTE4IDE1LjE5NTMgNy4wMTk1MyAxNC45NjY4QzcuMjQ4MDUgMTQuNzM4MyA3LjUzNTE2IDE0LjYyNCA3Ljg4MDg2IDE0LjYyNFpNMTIuMDAzOSA1LjU4ODg3QzEyLjgzNTkgNS41ODg4NyAxMy41MjczIDUuNTk3NjYgMTQuMDc4MSA1LjYxNTIzQzE0LjYyODkgNS42MzI4MSAxNS4wOTE4IDUuNjU2MjUgMTUuNDY2OCA1LjY4NTU1QzE1Ljg0NzcgNS43MDg5OCAxNi4xOTkyIDUuNzQxMjEgMTYuNTIxNSA1Ljc4MjIzQzE2LjcyMDcgNS44MDU2NiAxNi44Nzg5IDUuODgxODQgMTYuOTk2MSA2LjAxMDc0QzE3LjExOTEgNi4xMzk2NSAxNy4yMDQxIDYuMzAwNzggMTcuMjUxIDYuNDk0MTRDMTcuMjk3OSA2LjY5OTIyIDE3LjM0NzcgNi45ODkyNiAxNy40MDA0IDcuMzY0MjZDMTcuNDUzMSA3LjczOTI2IDE3LjQ5NzEgOC4xNzg3MSAxNy41MzIyIDguNjgyNjJDMTcuNTY3NCA5LjE4NjUyIDE3LjU4NSA5LjczNDM4IDE3LjU4NSAxMC4zMjYyVjEyLjM0NzdDMTcuNTg1IDEyLjU5MzggMTcuNTI5MyAxMi43OTg4IDE3LjQxOCAxMi45NjI5QzE3LjMwNjYgMTMuMTIxMSAxNy4xMTkxIDEzLjIxNzggMTYuODU1NSAxMy4yNTI5QzE2LjM4MDkgMTMuMzExNSAxNS43Mjc1IDEzLjM2MTMgMTQuODk1NSAxMy40MDIzQzE0LjA2OTMgMTMuNDQzNCAxMy4xMDU1IDEzLjQ2NjggMTIuMDAzOSAxMy40NzI3QzEwLjg5NjUgMTMuNDY2OCA5LjkyNjc2IDEzLjQ0MzQgOS4wOTQ3MyAxMy40MDIzQzguMjY4NTUgMTMuMzYxMyA3LjYxODE2IDEzLjMxMTUgNy4xNDM1NSAxMy4yNTI5QzYuODc5ODggMTMuMjE3OCA2LjY5MjM4IDEzLjEyMTEgNi41ODEwNSAxMi45NjI5QzYuNDY5NzMgMTIuNzk4OCA2LjQxNDA2IDEyLjU5MzggNi40MTQwNiAxMi4zNDc3VjEwLjMyNjJDNi40MTQwNiA5LjczNDM4IDYuNDMxNjQgOS4xODY1MiA2LjQ2NjggOC42ODI2MkM2LjUwMTk1IDguMTc4NzEgNi41NDU5IDcuNzM5MjYgNi41OTg2MyA3LjM2NDI2QzYuNjUxMzcgNi45ODkyNiA2LjcwMTE3IDYuNjk5MjIgNi43NDgwNSA2LjQ5NDE0QzYuNzk0OTIgNi4zMDA3OCA2Ljg3Njk1IDYuMTM5NjUgNi45OTQxNCA2LjAxMDc0QzcuMTExMzMgNS44ODE4NCA3LjI2MzY3IDUuODA1NjYgNy40NTExNyA1Ljc4MjIzQzcuNzg1MTYgNS43NDEyMSA4LjE0MjU4IDUuNzA4OTggOC41MjM0NCA1LjY4NTU1QzguOTA0MyA1LjY1NjI1IDkuMzcwMTIgNS42MzI4MSA5LjkyMDkgNS42MTUyM0MxMC40NzE3IDUuNTk3NjYgMTEuMTY2IDUuNTg4ODcgMTIuMDAzOSA1LjU4ODg3Wk0xMi4wMDM5IDcuMDM5MDZDMTEuMTc0NCA3LjAzOTA2IDEwLjQ5NjUgNy4wNDc1NSA5Ljk2NjggNy4wNjQ0NUM5LjQyOTM2IDcuMDgxNjEgOC45ODY3NyA3LjEwMzc5IDguNjM0NzcgNy4xMzA4Nkw4LjYyNDAyIDcuMTMxODRMOC42MTIzIDcuMTMyODFDOC40MzI4MiA3LjE0Mzg2IDguMjYwMzIgNy4xNTY4OSA4LjA5NDczIDcuMTcxODhDOC4wNzYyNCA3LjI4MzQzIDguMDU1NTQgNy40MTQ1MyA4LjAzNDE4IDcuNTY2NDFDNy45ODc0NCA3Ljg5ODgzIDcuOTQ2NiA4LjMwMjk4IDcuOTEzMDkgOC43ODMyQzcuODgwNjMgOS4yNDg0MiA3Ljg2NDI2IDkuNzYyNTEgNy44NjQyNiAxMC4zMjYyVjExLjg2ODJDOC4yMjAwOSAxMS44OTg5IDguNjUzMTkgMTEuOTI4NiA5LjE2Njk5IDExLjk1NDFDOS45Njk5IDExLjk5MzcgMTAuOTE0NCAxMi4wMTU2IDEyLjAwMjkgMTIuMDIxNUMxMy4wODY2IDEyLjAxNTYgMTQuMDI1OCAxMS45OTM3IDE0LjgyMzIgMTEuOTU0MUgxNC44MjQyQzE1LjM0MjIgMTEuOTI4NiAxNS43Nzc2IDExLjg5ODkgMTYuMTM0OCAxMS44NjgyVjEwLjMyNjJDMTYuMTM0OCA5Ljc2MjUxIDE2LjExODQgOS4yNDg0MiAxNi4wODU5IDguNzgzMkMxNi4wNTI0IDguMzAyOTggMTYuMDExNiA3Ljg5ODgzIDE1Ljk2NDggNy41NjY0MUMxNS45NDM1IDcuNDE0ODkgMTUuOTIxOCA3LjI4NDIzIDE1LjkwMzMgNy4xNzI4NUMxNS43Mzc1IDcuMTU3NDMgMTUuNTYyNCA3LjE0NDE3IDE1LjM3NzkgNy4xMzI4MUwxNS4zNjYyIDcuMTMxODRMMTUuMzUzNSA3LjEzMDg2QzE1LjAwODQgNy4xMDM5MSAxNC41Njk2IDcuMDgxNjEgMTQuMDMyMiA3LjA2NDQ1QzEzLjUwMjUgNy4wNDc1NSAxMi44Mjc0IDcuMDM5MDYgMTIuMDAzOSA3LjAzOTA2Wk0xNC4yNDQxIDMuMTk4MjRDMTQuNDI1OCAzLjE5ODI0IDE0LjU3MjMgMy4yNTM5MSAxNC42ODM2IDMuMzY1MjNDMTQuNzk0OCAzLjQ3NjUzIDE0Ljg1MDYgMy42MjAyNSAxNC44NTA2IDMuNzk1OUMxNC44NTA1IDMuOTcxNDYgMTQuNzk0OCA0LjExODI3IDE0LjY4MzYgNC4yMzUzNUMxNC41NzIzIDQuMzQ2NTIgMTQuNDI1NiA0LjQwMjM0IDE0LjI0NDEgNC40MDIzNEg5Ljc1MjkzQzkuNTcxNDIgNC40MDIzNCA5LjQyNDc3IDQuMzQ2NTIgOS4zMTM0OCA0LjIzNTM1QzkuMjA4MTEgNC4xMTgyNyA5LjE1NTM3IDMuOTcxNDYgOS4xNTUyNyAzLjc5NTlDOS4xNTUyNyAzLjYyMDI1IDkuMjA4MTcgMy40NzY1MyA5LjMxMzQ4IDMuMzY1MjNDOS40MjQ4IDMuMjUzOTEgOS41NzEyOSAzLjE5ODI0IDkuNzUyOTMgMy4xOTgyNEgxNC4yNDQxWiIgZmlsbD0iYmxhY2siLz4KPC9nPgo8ZGVmcz4KPGNsaXBQYXRoIGlkPSJjbGlwMF80NTg0XzMxNiI+CjxyZWN0IHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgZmlsbD0id2hpdGUiLz4KPC9jbGlwUGF0aD4KPC9kZWZzPgo8L3N2Zz4K");
}
.journey-tag.flight::before {
  display: block;
  background-image: url("data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPGcgY2xpcC1wYXRoPSJ1cmwoI2NsaXAwXzQ1ODRfMzE0KSI+CjxwYXRoIGQ9Ik0xNS44MTI1IDE5LjM5NTRDMTUuOTczNSAxOS43OTQgMTYuNDg5MSAxOS44OTg4IDE2Ljc5MzEgMTkuNTk0OUwxNy40NTg2IDE4LjkyOTRDMTcuNzM1OSAxOC42NTIgMTcuODYwMiAxOC4yNTY2IDE3Ljc5MTQgMTcuODcwNEwxNi40MDk5IDEwLjExNDFMMjAuMzE4NCA2LjQ1MzI1QzIxLjU0NTkgNS4yNzgzMyAyMS4yNTM0IDMuNzQzNzcgMjAuNzU1NyAzLjI0NjAxQzIwLjI1NzkgMi43NDgyNSAxOC42NjIyIDIuNTMxOTUgMTcuNTUwNiAzLjY4NTVMMTMuODk1MSA3LjU5OTMyTDYuMTMxNjggNi4yMTA3NkM1Ljc0NTI1IDYuMTQxNjUgNS4zNDk0NSA2LjI2NTkxIDUuMDcxODcgNi41NDM0OUw0LjQwNjM3IDcuMjA4OThDNC4xMDI1MyA3LjUxMjgzIDQuMjA3MjIgOC4wMjgyMSA0LjYwNTU0IDguMTg5NDJMMTAuNzk4NSAxMC42OTU5TDcuMjM1MjMgMTQuNzAyMUw0Ljg1MTI3IDE0LjAxNzdDNC42NDE1NyAxMy45NTc1IDQuNDE1NzIgMTQuMDE1OSA0LjI2MTQ1IDE0LjE3MDFMMy4zMDY3OSAxNS4xMjQ4QzMuMTY1MjQgMTUuMjY2MyAzLjE5OTQgMTUuNTA0MiAzLjM3NTA5IDE1LjYwMDJMNi42MjY4MSAxNy4zNzY4TDguNDAxNTEgMjAuNjI2NUM4LjQ5NzQ3IDIwLjgwMjIgOC43MzUzNiAyMC44MzY0IDguODc2OTMgMjAuNjk0OEw5LjgzMTUzIDE5Ljc0MDJDOS45ODU4IDE5LjU4NTkgMTAuMDQ0MiAxOS4zNjAxIDkuOTgzOTcgMTkuMTUwNEw5LjI5OTYxIDE2Ljc2NjRMMTMuMzEzMyAxMy4yMTA3TDE1LjgxMjUgMTkuMzk1NFoiIHN0cm9rZT0iYmxhY2siIHN0cm9rZS13aWR0aD0iMS41Ii8+CjwvZz4KPGRlZnM+CjxjbGlwUGF0aCBpZD0iY2xpcDBfNDU4NF8zMTQiPgo8cmVjdCB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIGZpbGw9IndoaXRlIi8+CjwvY2xpcFBhdGg+CjwvZGVmcz4KPC9zdmc+Cg==");
}
.journey-title {
  min-width: 0;
}
.journey-title h2 {
  margin: 9px 0 6px;
  overflow-wrap: anywhere;
  font-size: 24px;
  line-height: 1;
  font-weight: 850;
}
.journey-title p {
  margin: 0;
  overflow-wrap: anywhere;
  color: var(--muted);
  font-size: 13px;
  line-height: 1.42;
}
.journey-expand {
  border: 1px solid var(--line);
  border-radius: 999px;
  min-width: 52px;
  min-height: 36px;
  padding: 8px 11px;
  background: var(--ink);
  color: var(--void);
  font-size: 12px;
  font-weight: 800;
}
.journey-mainline {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
  gap: 10px;
  align-items: center;
  margin-top: 10px;
}
.time-block {
  min-width: 0;
}
.time-block b {
  display: block;
  overflow-wrap: anywhere;
  font-variant-numeric: tabular-nums;
  font-size: 22px;
  line-height: 1;
}
.time-block span {
  display: block;
  margin-top: 5px;
  overflow-wrap: anywhere;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.25;
}
.track {
  position: relative;
  width: 74px;
  height: 34px;
}
.track::before {
  content: "";
  position: absolute;
  left: 4px;
  right: 4px;
  top: 16px;
  height: 2px;
  background: linear-gradient(90deg, var(--source), rgba(23, 18, 13, 0.14));
}
.track::after {
  content: "";
  position: absolute;
  right: 4px;
  top: 10px;
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: var(--source);
  box-shadow: 0 0 18px rgba(37, 24, 13, 0.12);
}
.journey-metrics {
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 8px;
  margin-top: 10px;
}
.journey-metric {
  min-width: 0;
  border-radius: 14px;
  padding: 8px;
  background: rgba(23, 18, 13, 0.05);
}
.journey-metric span {
  display: block;
  color: var(--muted);
  font-size: 10px;
  line-height: 1;
}
.journey-metric b {
  display: block;
  margin-top: 6px;
  overflow-wrap: anywhere;
  color: var(--ink);
  font-size: 13px;
  line-height: 1.18;
}
.journey-card:not(.expanded) .journey-detail { display: none; }
.journey-detail {
  position: relative;
  z-index: 1;
  margin-top: 11px;
  border-top: 1px solid var(--line);
  padding-top: 11px;
}
.detail-grid {
  display: grid;
  gap: 8px;
}
.detail-row {
  display: grid;
  grid-template-columns: 78px minmax(0, 1fr);
  gap: 10px;
  color: var(--muted);
  font-size: 12px;
  line-height: 1.45;
  overflow-wrap: anywhere;
}
.detail-row b {
  color: var(--ink);
  font-weight: 760;
}
.journey-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 11px;
}
.journey-action {
  border: 0;
  border-radius: 999px;
  min-height: 42px;
  padding: 10px 14px;
  background: var(--source);
  color: #fffaf1;
  font-size: 13px;
  font-weight: 830;
}
.journey-action.secondary {
  background: var(--ink);
  color: var(--void);
  border: 1px solid var(--line);
}
@media (min-width: 680px) {
  .route-hero { min-height: 430px; padding: 36px 28px 28px; }
  .route-hero h1 { font-size: 58px; }
  .journey-board { padding-left: 22px; padding-right: 22px; grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .journey-card.featured { grid-column: 1 / -1; }
}
@media (max-width: 380px) {
  .route-hero h1 { font-size: 40px; }
  .route-map { padding: 10px; }
  .route-cities { grid-template-columns: minmax(0, 1fr) 42px minmax(0, 1fr); gap: 6px; }
  .route-city { min-height: 74px; padding: 10px; }
  .route-city b { font-size: 17px; }
  .route-mid { width: 42px; height: 30px; }
  .route-mid::before { left: 5px; right: 5px; top: 18px; }
  .track { display: none; }
  .route-stats { grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 6px; }
  .route-stat { padding: 8px 7px; }
  .route-stat b { font-size: 13px; }
  .journey-metrics { grid-template-columns: 1fr; }
}
@media (prefers-reduced-motion: no-preference) {
  .route-mid::after, .track::after { animation: travelPulse 2.6s ease-in-out infinite; }
  .journey-card { transition: transform 180ms ease, border-color 180ms ease; }
  .journey-card:active { transform: scale(0.992); }
}
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.001ms !important;
    animation-iteration-count: 1 !important;
    scroll-behavior: auto !important;
    transition-duration: 0.001ms !important;
  }
}
@keyframes travelPulse {
  0%, 100% { opacity: 0.72; }
  50% { opacity: 1; }
}
`;

const TRAVEL_HOME_JS: string = `
(function () {
  var node = document.getElementById('home-data');
  var data = {};
  try { data = JSON.parse(node && node.textContent ? node.textContent : '{}') || {}; } catch (error) { data = {}; }
  var app = document.getElementById('app');
  if (!app) { return; }
  var state = { mode: 'all', trainFastest: false, trainAvailable: false, trainShowMore: false, expandedKey: '' };
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
  function durationMinutes(value) {
    var raw = text(value);
    var colon = raw.match(/([0-9]+):([0-9]+)/);
    if (colon) { return Number(colon[1]) * 60 + Number(colon[2]); }
    var hours = raw.match(/([0-9]+)\\s*(?:h|小时|时)/i);
    var minutes = raw.match(/([0-9]+)\\s*(?:m|分钟|分)/i);
    var total = (hours ? Number(hours[1]) * 60 : 0) + (minutes ? Number(minutes[1]) : 0);
    return total > 0 ? total : 999999;
  }
  function available(value) {
    var raw = text(value);
    if (raw.indexOf('有') >= 0 || raw.toLowerCase().indexOf('available') >= 0) { return true; }
    if (raw.indexOf('无') >= 0 && raw.indexOf('有') < 0) { return false; }
    return /[1-9][0-9]*/.test(raw);
  }
  function sourceKind(block) {
    var kind = text(block && block.kind).toLowerCase();
    var raw = [kind, text(block && block.source), metric(block, ['source', 'provider', 'sourceTag']), text(block && block.title), text(block && block.subtitle)].join(' ').toLowerCase();
    if (kind === 'train-option' || raw.indexOf('train') >= 0 || raw.indexOf('12306') >= 0 || raw.indexOf('高铁') >= 0) { return 'train'; }
    if (kind === 'flight-option' || raw.indexOf('flight') >= 0 || raw.indexOf('飞常准') >= 0 || raw.indexOf('航班') >= 0 || raw.indexOf('飞机') >= 0) { return 'flight'; }
    if (kind === 'food-result') { return 'food'; }
    return 'other';
  }
  function sourceLabel(block) {
    var source = sourceKind(block);
    var rawSource = text(block && block.source);
    if (source === 'train') { return rawSource.toLowerCase() === 'train' || rawSource.length === 0 ? '高铁 · 12306' : rawSource; }
    if (source === 'flight') { return rawSource.toLowerCase() === 'flight' || rawSource.length === 0 ? '飞机 · 飞常准' : rawSource; }
    if (source === 'food') { return text(block && block.source) || '餐饮'; }
    return text(block && block.source) || text(block && block.kind) || '结果';
  }
  function statusText(value) {
    var raw = text(value);
    var key = raw.toLowerCase();
    if (key === 'success' || key === 'available' || key === 'ready') { return '可选'; }
    if (key === 'scheduled') { return '计划'; }
    return raw;
  }
  function firstMetric(blocks, labels) {
    for (var i = 0; i < blocks.length; i += 1) {
      var value = metric(blocks[i], labels);
      if (value.length > 0) { return value; }
    }
    return '';
  }
  function shortest(blocks) {
    var best = '';
    var bestMinutes = 999999;
    blocks.forEach(function (block) {
      var value = metric(block, ['duration']);
      var minutes = durationMinutes(value);
      if (minutes < bestMinutes) {
        best = value;
        bestMinutes = minutes;
      }
    });
    return best;
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
    Array.prototype.slice.call(document.querySelectorAll('.journey-card')).forEach(function (card) {
      var expanded = card.getAttribute('data-card-key') === state.expandedKey;
      card.classList.toggle('expanded', expanded);
      card.setAttribute('aria-expanded', expanded ? 'true' : 'false');
      var button = card.querySelector('.journey-expand');
      if (button) { button.textContent = expanded ? '收起' : '展开'; }
    });
  }
  function handleLocalAction(action) {
    if (isBusy) { return false; }
    var id = text(action && action.id);
    if (id === 'travel_show_all') { state.mode = 'all'; applyView(); return true; }
    if (id === 'travel_filter_train') { state.mode = 'train'; applyView(); return true; }
    if (id === 'travel_filter_flight') { state.mode = 'flight'; applyView(); return true; }
    if (id === 'client_show_more') { state.trainShowMore = !state.trainShowMore; applyView(); return true; }
    if (id === 'client_sort_fastest') { state.trainFastest = !state.trainFastest; applyView(); return true; }
    if (id === 'client_filter_available') { state.trainAvailable = !state.trainAvailable; applyView(); return true; }
    return false;
  }
  function updateControls() {
    Array.prototype.slice.call(document.querySelectorAll('.travel-control')).forEach(function (button) {
      var id = button.getAttribute('data-action') || '';
      var active = false;
      if (id === 'travel_show_all') { active = state.mode === 'all'; }
      if (id === 'travel_filter_train') { active = state.mode === 'train'; }
      if (id === 'travel_filter_flight') { active = state.mode === 'flight'; }
      if (id === 'client_show_more') { active = state.trainShowMore; }
      if (id === 'client_sort_fastest') { active = state.trainFastest; }
      if (id === 'client_filter_available') { active = state.trainAvailable; }
      button.classList.toggle('active', active);
    });
  }
  function applyView() {
    var board = document.querySelector('.journey-board');
    var cards = Array.prototype.slice.call(document.querySelectorAll('.journey-card'));
    cards.sort(function (left, right) {
      var leftSource = left.getAttribute('data-source') || '';
      var rightSource = right.getAttribute('data-source') || '';
      if (state.trainFastest && leftSource === 'train' && rightSource === 'train') {
        return durationMinutes(left.getAttribute('data-duration') || '') - durationMinutes(right.getAttribute('data-duration') || '');
      }
      return numberIn(left.getAttribute('data-index') || '') - numberIn(right.getAttribute('data-index') || '');
    });
    cards.forEach(function (card) { if (board) { board.appendChild(card); } });
    var visible = 0;
    var trainVisible = 0;
    cards.forEach(function (card) {
      var source = card.getAttribute('data-source') || '';
      var keep = true;
      if (state.mode === 'train') { keep = source === 'train'; }
      if (state.mode === 'flight') { keep = source === 'flight'; }
      if (source === 'train' && state.trainAvailable) { keep = keep && available(card.getAttribute('data-availability') || ''); }
      if (source === 'train' && keep) {
        trainVisible += 1;
        if (!state.trainShowMore && trainVisible > 6) { keep = false; }
      }
      if (keep) { visible += 1; }
      card.style.display = keep ? '' : 'none';
    });
    var count = document.getElementById('journey-count');
    if (count) { count.textContent = String(visible) + ' / ' + String(cards.length) + ' 条'; }
    var empty = document.getElementById('journey-empty');
    if (empty) { empty.style.display = cards.length > 0 && visible === 0 ? '' : 'none'; }
    updateControls();
  }
  function detailRow(parent, label, value) {
    if (text(value).length === 0) { return; }
    var row = add(parent, 'div', 'detail-row');
    add(row, 'b', '', labelText(label));
    add(row, 'span', '', value);
  }
  function labelText(label) {
    var raw = text(label);
    if (raw === 'source') { return '来源'; }
    if (raw === 'from' || raw === 'dep') { return '出发'; }
    if (raw === 'to' || raw === 'arr') { return '到达'; }
    if (raw === 'depart' || raw === 'depTime') { return raw === 'depTime' ? '起飞' : '发车'; }
    if (raw === 'arrive' || raw === 'arrTime') { return raw === 'arrTime' ? '落地' : '到站'; }
    if (raw === 'duration') { return '耗时'; }
    if (raw === 'price') { return '价格'; }
    if (raw === 'availability' || raw === 'status') { return '状态'; }
    if (raw === 'seats') { return '座席'; }
    if (raw === 'business') { return '商务座'; }
    if (raw === 'first') { return '一等座'; }
    if (raw === 'second') { return '二等座'; }
    if (raw === 'noSeat') { return '无座'; }
    if (raw === 'hardSeat') { return '硬座'; }
    if (raw === 'sleeperSoft') { return '卧铺'; }
    if (raw === 'airline') { return '航司'; }
    if (raw === 'detail') { return '详情'; }
    return raw;
  }
  function addActionButtons(parent, actions) {
    var kept = list(actions).filter(function (action) { return text(action && (action.label || action.id)).length > 0; });
    if (kept.length === 0) { return; }
    var row = add(parent, 'div', 'journey-actions');
    kept.forEach(function (action, index) {
      var button = add(row, 'button', index === 0 ? 'journey-action' : 'journey-action secondary', action.label || action.id);
      button.type = 'button';
      button.disabled = isBusy;
      button.addEventListener('click', function (event) {
        event.stopPropagation();
        if (isBusy) { return; }
        if (handleLocalAction(action)) { return; }
        postAction(action);
      });
    });
  }
  app.textContent = '';
  var blocks = list(data.blocks);
  var travelBlocks = blocks.filter(function (block) {
    var source = sourceKind(block);
    return source === 'train' || source === 'flight';
  });
  var shell = add(app, 'main', 'itinerary-shell');
  var hero = add(shell, 'header', 'route-hero');
  add(hero, 'div', 'route-kicker', '出行方案 · 实时候选');
  add(hero, 'h1', '', text(data.title) || '今日出行方案');
  add(hero, 'p', '', text(data.subtitle) || '高铁和航班结果来自真实工具返回，页面只做本地筛选和展示。');
  var map = add(hero, 'section', 'route-map');
  var from = firstMetric(travelBlocks, ['from', 'dep']) || '出发';
  var to = firstMetric(travelBlocks, ['to', 'arr']) || '到达';
  var cities = add(map, 'div', 'route-cities');
  var fromNode = add(cities, 'div', 'route-city');
  add(fromNode, 'b', '', from);
  add(fromNode, 'span', '', '出发');
  add(cities, 'div', 'route-mid');
  var toNode = add(cities, 'div', 'route-city');
  add(toNode, 'b', '', to);
  add(toNode, 'span', '', '到达');
  var stats = add(map, 'div', 'route-stats');
  var trainCount = travelBlocks.filter(function (block) { return sourceKind(block) === 'train'; }).length;
  var flightCount = travelBlocks.filter(function (block) { return sourceKind(block) === 'flight'; }).length;
  [
    ['候选', String(travelBlocks.length) + ' 条'],
    ['高铁 / 航班', String(trainCount) + ' / ' + String(flightCount)],
    ['最短耗时', shortest(travelBlocks) || '待确认']
  ].forEach(function (item) {
    var stat = add(stats, 'div', 'route-stat');
    add(stat, 'span', '', item[0]);
    add(stat, 'b', '', item[1]);
  });
  var controls = add(shell, 'nav', 'travel-controls');
  var localControls = [
    { id: 'travel_show_all', label: '全部', prompt: 'travel_show_all', variant: 'secondary', kind: 'client' },
    { id: 'travel_filter_train', label: '高铁', prompt: 'travel_filter_train', variant: 'secondary', kind: 'client' },
    { id: 'travel_filter_flight', label: '飞机', prompt: 'travel_filter_flight', variant: 'secondary', kind: 'client' },
    { id: 'client_sort_fastest', label: '最快', prompt: 'client_sort_fastest', variant: 'secondary', kind: 'client' },
    { id: 'client_filter_available', label: '有票', prompt: 'client_filter_available', variant: 'secondary', kind: 'client' },
    { id: 'client_show_more', label: '更多', prompt: 'client_show_more', variant: 'secondary', kind: 'client' }
  ];
  var seen = {};
  localControls.concat(list(data.actions)).forEach(function (action) {
    var id = text(action && action.id);
    if (id.length === 0 || seen[id]) { return; }
    seen[id] = true;
    var label = text(action && action.label);
    if (id === 'travel_filter_train') { label = '高铁'; }
    if (id === 'travel_filter_flight') { label = '飞机'; }
    if (id === 'client_sort_fastest') { label = '最快'; }
    if (id === 'client_filter_available') { label = '有票'; }
    if (id === 'client_show_more') { label = '更多'; }
    var button = add(controls, 'button', 'travel-control', label || id);
    button.type = 'button';
    button.disabled = isBusy;
    button.setAttribute('data-action', id);
    button.addEventListener('click', function () {
      if (handleLocalAction(action)) { return; }
      postAction(action);
    });
  });
  var countBadge = add(controls, 'span', 'travel-control', '0 / 0 条');
  countBadge.id = 'journey-count';
  var board = add(shell, 'section', 'journey-board');
  var empty = add(board, 'div', 'journey-empty', '当前筛选下暂无匹配出行方案。');
  empty.id = 'journey-empty';
  empty.style.display = 'none';
  blocks.forEach(function (block, index) {
    var source = sourceKind(block);
    var key = text(block.id) || String(index);
    var card = add(board, 'article', index === 0 ? 'journey-card featured' : 'journey-card');
    card.setAttribute('data-card-key', key);
    card.setAttribute('data-source', source);
    card.setAttribute('data-index', String(index));
    card.setAttribute('data-duration', metric(block, ['duration']));
    card.setAttribute('data-availability', [metric(block, ['availability', 'status']), metric(block, ['seats', 'business', 'first', 'second', 'noSeat', 'hardSeat', 'sleeperSoft'])].join(' '));
    card.setAttribute('aria-expanded', 'false');
    var top = add(card, 'div', 'journey-top');
    var title = add(top, 'div', 'journey-title');
    add(title, 'div', 'journey-tag ' + source, sourceLabel(block));
    add(title, 'h2', '', text(block.title) || text(block.kind) || '出行结果');
    var expand = add(top, 'button', 'journey-expand', '展开');
    expand.type = 'button';
    expand.addEventListener('click', function (event) { event.stopPropagation(); setExpanded(key); });
    card.addEventListener('click', function () { setExpanded(key); });
    var mainline = add(card, 'div', 'journey-mainline');
    var left = add(mainline, 'div', 'time-block');
    add(left, 'b', '', metric(block, ['depart', 'depTime']) || '--');
    add(left, 'span', '', metric(block, ['from', 'dep']) || '出发');
    add(mainline, 'div', 'track');
    var right = add(mainline, 'div', 'time-block');
    add(right, 'b', '', metric(block, ['arrive', 'arrTime']) || '--');
    add(right, 'span', '', metric(block, ['to', 'arr']) || '到达');
    var metrics = add(card, 'div', 'journey-metrics');
    [
      ['耗时', metric(block, ['duration']) || '待确认']
    ].forEach(function (item) {
      var box = add(metrics, 'div', 'journey-metric');
      add(box, 'span', '', item[0]);
      add(box, 'b', '', item[1]);
    });
    var detail = add(card, 'div', 'journey-detail');
    var grid = add(detail, 'div', 'detail-grid');
    detailRow(grid, '来源', sourceLabel(block));
    list(block.metrics).concat(list(block.rows)).forEach(function (item) {
      if (text(item && item.label) === 'source') { return; }
      detailRow(grid, text(item && item.label), text(item && item.value));
    });
    addActionButtons(detail, block.actions);
  });
  applyView();
})();
`;

export function shouldRenderTravelHomeDocument(document: HtmlHomeDocument): boolean {
  if (document.kind !== 'travel') {
    return false;
  }
  const blocks = document.blocks;
  for (let index = 0; index < blocks.length; index++) {
    const kind = blocks[index].kind;
    if (kind === 'travel-option' || kind === 'train-option' || kind === 'flight-option') {
      return true;
    }
  }
  return false;
}

export function renderTravelHomeDocument(document: HtmlHomeDocument, isBusy: boolean = false): string {
  const renderDocument: HtmlTravelHomeDocumentWithBusy = {
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
    isBusy: isBusy || (document as HtmlTravelHomeDocumentWithBusy).isBusy === true
  };
  const json = escapeScriptJson(JSON.stringify(renderDocument));
  const title = escapeHtmlText(document.title.length > 0 ? document.title : '今日出行方案');
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${title}</title>
<style>${TRAVEL_HOME_CSS}</style>
</head>
<body>
<div id="app"></div>
<script id="home-data" type="application/json">${json}</script>
<script>${TRAVEL_HOME_JS}</script>
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

function escapeHtmlText(value: HtmlTravelTextValue): string {
  if (value === undefined || value === null) {
    return '';
  }
  return value.toString()
    .split('&').join('&amp;')
    .split('<').join('&lt;')
    .split('>').join('&gt;')
    .split('"').join('&quot;');
}
