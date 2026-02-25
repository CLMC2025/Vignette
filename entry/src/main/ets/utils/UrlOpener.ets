import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';
import type common from '@ohos.app.ability.common';

export async function openUrl(context: common.UIAbilityContext, url: string): Promise<boolean> {
  const target = url.trim();
  if (target.length === 0) {
    return false;
  }

  // 处理邮箱链接
  if (target.startsWith('mailto:')) {
    const email = target.substring(7);
    return await copyToClipboard(email, `邮箱 ${email} 已复制到剪贴板，请手动发送邮件`);
  }

  // 处理QQ群链接
  if (target.startsWith('mqqapi://') || target.includes('qq')) {
    const qqMatch = target.match(/uin=(\d+)/);
    const qqNumber = qqMatch ? qqMatch[1] : '';
    if (qqNumber) {
      return await copyToClipboard(qqNumber, `QQ群号 ${qqNumber} 已复制到剪贴板，请手动打开QQ搜索加群`);
    }
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

async function copyToClipboard(text: string, successMessage: string): Promise<boolean> {
  try {
    const pasteboardData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    const systemPasteboard = pasteboard.getSystemPasteboard();
    await systemPasteboard.setData(pasteboardData);
    promptAction.showToast({ message: successMessage, duration: 2000 });
    return true;
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    promptAction.showToast({ message: `复制失败：${msg}`, duration: 1500 });
    return false;
  }
}
