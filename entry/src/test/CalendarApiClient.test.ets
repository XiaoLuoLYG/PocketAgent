import { describe, it, expect } from '@ohos/hypium';
import {
  CalendarEventArgs,
  calendarEventMatchesArgs,
  calendarCreateBody,
  calendarEventRequiredFields,
  calendarEventResultsFromListPayload,
  calendarMatchingExistingEventFromListPayload,
  calendarMissingArgsResult,
  calendarSearchQueryText,
  calendarUpdateBody,
  normalizedCalendarArgsForPrompt
} from '../main/ets/model/CalendarApiClient';

export default function calendarApiClientTest() {
  describe('calendarApiClient', () => {
    it('maps list payload into generic results', 0, () => {
      const payload = '{"items":[{"id":"event-123","summary":"AIPhoneDemo smoke","start":{"dateTime":"2026-06-30T15:00:00+08:00"},"end":{"dateTime":"2026-06-30T15:30:00+08:00"},"htmlLink":"https://calendar.google.com/event?eid=123"}]}';
      const results = calendarEventResultsFromListPayload(payload);
      expect(results.length).assertEqual(1);
      expect(results[0].toolName).assertEqual('calendar.events.search');
      expect(results[0].title).assertEqual('AIPhoneDemo smoke');
      expect(results[0].rows[0].value).assertEqual('event-123');
    });

    it('builds create and update bodies from structured args', 0, () => {
      const create = calendarCreateBody({
        title: 'AIPhoneDemo smoke',
        start: '2026-06-30T15:00:00+08:00',
        end: '2026-06-30T15:30:00+08:00',
        timezone: 'Asia/Shanghai'
      });
      const update = calendarUpdateBody({
        eventId: 'event-123',
        title: 'AIPhoneDemo smoke',
        start: '2026-06-30T16:00:00+08:00',
        end: '2026-06-30T16:30:00+08:00',
        timezone: 'Asia/Shanghai'
      });

      expect(JSON.stringify(create).indexOf('"summary":"AIPhoneDemo smoke"')).assertLarger(-1);
      expect(JSON.stringify(update).indexOf('"dateTime":"2026-06-30T16:00:00+08:00"')).assertLarger(-1);
    });

    it('returns real missing-field errors instead of guessing dates', 0, () => {
      const missing = calendarEventRequiredFields('calendar.event.create', {
        title: 'AIPhoneDemo smoke'
      });
      const result = calendarMissingArgsResult('calendar.event.create', missing);
      expect(missing.join(',')).assertEqual('start,end');
      expect(result.status).assertEqual('error');
      expect(result.summary.indexOf('start')).assertLarger(-1);
      expect(result.summary.indexOf('end')).assertLarger(-1);
    });

    it('does not use the whole prompt as the Calendar search query', 0, () => {
      expect(calendarSearchQueryText({})).assertEqual('');
      expect(calendarSearchQueryText({ query: '产品同步' })).assertEqual('产品同步');
    });

    it('keeps the requested window on empty search results', 0, () => {
      const results = calendarEventResultsFromListPayload('{"items":[]}', {
        timeMin: '2026-07-02T00:00:00+08:00',
        timeMax: '2026-07-03T00:00:00+08:00'
      });

      expect(results.length).assertEqual(1);
      expect(results[0].title).assertEqual('没有找到日程');
      expect(results[0].rows[0].label).assertEqual('Window Start');
      expect(results[0].rows[0].value).assertEqual('2026-07-02T00:00:00+08:00');
      expect(results[0].rows[1].label).assertEqual('Window End');
      expect(results[0].rows[1].value).assertEqual('2026-07-03T00:00:00+08:00');
    });

    it('detects an existing event before creating a duplicate', 0, () => {
      const args: CalendarEventArgs = {
        title: '一对一会议',
        start: '2026-07-02T16:30:00+08:00',
        end: '2026-07-02T17:00:00+08:00'
      };
      const payload = '{"items":[{"id":"existing-1","summary":"一对一会议","start":{"dateTime":"2026-07-02T16:30:00+08:00"},"end":{"dateTime":"2026-07-02T17:00:00+08:00"}}]}';
      const existing = calendarMatchingExistingEventFromListPayload(payload, args);

      expect(existing === null).assertFalse();
      if (existing !== null) {
        expect(existing.id).assertEqual('existing-1');
        expect(calendarEventMatchesArgs(existing, args)).assertTrue();
      }
    });

    it('normalizes stale model dates for relative search prompts', 0, () => {
      const args: CalendarEventArgs = normalizedCalendarArgsForPrompt('calendar.events.search', '帮我查看我明天的google calendar日程', {
        timeMin: '2023-10-05T00:00:00+08:00',
        timeMax: '2023-10-06T00:00:00+08:00',
        timezone: 'Asia/Shanghai',
        calendarId: 'primary'
      }, new Date('2026-07-01T09:00:00+08:00'));

      expect(args.timeMin).assertEqual('2026-07-02T00:00:00+08:00');
      expect(args.timeMax).assertEqual('2026-07-03T00:00:00+08:00');
      expect(args.calendarId).assertEqual('primary');
    });

    it('normalizes stale model dates for relative create prompts without changing time', 0, () => {
      const args: CalendarEventArgs = normalizedCalendarArgsForPrompt('calendar.event.create', '帮我在明天下午创建一个一对一会议的日程，4:30开始持续半个小时', {
        title: '一对一会议',
        start: '2023-10-05T16:30:00+08:00',
        end: '2023-10-05T17:00:00+08:00',
        timezone: 'Asia/Shanghai',
        calendarId: 'primary'
      }, new Date('2026-07-01T09:00:00+08:00'));

      expect(args.title).assertEqual('一对一会议');
      expect(args.start).assertEqual('2026-07-02T16:30:00+08:00');
      expect(args.end).assertEqual('2026-07-02T17:00:00+08:00');
      expect(args.timezone).assertEqual('Asia/Shanghai');
    });
  });
}
