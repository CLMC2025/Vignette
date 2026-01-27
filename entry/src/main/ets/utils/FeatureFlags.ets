export class FeatureFlags {
  private static getBool(key: string, defaultValue: boolean): boolean {
    const raw = AppStorage.get<string>(key);
    if (raw === undefined) return defaultValue;
    if (raw === 'true') return true;
    if (raw === 'false') return false;
    return defaultValue;
  }

  static isBackupReminderEnabled(): boolean {
    return FeatureFlags.getBool('ff_backup_reminder_enabled', true);
  }
}
