import { A2uiComponent } from '../../../model/A2uiTypes';

export type HtmlHomeSource = 'welcome' | 'pending' | 'model' | 'tool';
export type HtmlHomeKind = 'welcome' | 'thinking' | 'travel' | 'food' | 'social' | 'dynamic-tools' | 'gmail' | 'generic';

export interface HtmlHomeChip {
  label: string;
  value?: string;
}

export interface HtmlHomeMetric {
  label: string;
  value: string;
}

export interface HtmlHomeTimelineItem {
  title: string;
  subtitle?: string;
  status?: string;
}

export interface HtmlHomeAction {
  id: string;
  label: string;
  prompt: string;
  variant: string;
  kind: string;
  sourceComponentId?: string;
  args?: Object;
}

export interface HtmlHomeBlock {
  id: string;
  kind: string;
  title: string;
  subtitle?: string;
  status?: string;
  source?: string;
  credentialName?: string;
  credentialRef?: string;
  toolId?: string;
  prompt?: string;
  metrics: HtmlHomeMetric[];
  rows: HtmlHomeMetric[];
  actions: HtmlHomeAction[];
  rawPreview?: string;
}

export interface HtmlHomeHistoryItem {
  id: string;
  role: string;
  content: string;
}

export interface HtmlHomeDocument {
  version: number;
  source: HtmlHomeSource;
  kind: HtmlHomeKind;
  title: string;
  subtitle: string;
  chips: HtmlHomeChip[];
  metrics: HtmlHomeMetric[];
  timeline: HtmlHomeTimelineItem[];
  blocks: HtmlHomeBlock[];
  actions: HtmlHomeAction[];
  history: HtmlHomeHistoryItem[];
  rawSurfaceRoot: A2uiComponent | null;
  generatedAt: string;
}
