import promptAction from '@ohos.promptAction';

import { buildUserFacingError } from './ErrorClassifier';

interface DialogIndexResult {
  index: number;
}

interface DialogButton {
  text: string;
  color: string;
}

export interface FriendlyErrorActions {
  onOpenSettings?: () => void;
  onRetry?: () => void;
}

const EMPTY_ACTIONS: FriendlyErrorActions = {};

export type FriendlyErrorInput = string | Error | Object | number | boolean;

function toErrorString(err: FriendlyErrorInput): string {
  if (err instanceof Error) {
    return err.message;
  }
  if (typeof err === 'string') {
    return err;
  }
  try {
    return JSON.stringify(err);
  } catch (_) {
    return String(err);
  }
}

export async function showFriendlyError(err: FriendlyErrorInput, actions: FriendlyErrorActions = EMPTY_ACTIONS): Promise<void> {
  const info = buildUserFacingError(toErrorString(err));

  const message = info.suggestion.length > 0
    ? `${info.userMessage}\n\n建议：${info.suggestion}`
    : info.userMessage;

  const buttons: DialogButton[] = [];
  const handlers: Array<() => void> = [];

  if (info.showSettingsAction && typeof actions.onOpenSettings === 'function') {
    buttons.push({ text: '去设置', color: '#2196F3' });
    handlers.push(actions.onOpenSettings);
  }
  if (info.showRetryAction && typeof actions.onRetry === 'function') {
    buttons.push({ text: '重试', color: '#2196F3' });
    handlers.push(actions.onRetry);
  }
  buttons.push({ text: '知道了', color: '#666666' });
  handlers.push(() => {});

  try {
    const result = await (promptAction.showDialog({
      title: info.title,
      message,
      buttons
    }) as Promise<DialogIndexResult>);

    const idx = result.index;
    if (idx >= 0 && idx < handlers.length) {
      handlers[idx]();
    }
  } catch (_) {
    promptAction.showToast({ message: info.userMessage, duration: 2000 });
  }
}
