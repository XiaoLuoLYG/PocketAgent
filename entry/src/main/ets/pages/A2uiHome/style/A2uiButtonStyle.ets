import {
  COLOR_ACCENT,
  COLOR_ACCENT_DEEP,
  COLOR_ACTION_ACTIVATED,
  COLOR_ACTION_ACTIVATED_EDGE,
  COLOR_ACTION_ACTIVATED_TEXT,
  COLOR_ACTION_DEACTIVATED,
  COLOR_ACTION_DEACTIVATED_EDGE,
  COLOR_ACTION_DEACTIVATED_TEXT,
  COLOR_BUTTON_TEXT,
  COLOR_CARD_EDGE,
  COLOR_CARD_RAISED,
  COLOR_ERROR,
  COLOR_ERROR_SOFT,
  COLOR_INK,
  COLOR_LINE,
  COLOR_PAGE
} from './A2uiHomeTheme';

export const A2UI_CIRCLE_BUTTON_SIZE: number = 44;
export const A2UI_CIRCLE_BUTTON_ICON_SIZE: number = 22;
export const A2UI_CIRCLE_BUTTON_BACKGROUND: string = COLOR_PAGE;
export const A2UI_CIRCLE_BUTTON_BORDER: string = COLOR_LINE;

export interface A2uiButtonVisualStyle {
  backgroundColor: string;
  borderColor: string;
  textColor: string;
  opacity: number;
}

export function resolveA2uiButtonColor(overrideColor: string, fallbackColor: string): string {
  return overrideColor.length > 0 ? overrideColor : fallbackColor;
}

export function resolveA2uiButtonStyle(tone: string, active: boolean, isEnabled: boolean): A2uiButtonVisualStyle {
  if (!isEnabled) {
    return {
      backgroundColor: COLOR_ACTION_DEACTIVATED,
      borderColor: COLOR_ACTION_DEACTIVATED_EDGE,
      textColor: COLOR_ACTION_DEACTIVATED_TEXT,
      opacity: 0.48
    };
  }
  if (tone === 'danger') {
    return {
      backgroundColor: COLOR_ERROR_SOFT,
      borderColor: COLOR_ERROR,
      textColor: COLOR_ERROR,
      opacity: 1
    };
  }
  if (active || tone === 'activated') {
    return {
      backgroundColor: COLOR_ACTION_ACTIVATED,
      borderColor: COLOR_ACTION_ACTIVATED_EDGE,
      textColor: COLOR_ACTION_ACTIVATED_TEXT,
      opacity: 1
    };
  }
  if (tone === 'primary') {
    return {
      backgroundColor: COLOR_ACCENT_DEEP,
      borderColor: COLOR_ACCENT,
      textColor: COLOR_BUTTON_TEXT,
      opacity: 1
    };
  }
  if (tone === 'deactivated') {
    return {
      backgroundColor: COLOR_ACTION_DEACTIVATED,
      borderColor: COLOR_ACTION_DEACTIVATED_EDGE,
      textColor: COLOR_BUTTON_TEXT,
      opacity: 1
    };
  }
  return {
    backgroundColor: COLOR_CARD_RAISED,
    borderColor: COLOR_CARD_EDGE,
    textColor: COLOR_INK,
    opacity: 1
  };
}
