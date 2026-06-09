export interface LocalModelSettings {
  provider: string;
  baseUrl: string;
  model: string;
  apiKey: string;
}

export function defaultLocalModelSettings(): LocalModelSettings {
  return {
    provider: 'Huawei Local API',
    baseUrl: 'http://127.0.0.1:11434',
    model: 'Qwen3-8B',
    apiKey: ''
  };
}
