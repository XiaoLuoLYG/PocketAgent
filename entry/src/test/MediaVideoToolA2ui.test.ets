import { describe, it, expect } from '@ohos/hypium';
import { A2uiGenericToolResultData } from '../main/ets/model/A2uiTypes';
import { isMediaVideoResult, mediaVideoPlaybackAction } from '../main/ets/model/MediaVideoToolA2ui';

function result(sourceTag: string, toolName: string, status: string, url: string): A2uiGenericToolResultData {
  return {
    sourceTag: sourceTag,
    toolName: toolName,
    title: 'Qwen Max official intro',
    status: status,
    summary: 'video result',
    rows: url.length > 0 ? [{ label: 'Watch URL', value: url }] : [],
    rawPreview: 'videoId=abc123'
  };
}

export default function mediaVideoToolA2uiTest() {
  describe('mediaVideoToolA2ui', () => {
    it('creates playback actions for YouTube and Bilibili success rows', 0, () => {
      const youtube = result('YouTube Data API', 'media.video.search', 'success', 'https://www.youtube.com/watch?v=abc123');
      const bilibili = result('哔哩哔哩', 'media.video.search', 'success', 'https://www.bilibili.com/video/BV1h57y6pE5o');

      expect(isMediaVideoResult(youtube)).assertTrue();
      expect(mediaVideoPlaybackAction(youtube)?.id).assertEqual('media.open.web');
      expect(mediaVideoPlaybackAction(youtube)?.label).assertEqual('跳转');
      expect(mediaVideoPlaybackAction(youtube)?.prompt).assertEqual('https://www.youtube.com/watch?v=abc123');
      expect(mediaVideoPlaybackAction(bilibili)?.id).assertEqual('media.open.web');
      expect(mediaVideoPlaybackAction(bilibili)?.label).assertEqual('跳转');
      expect(mediaVideoPlaybackAction(bilibili)?.kind).assertEqual('client');
      expect(mediaVideoPlaybackAction(bilibili)?.variant).assertEqual('primary');
      expect(mediaVideoPlaybackAction(bilibili)?.prompt).assertEqual('https://www.bilibili.com/video/BV1h57y6pE5o');
    });

    it('does not create playback actions for errors or rows without official URLs', 0, () => {
      const errorRow = result('哔哩哔哩', 'media.video.search', 'error', 'https://www.bilibili.com/video/BV1h57y6pE5o');
      const missingUrl = result('哔哩哔哩', 'media.video.search', 'success', '');
      const nonUrl = result('哔哩哔哩', 'media.video.search', 'success', 'not-a-url');
      const playlist = result('YouTube Data API', 'youtube.mine.playlists', 'success', 'https://www.youtube.com/playlist?list=PL123');

      expect(mediaVideoPlaybackAction(errorRow)).assertEqual(null);
      expect(mediaVideoPlaybackAction(missingUrl)).assertEqual(null);
      expect(mediaVideoPlaybackAction(nonUrl)).assertEqual(null);
      expect(mediaVideoPlaybackAction(playlist)).assertEqual(null);
    });
  });
}
