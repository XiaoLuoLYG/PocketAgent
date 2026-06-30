import { describe, it, expect } from '@ohos/hypium';
import { DynamicGenericToolResult } from '../main/ets/model/DynamicToolTypes';
import { callMediaVideoSearch, mediaSourcesFromArgs, mediaVideoQueryFromArgs, mediaVideoSearchQuery, mergeMediaVideoProviderResults } from '../main/ets/model/MediaVideoClient';

function row(source: string, title: string, status: string = 'success'): DynamicGenericToolResult {
  return {
    sourceTag: source,
    toolName: source === 'YouTube Data API' ? 'youtube.video.search' : 'media.video.search',
    title: title,
    status: status,
    summary: title,
    rows: [{ label: 'Watch URL', value: 'https://example.test/watch' }],
    rawPreview: title
  };
}

interface QueryArgsFixture {
  query: string;
}

interface SourceArgsFixture {
  sources: string[];
}

export default function mediaVideoClientTest() {
  describe('mediaVideoClient', () => {
    it('extracts query and source args without keyword heuristics', 0, () => {
      const queryArgs: QueryArgsFixture = { query: 'qwen max 官方介绍' };
      const sourceArgs: SourceArgsFixture = { sources: ['bilibili'] };

      expect(mediaVideoQueryFromArgs('帮我搜视频', queryArgs)).assertEqual('qwen max 官方介绍');
      expect(mediaVideoQueryFromArgs('帮我搜视频', null)).assertEqual('视频');
      expect(mediaVideoSearchQuery('帮我在b站和youtube里搜索qwen max 的官方视频')).assertEqual('qwen max 的官方视频');
      expect(mediaSourcesFromArgs(sourceArgs).join(',')).assertEqual('bilibili');
      expect(mediaSourcesFromArgs(null).join(',')).assertEqual('youtube,bilibili');
    });

    it('merges provider rows and normalizes toolName for aggregate search', 0, () => {
      const results = mergeMediaVideoProviderResults([
        row('YouTube Data API', 'YouTube hit'),
        row('哔哩哔哩', 'Bilibili hit')
      ]);

      expect(results.length).assertEqual(2);
      expect(results[0].toolName).assertEqual('media.video.search');
      expect(results[0].sourceTag).assertEqual('YouTube Data API');
      expect(results[1].sourceTag).assertEqual('哔哩哔哩');
    });

    it('keeps YouTube missing-key rows and includes Bilibili without credentials', 0, async () => {
      const youtubeArgs: SourceArgsFixture = { sources: ['youtube'] };
      const results = await callMediaVideoSearch('qwen max 官方介绍', youtubeArgs, '');

      expect(results.length).assertEqual(1);
      expect(results[0].sourceTag).assertEqual('YouTube Data API');
      expect(results[0].status).assertEqual('error');
      expect(results[0].toolName).assertEqual('media.video.search');
      expect(results[0].rows[0].label).assertEqual('Credential');
    });
  });
}
