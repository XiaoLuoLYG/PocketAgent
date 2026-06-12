export const COLOR_PAGE: string = '#05080D';
export const COLOR_PANEL: string = '#0D151C';
export const COLOR_GLASS: string = '#111D25';
export const COLOR_CARD: string = '#17252D';
export const COLOR_CARD_RAISED: string = '#1D3039';
export const COLOR_FIELD: string = '#091017';
export const COLOR_CARD_EDGE: string = '#38545E';
export const COLOR_LINE: string = '#263943';
export const COLOR_INK: string = '#F3FBFA';
export const COLOR_TEXT: string = '#D4E5E6';
export const COLOR_MUTED: string = '#8A9DA3';
export const COLOR_ACCENT: string = '#35D6B8';
export const COLOR_ACCENT_DARK: string = '#83F2DC';
export const COLOR_ACCENT_DEEP: string = '#0E6F62';
export const COLOR_ACCENT_SOFT: string = '#102F2D';
export const COLOR_BUTTON_TEXT: string = '#F7FFFD';
export const COLOR_ERROR: string = '#FF8A84';
export const COLOR_ERROR_SOFT: string = '#351B1D';
export const COLOR_ERROR_LINE: string = '#7B393A';
export const COLOR_CARD_SHADOW: string = '#020B10D0';
export const COLOR_PANEL_SHADOW: string = '#020B10C8';
export const COLOR_CARD_GLOW: string = '#0F4D4566';
export const COLOR_ACCENT_SHADOW: string = '#0B514880';

export function statusColor(status: string): string {
  if (status === 'ready') {
    return COLOR_ACCENT_DARK;
  }
  if (status === 'checking') {
    return '#4FDBCA';
  }
  if (status === 'thinking' || status === 'calling_tool') {
    return COLOR_ACCENT_DARK;
  }
  if (status === 'error') {
    return COLOR_ERROR;
  }
  return COLOR_MUTED;
}

export function statusBackground(status: string): string {
  if (status === 'ready') {
    return COLOR_ACCENT_SOFT;
  }
  if (status === 'checking') {
    return '#123039';
  }
  if (status === 'thinking' || status === 'calling_tool') {
    return COLOR_ACCENT_SOFT;
  }
  if (status === 'error') {
    return COLOR_ERROR_SOFT;
  }
  return COLOR_CARD;
}
