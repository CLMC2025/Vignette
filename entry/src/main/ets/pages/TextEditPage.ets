import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';

import { DesignTokens } from '../model/DesignTokens';
import { ColorsInterface } from '../model/TokenInterfaces';
import { ThemeManager } from '../manager/ThemeManager';
import { DBManager } from '../database/DBManager';
import { showFriendlyError } from '../utils/FriendlyErrorPresenter';

interface TextEditPageParams {
  textId?: number;
}

@Entry
@Component
struct TextEditPage {
  @State private textId: number = 0;
  @State private title: string = '';
  @State private content: string = '';
  @State private isLoading: boolean = true;
  @State private isSaving: boolean = false;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private context: common.UIAbilityContext | null = null;
  private dbManager: DBManager = DBManager.getInstance();

  aboutToAppear(): void {
    this.context = getContext(this) as common.UIAbilityContext;
    void this.init();
  }

  private async init(): Promise<void> {
    this.isLoading = true;
    try {
      await this.dbManager.initialize(this.context!);
    } catch (_) { /* 数据库初始化失败，后续操作会处理 */ }

    try {
      const params = router.getParams() as TextEditPageParams;
      const id = Number(params?.textId ?? 0);
      this.textId = id;
      if (id > 0) {
        const row = await this.dbManager.getTextById(id);
        if (row === null) {
          promptAction.showToast({ message: '文本不存在或已被删除', duration: 1500 });
          router.back();
          return;
        }
        this.title = row.title ?? '';
        this.content = row.content ?? '';
      } else {
        this.title = '';
        this.content = '';
      }
    } catch (e) {
      await showFriendlyError(e, { onOpenSettings: () => router.pushUrl({ url: 'pages/SettingsPage' }) });
      router.back();
    } finally {
      this.isLoading = false;
    }
  }

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private async save(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    const content = this.content.trim();
    if (content.length === 0) {
      promptAction.showToast({ message: '请输入文本内容', duration: 1200 });
      return;
    }
    const title = this.title.trim().length > 0 ? this.title.trim() : '未命名文本';

    this.isSaving = true;
    try {
      if (this.textId > 0) {
        const existing = await this.dbManager.getTextById(this.textId);
        if (existing === null) {
          promptAction.showToast({ message: '文本不存在或已被删除', duration: 1500 });
          router.back();
          return;
        }
        const sourceType = existing.sourceType ?? 'paste';
        const sourceRef = existing.sourceRef ?? '';
        await this.dbManager.updateText(this.textId, title, this.content, sourceType, sourceRef);
      } else {
        await this.dbManager.createText(title, this.content, 'paste', '');
      }
      promptAction.showToast({ message: '已保存', duration: 1000 });
      router.back();
    } catch (e) {
      await showFriendlyError(e, {
        onOpenSettings: () => router.pushUrl({ url: 'pages/SettingsPage' }),
        onRetry: () => { void this.save(); }
      });
    } finally {
      this.isSaving = false;
    }
  }

  build() {
    Column() {
      Row() {
        Text(this.textId > 0 ? '编辑文本' : '新建文本')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colors.GRAY_900)
          .layoutWeight(1)

        Text('取消')
          .fontSize(14)
          .fontColor(this.colors.GRAY_600)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .onClick(() => router.back())

        Text(this.isSaving ? '保存中' : '保存')
          .fontSize(14)
          .fontColor(this.colors.WHITE)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor(this.colors.PRIMARY)
          .borderRadius(14)
          .margin({ left: 8 })
          .onClick(() => { void this.save(); })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 10 })

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
            .color(this.colors.PRIMARY)
          Text('加载中...')
            .fontSize(13)
            .fontColor(this.colors.GRAY_500)
            .margin({ top: 10 })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Column({ space: 10 }) {
          TextInput({ text: this.title, placeholder: '标题（可选）' })
            .height(44)
            .backgroundColor(this.colors.SURFACE_PRIMARY)
            .borderRadius(12)
            .padding({ left: 12, right: 12 })
            .fontSize(14)
            .fontColor(this.colors.TEXT_PRIMARY)
            .onChange((v: string) => this.title = v)

          TextArea({ text: this.content, placeholder: '粘贴或输入文本内容...' })
            .layoutWeight(1)
            .backgroundColor(this.colors.SURFACE_PRIMARY)
            .borderRadius(12)
            .padding(12)
            .fontSize(14)
            .fontColor(this.colors.TEXT_PRIMARY)
            .onChange((v: string) => this.content = v)

          Row() {
            Text(`${this.content.length} 字符`)
              .fontSize(12)
              .fontColor(this.colors.GRAY_500)
            Blank()
            if (this.content.length > 0) {
              Text('清空')
                .fontSize(12)
                .fontColor(this.colors.GRAY_600)
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .backgroundColor(this.colors.GRAY_100)
                .borderRadius(12)
                .onClick(() => this.content = '')
            }
          }
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors.BACKGROUND_PRIMARY)
    .id('textEditPage_' + this.themeRefreshToken)
  }
}
