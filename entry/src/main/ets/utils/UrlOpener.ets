import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';

export async function openUrl(context: common.UIAbilityContext, url: string): Promise<boolean> {
  const target = url.trim();
  if (target.length === 0) {
    return false;
  }
  try {
    await context.startAbility({
      action: 'ohos.want.action.viewData',
      uri: target
    });
    return true;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    promptAction.showToast({ message: `打开失败：${msg}`, duration: 1500 });
    return false;
  }
}

