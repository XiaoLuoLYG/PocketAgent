export const A2UI_MOTION_FAST_MS: number = 180;
export const A2UI_MOTION_NORMAL_MS: number = 260;
export const A2UI_MOTION_CURVE: Curve = Curve.EaseInOut;
export const A2UI_THINKING_DOT_MS: number = 420;
export const A2UI_ENTER_OFFSET_Y: number = 8;
export const A2UI_SURFACE_ENTER_OFFSET_Y: number = 10;
export const A2UI_THINKING_PULSE_MIN: number = 1;

export function a2uiEnterTransition(offsetY: number = A2UI_ENTER_OFFSET_Y): TransitionEffect {
  return TransitionEffect
    .opacity(0)
    .combine(TransitionEffect.translate({ x: 0, y: offsetY, z: 0 }))
    .animation({ duration: A2UI_MOTION_NORMAL_MS, curve: A2UI_MOTION_CURVE });
}

function normalizedStep(value: number): number {
  let step = value;
  while (step < 0) {
    step = step + 3;
  }
  while (step >= 3) {
    step = step - 3;
  }
  return step;
}

export function a2uiThinkingDotIntensity(index: number, activeStep: number): number {
  const step = normalizedStep(activeStep);
  if (index === step) {
    return 1;
  }
  if (index === normalizedStep(step - 1)) {
    return 0.45;
  }
  return 0.08;
}

export function a2uiThinkingDotOpacity(index: number, activeStep: number): number {
  return 0.3 + a2uiThinkingDotIntensity(index, activeStep) * 0.64;
}

export function a2uiThinkingDotScale(index: number, activeStep: number): number {
  return 0.74 + a2uiThinkingDotIntensity(index, activeStep) * 0.58;
}

export function a2uiThinkingDotsActive(isBusy: boolean, status: string): boolean {
  if (!isBusy) {
    return false;
  }
  return status === 'thinking' || status === 'calling_tool';
}
