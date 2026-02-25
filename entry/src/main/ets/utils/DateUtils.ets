export class DateUtils {
  private static readonly DAY_MS: number = 24 * 60 * 60 * 1000;

  static getStartOfDayMs(ts: number): number {
    const d = new Date(ts);
    const result = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0, 0).getTime();
    return result;
  }

  static getTimezoneOffsetMs(): number {
    return -new Date().getTimezoneOffset() * 60 * 1000;
  }

  static formatDebugDate(ms: number): string {
    const d = new Date(ms);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}:${String(d.getSeconds()).padStart(2, '0')}`;
  }

  static getDayKey(ms: number): number {
    const timezoneOffsetMs = DateUtils.getTimezoneOffsetMs();
    return Math.floor((ms + timezoneOffsetMs) / DateUtils.DAY_MS);
  }

  static dayKeyToMs(dayKey: number): number {
    const timezoneOffsetMs = DateUtils.getTimezoneOffsetMs();
    return dayKey * DateUtils.DAY_MS - timezoneOffsetMs;
  }
}
