import notificationManager from '@ohos.notificationManager';

/**
 * Notification normal content interface
 */
export interface AppNotificationNormalContent {
  title: string;
  text: string;
}

/**
 * Notification basic content interface
 */
export interface AppNotificationBasicContent {
  contentType: notificationManager.ContentType;
  normal: AppNotificationNormalContent;
}

/**
 * Notification content interface for backup reminders
 */
export interface AppNotificationContent {
  content: AppNotificationBasicContent;
}

/**
 * Simple notification request interface
 */
export interface AppNotificationRequest {
  id: number;
  slotId: string;
  content: AppNotificationContent;
}

/**
 * Dashboard statistics
 */
export class DashboardStats {
  newWordsToday: number = 0;
  reviewDue: number = 0;
  totalWords: number = 0;
}

/**
 * Router params interface
 */
export interface RouterParams {
  queue?: Object[]; // QueueItem[]
  sessionId?: string;
}
