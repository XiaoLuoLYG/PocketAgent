import { A2uiComponent, A2uiSurfaceState } from '../../../model/A2uiTypes';
import { resolveData } from '../../../model/A2uiData';

export function rootComponentIdOf(surface: A2uiSurfaceState): string {
  return surface.rootId.length > 0 ? surface.rootId : 'root';
}

export function findA2uiComponent(surface: A2uiSurfaceState, id: string): A2uiComponent | null {
  for (let index = 0; index < surface.components.length; index++) {
    if (surface.components[index].id === id) {
      return surface.components[index];
    }
  }
  return null;
}

export function childIdsOf(component: A2uiComponent): string[] {
  const ids: string[] = [];
  if (component.child !== undefined && component.child.length > 0) {
    ids.push(component.child);
  }
  if (component.children !== undefined && component.children !== null) {
    component.children.forEach((childId: string) => {
      if (childId.length > 0) {
        ids.push(childId);
      }
    });
  }
  return ids;
}

export function componentTitleOf(component: A2uiComponent, fallback: string = ''): string {
  if (component.title !== undefined && component.title.length > 0) {
    return component.title;
  }
  return fallback;
}

export function componentBodyOf(component: A2uiComponent, fallback: string = ''): string {
  if (component.body !== undefined && component.body.length > 0) {
    return component.body;
  }
  return fallback;
}

export function componentTextOf(component: A2uiComponent): string {
  if (component.text !== undefined && component.text.length > 0) {
    return component.text;
  }
  return componentBodyOf(component);
}

export function componentStatusOf(component: A2uiComponent, fallback: string = 'idle'): string {
  if (component.status !== undefined && component.status.length > 0) {
    return component.status;
  }
  return fallback;
}

export function componentVariantOf(component: A2uiComponent): string {
  if (component.variant !== undefined && component.variant.length > 0) {
    return component.variant;
  }
  return '';
}

export function componentToneOf(component: A2uiComponent): string {
  if (component.tone !== undefined && component.tone.length > 0) {
    return component.tone;
  }
  return '';
}

export function thinkingTextOf(surface: A2uiSurfaceState, component: A2uiComponent): string {
  let thoughts: string[] = [];
  if (component.dataPath === '/thoughts') {
    const data = resolveData(surface, component.dataPath);
    if (Array.isArray(data)) {
      thoughts = data as string[];
    }
  }
  if (thoughts.length === 0) {
    return componentTextOf(component);
  }
  if (thoughts.length === 1 && thoughts[0] === '等待模型响应') {
    return '';
  }
  return thoughts.join('\n');
}
