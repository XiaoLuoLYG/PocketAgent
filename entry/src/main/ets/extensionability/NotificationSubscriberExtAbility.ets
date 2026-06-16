import { notificationExtensionSubscription, NotificationSubscriberExtensionAbility } from '@kit.NotificationKit';
import { aiLogInfo } from '../model/AiphoneLogger';
import {
  appendNotificationCapture,
  captureRecordFromNotificationInfo,
  SocialNotificationRecord
} from '../model/SocialNotificationArchive';

export default class NotificationSubscriberExtAbility extends NotificationSubscriberExtensionAbility {
  onDestroy(): void {
    aiLogInfo('[AIPhone][SocialNotificationSubscriberDestroy]');
  }

  onReceiveMessage(notificationInfo: notificationExtensionSubscription.NotificationInfo): void {
    const record: SocialNotificationRecord = captureRecordFromNotificationInfo(notificationInfo);
    aiLogInfo('[AIPhone][SocialNotificationReceived] bundle=' + record.bundleName +
      ' app=' + record.appName +
      ' platform=' + record.platform +
      ' titleChars=' + record.conversationTitle.length.toString() +
      ' textChars=' + record.preview.length.toString() +
      ' hash=' + record.hashCode);
    appendNotificationCapture(this.context, record);
  }

  onCancelMessages(hashCodes: Array<string>): void {
    aiLogInfo('[AIPhone][SocialNotificationCancel] hashes=' + JSON.stringify(hashCodes));
  }
}
