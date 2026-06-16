export const COLOR_PAGE: string = '#05080D';
export const COLOR_PANEL: string = '#0D151C';
export const COLOR_GLASS: string = '#111D25';
export const COLOR_CARD: string = '#17252D';
export const COLOR_CARD_RAISED: string = '#1D3039';
export const COLOR_FIELD: string = '#091017';
export const COLOR_CARD_INSET: string = '#0C161D';
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
export const COLOR_ACTION_ACTIVATED: string = COLOR_ACCENT_DEEP;
export const COLOR_ACTION_ACTIVATED_TEXT: string = COLOR_BUTTON_TEXT;
export const COLOR_ACTION_ACTIVATED_EDGE: string = COLOR_ACCENT;
export const COLOR_ACTION_DEACTIVATED: string = '#1B2931';
export const COLOR_ACTION_DEACTIVATED_TEXT: string = '#9DAFB4';
export const COLOR_ACTION_DEACTIVATED_EDGE: string = '#334B55';
export const COLOR_TRAVEL_TRAIN: string = '#72E59D';
export const COLOR_TRAVEL_TRAIN_SOFT: string = '#132D22';
export const COLOR_TRAVEL_TRAIN_LINE: string = '#347B54';
export const COLOR_TRAVEL_TRAIN_CARD: string = '#121F18';
export const COLOR_TRAVEL_TRAIN_GLOW: string = '#0D3A2280';
export const COLOR_TRAVEL_FLIGHT: string = '#7AA7FF';
export const COLOR_TRAVEL_FLIGHT_SOFT: string = '#142545';
export const COLOR_TRAVEL_FLIGHT_LINE: string = '#456DAE';
export const COLOR_TRAVEL_FLIGHT_CARD: string = '#111A2B';
export const COLOR_TRAVEL_FLIGHT_GLOW: string = '#102B6680';
export const COLOR_SOCIAL: string = '#F1C76A';
export const COLOR_SOCIAL_SOFT: string = '#322819';
export const COLOR_SOCIAL_LINE: string = '#8B6B2A';
export const COLOR_SOCIAL_CARD: string = '#1D1B15';
export const COLOR_SOCIAL_GLOW: string = '#5A3E0F66';
export const COLOR_FOOD_AMAP: string = '#53E08A';
export const COLOR_FOOD_AMAP_SOFT: string = '#122D22';
export const COLOR_FOOD_AMAP_LINE: string = '#348B5A';
export const COLOR_FOOD_AMAP_CARD: string = '#122218';
export const COLOR_FOOD_AMAP_GLOW: string = '#0A402680';
export const COLOR_FOOD_TENCENT: string = '#68C7FF';
export const COLOR_FOOD_TENCENT_SOFT: string = '#102B3B';
export const COLOR_FOOD_TENCENT_LINE: string = '#367DA6';
export const COLOR_FOOD_TENCENT_CARD: string = '#10202C';
export const COLOR_FOOD_TENCENT_GLOW: string = '#0C385B80';
export const COLOR_FOOD_BAIDU: string = '#FF7C8D';
export const COLOR_FOOD_BAIDU_SOFT: string = '#341A22';
export const COLOR_FOOD_BAIDU_LINE: string = '#A84856';
export const COLOR_FOOD_BAIDU_CARD: string = '#21141A';
export const COLOR_FOOD_BAIDU_GLOW: string = '#61202A66';
export const COLOR_FOOD_MEITUAN: string = '#F5C84C';
export const COLOR_FOOD_MEITUAN_SOFT: string = '#32280F';
export const COLOR_FOOD_MEITUAN_LINE: string = '#94742A';
export const COLOR_FOOD_MEITUAN_CARD: string = '#221C0E';
export const COLOR_FOOD_MEITUAN_GLOW: string = '#61481066';
export const COLOR_FOOD_TAOBAO: string = '#B58BFF';
export const COLOR_FOOD_TAOBAO_SOFT: string = '#251B3D';
export const COLOR_FOOD_TAOBAO_LINE: string = '#6E52AF';
export const COLOR_FOOD_TAOBAO_CARD: string = '#191329';
export const COLOR_FOOD_TAOBAO_GLOW: string = '#3D267066';

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
