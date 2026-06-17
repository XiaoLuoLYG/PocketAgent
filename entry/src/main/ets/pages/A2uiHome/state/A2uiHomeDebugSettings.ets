export const A2UI_FOOD_PROVIDER_DELAY_MAX_MS: number = 30000;

export function normalizeFoodProviderDelayMs(value: string): number {
  const parsed = Number.parseInt(value.trim());
  if (Number.isNaN(parsed) || parsed < 0) {
    return 0;
  }
  if (parsed > A2UI_FOOD_PROVIDER_DELAY_MAX_MS) {
    return A2UI_FOOD_PROVIDER_DELAY_MAX_MS;
  }
  return parsed;
}
