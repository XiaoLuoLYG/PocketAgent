import { describe, it, expect } from '@ohos/hypium';
import {
  childIdsOf,
  componentTextOf,
  findA2uiComponent,
  rootComponentIdOf,
  thinkingTextOf
} from '../main/ets/pages/A2uiHome/render/A2uiRenderData';
import { A2uiComponent, A2uiSurfaceState } from '../main/ets/model/A2uiTypes';

function sampleSurface(): A2uiSurfaceState {
  const root: A2uiComponent = {
    id: 'root',
    component: 'SurfaceRoot',
    child: 'body'
  };
  const bodyChildren: string[] = ['title', 'info'];
  const body: A2uiComponent = {
    id: 'body',
    component: 'Column',
    children: bodyChildren
  };
  const title: A2uiComponent = {
    id: 'title',
    component: 'Text',
    text: '你好'
  };
  const info: A2uiComponent = {
    id: 'info',
    component: 'InfoRows',
    dataPath: '/rows'
  };
  const components: A2uiComponent[] = [root, body, title, info];
  return {
    surfaceId: 's',
    rootId: 'root',
    title: '测试',
    intent: 'general',
    status: 'ready',
    components: components,
    dataModelJson: '{"rows":[{"label":"数值","value":"42"}]}',
    error: '',
    sequence: 1
  };
}

export default function a2uiRenderDataTest() {
  describe('a2uiRenderData', () => {
    it('finds the root component id from a surface', 0, () => {
      expect(rootComponentIdOf(sampleSurface())).assertEqual('root');
    });

    it('resolves child and children ids in render order', 0, () => {
      const surface = sampleSurface();
      const root = findA2uiComponent(surface, 'root');
      const body = findA2uiComponent(surface, 'body');

      expect(root !== null).assertTrue();
      expect(body !== null).assertTrue();
      if (root !== null && body !== null) {
        expect(childIdsOf(root).join(',')).assertEqual('body');
        expect(childIdsOf(body).join(',')).assertEqual('title,info');
      }
    });

    it('reads text before body fallback', 0, () => {
      const surface = sampleSurface();
      const title = findA2uiComponent(surface, 'title');

      expect(title !== null).assertTrue();
      if (title !== null) {
        expect(componentTextOf(title)).assertEqual('你好');
      }
    });

    it('reads thinking text from thoughts data path', 0, () => {
      const thinking: A2uiComponent = {
        id: 'think',
        component: 'ThinkingStream',
        dataPath: '/thoughts'
      };
      const components: A2uiComponent[] = [thinking];
      const surface: A2uiSurfaceState = {
        surfaceId: 's',
        rootId: 'think',
        title: '思考中',
        intent: 'general',
        status: 'thinking',
        components: components,
        dataModelJson: '{"thoughts":["正在分析","请求"]}',
        error: '',
        sequence: 1
      };

      expect(thinkingTextOf(surface, thinking)).assertEqual('正在分析\n请求');
    });

    it('falls back to component text when thoughts are absent', 0, () => {
      const thinking: A2uiComponent = {
        id: 'think',
        component: 'ThinkingCard',
        body: '思考流写入中'
      };

      expect(thinkingTextOf(sampleSurface(), thinking)).assertEqual('思考流写入中');
    });

    it('hides placeholder thinking text', 0, () => {
      const thinking: A2uiComponent = {
        id: 'think',
        component: 'ThinkingStream',
        dataPath: '/thoughts'
      };
      const components: A2uiComponent[] = [thinking];
      const surface: A2uiSurfaceState = {
        surfaceId: 's',
        rootId: 'think',
        title: '思考中',
        intent: 'general',
        status: 'thinking',
        components: components,
        dataModelJson: '{"thoughts":["等待模型响应"]}',
        error: '',
        sequence: 1
      };

      expect(thinkingTextOf(surface, thinking)).assertEqual('');
    });
  });
}
