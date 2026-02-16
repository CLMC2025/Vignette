// =====================================================
// SettingsCommon.ets - Shared types for Settings
// =====================================================

export interface SelectOption {
  value: string;
}

export interface SettingsSectionItem {
  id: string;
  title: string;
  subtitle: string;
}

export interface ErrorObject {
  message?: string;
  code?: number | string;
  name?: string;
}

export function formatError(e: Error | ErrorObject | string | number | boolean): string {
  if (e instanceof Error) {
    return e.message;
  }
  if (typeof e === 'string') {
    return e;
  }
  if (typeof e === 'object' && e !== null) {
    const errorObj = e as ErrorObject;
    if (errorObj.message && typeof errorObj.message === 'string') {
      return errorObj.message;
    }
    return String(e);
  }
  return String(e);
}
