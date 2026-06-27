export const COLOR_PAGE: string = '#F5F2EE';
export const COLOR_PANEL: string = '#F8F5F0';
export const COLOR_GLASS: string = '#FFFFFFD9';
export const COLOR_CARD: string = '#FFFFFF';
export const COLOR_CARD_RAISED: string = '#FFFFFF';
export const COLOR_FIELD: string = '#FFFFFF';
export const COLOR_CARD_INSET: string = '#F0E8DF';
export const COLOR_CARD_EDGE: string = '#DED6CC';
export const COLOR_LINE: string = '#E7DFD6';
export const COLOR_INK: string = '#211B17';
export const COLOR_TEXT: string = '#493F38';
export const COLOR_MUTED: string = '#7A6E64';
export const COLOR_ACCENT: string = '#995F4C';
export const COLOR_ACCENT_DARK: string = '#995F4C';
export const COLOR_ACCENT_DEEP: string = '#7D4B3B';
export const COLOR_ACCENT_SOFT: string = '#EFE2DC';
export const COLOR_BUTTON_TEXT: string = '#F7FFFD';
export const COLOR_ERROR: string = '#B04A42';
export const COLOR_ERROR_SOFT: string = '#F6E2DF';
export const COLOR_ERROR_LINE: string = '#D6AAA4';
export const COLOR_CARD_SHADOW: string = '#9F8D7C22';
export const COLOR_PANEL_SHADOW: string = '#9F8D7C24';
export const COLOR_CARD_GLOW: string = '#9F8D7C24';
export const COLOR_ACCENT_SHADOW: string = '#995F4C33';
export const COLOR_ACTION_ACTIVATED: string = COLOR_ACCENT_DEEP;
export const COLOR_ACTION_ACTIVATED_TEXT: string = COLOR_BUTTON_TEXT;
export const COLOR_ACTION_ACTIVATED_EDGE: string = COLOR_ACCENT;
export const COLOR_ACTION_DEACTIVATED: string = '#E8E0D7';
export const COLOR_ACTION_DEACTIVATED_TEXT: string = '#8A7D72';
export const COLOR_ACTION_DEACTIVATED_EDGE: string = '#D7CEC4';
export const COLOR_TRAVEL_TRAIN: string = '#397A55';
export const COLOR_TRAVEL_TRAIN_SOFT: string = '#E2F1E7';
export const COLOR_TRAVEL_TRAIN_LINE: string = '#9CCAB0';
export const COLOR_TRAVEL_TRAIN_CARD: string = '#F2FAF4';
export const COLOR_TRAVEL_TRAIN_GLOW: string = '#397A5526';
export const COLOR_TRAVEL_FLIGHT: string = '#476F9F';
export const COLOR_TRAVEL_FLIGHT_SOFT: string = '#E5EEF8';
export const COLOR_TRAVEL_FLIGHT_LINE: string = '#A8BEDC';
export const COLOR_TRAVEL_FLIGHT_CARD: string = '#F3F7FC';
export const COLOR_TRAVEL_FLIGHT_GLOW: string = '#476F9F26';
export const COLOR_SOCIAL: string = '#A77816';
export const COLOR_SOCIAL_SOFT: string = '#F5EAD0';
export const COLOR_SOCIAL_LINE: string = '#D4B670';
export const COLOR_SOCIAL_CARD: string = '#FBF6EA';
export const COLOR_SOCIAL_GLOW: string = '#A7781624';
export const COLOR_FOOD_AMAP: string = '#2F8F5F';
export const COLOR_FOOD_AMAP_SOFT: string = '#E1F2E8';
export const COLOR_FOOD_AMAP_LINE: string = '#93C9AC';
export const COLOR_FOOD_AMAP_CARD: string = '#F2FAF5';
export const COLOR_FOOD_AMAP_GLOW: string = '#2F8F5F24';
export const COLOR_FOOD_TENCENT: string = '#2D78A8';
export const COLOR_FOOD_TENCENT_SOFT: string = '#E3F0F8';
export const COLOR_FOOD_TENCENT_LINE: string = '#94C4E0';
export const COLOR_FOOD_TENCENT_CARD: string = '#F2F8FC';
export const COLOR_FOOD_TENCENT_GLOW: string = '#2D78A824';
export const COLOR_FOOD_BAIDU: string = '#B34F66';
export const COLOR_FOOD_BAIDU_SOFT: string = '#F7E5EA';
export const COLOR_FOOD_BAIDU_LINE: string = '#DAA7B3';
export const COLOR_FOOD_BAIDU_CARD: string = '#FCF3F5';
export const COLOR_FOOD_BAIDU_GLOW: string = '#B34F6624';
export const COLOR_FOOD_MEITUAN: string = '#A77816';
export const COLOR_FOOD_MEITUAN_SOFT: string = '#F6ECCD';
export const COLOR_FOOD_MEITUAN_LINE: string = '#D9BD75';
export const COLOR_FOOD_MEITUAN_CARD: string = '#FCF7E9';
export const COLOR_FOOD_MEITUAN_GLOW: string = '#A7781624';
export const COLOR_FOOD_TAOBAO: string = '#7A5BB5';
export const COLOR_FOOD_TAOBAO_SOFT: string = '#ECE5F7';
export const COLOR_FOOD_TAOBAO_LINE: string = '#B9A8DD';
export const COLOR_FOOD_TAOBAO_CARD: string = '#F7F3FC';
export const COLOR_FOOD_TAOBAO_GLOW: string = '#7A5BB524';
export const COLOR_FOOD_MCD: string = '#B57915';
export const COLOR_FOOD_MCD_SOFT: string = '#F7ECCF';
export const COLOR_FOOD_MCD_LINE: string = '#DDBA73';
export const COLOR_FOOD_MCD_CARD: string = '#FCF7EA';
export const COLOR_FOOD_MCD_GLOW: string = '#B5791524';
export const COLOR_FOOD_LUCKIN: string = '#466EB8';
export const COLOR_FOOD_LUCKIN_SOFT: string = '#E6EDF9';
export const COLOR_FOOD_LUCKIN_LINE: string = '#A9BDE4';
export const COLOR_FOOD_LUCKIN_CARD: string = '#F3F7FD';
export const COLOR_FOOD_LUCKIN_GLOW: string = '#466EB824';

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
