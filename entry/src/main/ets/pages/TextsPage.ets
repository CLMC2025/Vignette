import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import util from '@ohos.util';

import { DesignTokens } from '../model/DesignTokens';
import { ColorsInterface } from '../model/TokenInterfaces';
import { ThemeManager } from '../manager/ThemeManager';
import { DBManager } from '../database/DBManager';
import { TextItem, TextSourceType } from '../model/WordModel';
import { showFriendlyError } from '../utils/FriendlyErrorPresenter';

interface TextsPageParams {
  highlightTextId?: number;
}

interface DialogIndexResult {
  index: number;
}

@Entry
@Component
struct TextsPage {
  @State private texts: TextItem[] = [];
  @State private isLoading: boolean = true;
  @State private loadingHint: string = '加载中...';
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private context: common.UIAbilityContext | null = null;
  private dbManager: DBManager = DBManager.getInstance();

  aboutToAppear(): void {
    this.context = getContext(this) as common.UIAbilityContext;
    void this.ensureDBAndLoad();
  }

  private async ensureDBAndLoad(): Promise<void> {
    console.info('[TextsPage] Initializing database');
    try {
      await this.dbManager.initialize(this.context!);
      console.info('[TextsPage] Database initialized successfully');
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error(`[TextsPage] Database initialization failed: ${errMsg}`);
    }
    await this.loadTexts();
  }

  private async loadTexts(): Promise<void> {
    this.isLoading = true;
    this.loadingHint = '加载文本库...';
    try {
      const rows = await this.dbManager.listTexts(200);
      const list: TextItem[] = [];
      for (const r of rows) {
        const sourceType: TextSourceType = r.sourceType === 'file' ? 'file' : 'paste';
        list.push(new TextItem(r.id, r.title, r.content, sourceType, r.sourceRef, r.createdAt, r.updatedAt));
      }
      this.texts = list;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      this.loadingHint = `加载失败：${msg}`;
      this.texts = [];
    } finally {
      this.isLoading = false;
    }
  }

  private formatTime(ts: number): string {
    const ms = Number(ts);
    if (!Number.isFinite(ms) || ms <= 0) return '';
    const d = new Date(ms);
    const pad = (n: number): string => String(n).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  private getMetaText(item: TextItem): string {
    const updated = this.formatTime(item.updatedAt);
    const chars = item.content.length;
    return `${updated}  ·  ${chars} 字符`;
  }

  private openText(item: TextItem): void {
    router.pushUrl({ url: 'pages/TextReaderPage', params: { textId: item.id } });
  }

  private createNewText(): void {
    router.pushUrl({ url: 'pages/TextEditPage' });
  }

  private async deleteText(item: TextItem): Promise<void> {
    try {
      const result = await (promptAction.showDialog({
        title: '删除文本',
        message: `确定删除「${item.title}」吗？`,
        buttons: [
          { text: '取消', color: String(this.colors.TEXT_SECONDARY) },
          { text: '删除', color: String(this.colors.ERROR) }
        ]
      }) as Promise<DialogIndexResult>);
      if (result.index !== 1) {
        return;
      }
    } catch (_) {
      return;
    }

    try {
      await this.dbManager.deleteText(item.id);
      promptAction.showToast({ message: '已删除', duration: 1000 });
      await this.loadTexts();
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `删除失败：${msg}`, duration: 1500 });
    }
  }

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private async importFromFile(): Promise<void> {
    try {
      const documentPicker = new picker.DocumentViewPicker();
      const options = new picker.DocumentSelectOptions();
      const result = await documentPicker.select(options);
      if (result.length === 0) {
        return;
      }
      const uri = result[0];
      let file: fs.File | null = null;
      try {
        file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
        const size = fs.statSync(file.fd).size;
        if (size > 2 * 1024 * 1024) {
          promptAction.showToast({ message: '文件过大，请使用小于2MB的文件', duration: 1500 });
          return;
        }
        const buf = new ArrayBuffer(size);
        fs.readSync(file.fd, buf);
        const decoder = new util.TextDecoder('utf-8');
        const text = decoder.decode(new Uint8Array(buf));
        const trimmed = text.trim();
        if (trimmed.length === 0) {
          promptAction.showToast({ message: '文件内容为空', duration: 1200 });
          return;
        }
        const title = `导入文本 ${new Date().toLocaleString()}`;
        const id = await this.dbManager.createText(title, text, 'file', uri);
        promptAction.showToast({ message: '导入成功', duration: 1200 });
        await this.loadTexts();
        router.pushUrl({ url: 'pages/TextReaderPage', params: { textId: id } });
      } finally {
        if (file !== null) {
          try { fs.closeSync(file); } catch (_) {}
        }
      }
    } catch (e) {
      await showFriendlyError(e);
    }
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor(this.colors.GRAY_900)
          .padding(8)
          .onClick(() => router.back())

        Text('文本库')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colors.GRAY_900)
          .layoutWeight(1)
          .margin({ left: 4 })

        Button('导入')
          .height(36)
          .fontSize(14)
          .fontColor(this.colors.PRIMARY)
          .backgroundColor(this.colors.PRIMARY_LIGHTEST)
          .borderRadius(18)
          .onClick(() => { void this.importFromFile(); })

        Button('新建')
          .height(36)
          .fontSize(14)
          .fontColor(this.colors.WHITE)
          .backgroundColor(this.colors.PRIMARY)
          .borderRadius(18)
          .margin({ left: 10 })
          .onClick(() => this.createNewText())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 10 })

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(36)
            .height(36)
            .color(this.colors.PRIMARY)
          Text(this.loadingHint)
            .fontSize(13)
            .fontColor(this.colors.GRAY_500)
            .margin({ top: 10 })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.texts.length === 0) {
        Column() {
          Text('还没有文本')
            .fontSize(16)
            .fontColor(this.colors.GRAY_700)
          Text('导入 txt 或新建粘贴内容')
            .fontSize(13)
            .fontColor(this.colors.GRAY_500)
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            ForEach(this.texts, (item: TextItem) => {
              Column() {
                Row() {
                  Column() {
                    Text(item.title.length > 0 ? item.title : '未命名文本')
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.colors.GRAY_900)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Text(this.getMetaText(item))
                      .fontSize(12)
                      .fontColor(this.colors.GRAY_500)
                      .margin({ top: 4 })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Text('打开')
                    .fontSize(13)
                    .fontColor(this.colors.PRIMARY)
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .backgroundColor(this.colors.PRIMARY_LIGHTEST)
                    .borderRadius(14)
                    .onClick(() => this.openText(item))

                  Text('删除')
                    .fontSize(13)
                    .fontColor(this.colors.ERROR)
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .backgroundColor(this.colors.WARNING_LIGHT + '20')
                    .borderRadius(14)
                    .margin({ left: 8 })
                    .onClick(() => { void this.deleteText(item); })
                }
                .width('100%')
              }
              .padding(14)
              .backgroundColor(this.colors.SURFACE_PRIMARY)
              .borderRadius(14)
              .onClick(() => this.openText(item))
            }, (item: TextItem) => `text-${item.id}`)
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors.BACKGROUND_PRIMARY)
    .id('textsPage_' + this.themeRefreshToken)
  }
}
