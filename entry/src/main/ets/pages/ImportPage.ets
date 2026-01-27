// =====================================================
// ImportPage.ets - Import custom wordbooks
// Supports: paste TXT/CSV content (word + meaning)
// =====================================================

import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';
import { DBManager } from '../database/DBManager';
import { WordItem, WordStatus, WordDefinition, FSRSState, ReviewHistory } from '../model/WordModel';

@Entry
@Component
struct ImportPage {
  @State bookName: string = '自定义词书';
  @State tagsText: string = '';
  @State rawText: string = '';
  @State previewCount: number = 0;
  @State invalidCount: number = 0;
  @State duplicateCount: number = 0;
  @State importing: boolean = false;
  @State importResult: string = '';

  private dbManager: DBManager = DBManager.getInstance();
  private initialized: boolean = false;

  aboutToAppear(): void {
    this.ensureDB();
  }

  private async ensureDB(): Promise<void> {
    if (this.initialized) {
      return;
    }

    try {
      const context = getContext(this) as common.UIAbilityContext;
      await this.dbManager.initialize(context);
      this.initialized = true;
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `数据库初始化失败: ${errMsg}`, duration: 2500 });
    }
  }

  private normalizeWord(word: string): string {
    return word.trim().toLowerCase();
  }

  private parseText(): WordItem[] {
    const lines = this.rawText.split(/\r?\n/);
    const seen: Set<string> = new Set<string>();
    const words: WordItem[] = [];
    let invalid = 0;
    let dup = 0;

    const bookId = this.bookName.trim().length > 0 ? this.bookName.trim() : 'default';
    const tags = this.tagsText.trim();

    for (const line of lines) {
      const s = line.trim();
      if (s.length === 0) {
        continue;
      }
      if (s.startsWith('#') || s.startsWith('//')) {
        continue;
      }

      let word = '';
      let meaning = '';

      if (s.includes('\t')) {
        const parts = s.split('\t');
        word = parts[0];
        meaning = parts.slice(1).join('\t');
      } else if (s.includes(',')) {
        const parts = s.split(',');
        word = parts[0];
        meaning = parts.slice(1).join(',');
      } else {
        const parts = s.split(/\s+/);
        word = parts[0];
        meaning = parts.slice(1).join(' ');
      }

      word = this.normalizeWord(word);
      meaning = meaning.trim();

      if (word.length === 0) {
        invalid++;
        continue;
      }

      if (!/^[a-zA-Z][a-zA-Z\-\']*$/.test(word)) {
        invalid++;
        continue;
      }

      if (seen.has(word)) {
        dup++;
        continue;
      }
      seen.add(word);

      const def = new WordDefinition(word, '', '', meaning, [], 'import');
      const now = Date.now();
      // 正确的参数顺序：id, word, status, fsrsState, history, definition, dueDate, createdAt, updatedAt, bookId, tags, lapseCount, leechLevel, errorTags, suspendUntil
      const item = new WordItem(
        0, // id
        word, // word
        WordStatus.NEW, // status
        new FSRSState(), // fsrsState
        new ReviewHistory(), // history
        def, // definition
        now, // dueDate
        now, // createdAt
        now, // updatedAt
        bookId, // bookId
        tags.trim().length > 0 ? tags.split(' ') : [], // tags (转换为string[])
        0, // lapseCount
        0, // leechLevel
        [], // errorTags
        0 // suspendUntil
      );
      words.push(item);

      // Soft limit to avoid UI freeze for huge pastes.
      if (words.length >= 5000) {
        break;
      }
    }

    this.previewCount = words.length;
    this.invalidCount = invalid;
    this.duplicateCount = dup;
    return words;
  }

  private preview(): void {
    this.parseText();
    if (this.previewCount === 0) {
      this.importResult = '没有可导入的单词，请检查格式。';
    } else {
      this.importResult = `预览：${this.previewCount} 个单词（无效 ${this.invalidCount}，重复 ${this.duplicateCount}）`;
    }
  }

  private async doImport(): Promise<void> {
    if (this.importing) {
      return;
    }

    await this.ensureDB();
    const words = this.parseText();
    if (words.length === 0) {
      promptAction.showToast({ message: '没有可导入的单词', duration: 2000 });
      return;
    }

    this.importing = true;
    this.importResult = '';

    try {
      const inserted = await this.dbManager.insertWords(words);
      this.importResult = `✅ 导入完成：新增 ${inserted} / ${words.length}（无效 ${this.invalidCount}，重复 ${this.duplicateCount}）`;
      promptAction.showToast({ message: '导入完成', duration: 1500 });
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      this.importResult = `❌ 导入失败：${errMsg}`;
    } finally {
      this.importing = false;
    }
  }

  build() {
    Column() {
      // Header
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor('#333333')
          .accessibilityText('返回')
          .onClick(() => router.back());

        Text('导入词书')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .margin({ left: 16 });

        Blank();
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#FFFFFF');

      Scroll() {
        Column() {
          // Book Info
          Text('词书信息')
            .fontSize(14)
            .fontColor('#666666')
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .margin({ top: 16, bottom: 8 });

          Column() {
            Row() {
              Text('名称')
                .fontSize(16)
                .fontColor('#333333')
                .width(72);

              TextInput({ text: this.bookName, placeholder: '例如：考研核心词' })
                .layoutWeight(1)
                .height(44)
                .fontSize(14)
                .backgroundColor(Color.Transparent)
                .onChange((v: string) => (this.bookName = v));
            }
            .width('100%')
            .height(56)
            .padding({ left: 16, right: 16 });

            Divider().color('#EEEEEE').margin({ left: 16 });

            Row() {
              Text('标签')
                .fontSize(16)
                .fontColor('#333333')
                .width(72);

              TextInput({ text: this.tagsText, placeholder: '可选：tag1 tag2' })
                .layoutWeight(1)
                .height(44)
                .fontSize(14)
                .backgroundColor(Color.Transparent)
                .onChange((v: string) => (this.tagsText = v));
            }
            .width('100%')
            .height(56)
            .padding({ left: 16, right: 16 });
          }
          .width('100%')
          .backgroundColor('#FFFFFF')
          .borderRadius(12);

          // Raw Content
          Text('粘贴词书内容')
            .fontSize(14)
            .fontColor('#666666')
            .fontWeight(FontWeight.Medium)
            .width('100%')
            .margin({ top: 24, bottom: 8 });

          Column() {
            Text('支持格式：word\\tmeaning / word,meaning / word meaning（meaning 可为空）')
              .fontSize(12)
              .fontColor('#999999')
              .margin({ bottom: 8 });

            TextArea({ text: this.rawText, placeholder: '在这里粘贴 TXT/CSV 内容…' })
              .width('100%')
              .height(220)
              .fontSize(12)
              .backgroundColor('#F7F7F7')
              .borderRadius(8)
              .padding(10)
              .onChange((v: string) => (this.rawText = v));

            Row() {
              Button('预览')
                .layoutWeight(1)
                .height(44)
                .fontSize(16)
                .fontColor('#FFFFFF')
                .backgroundColor('#2196F3')
                .borderRadius(22)
                .accessibilityText('预览导入内容')
                .onClick(() => this.preview());

              Blank();

              Button(this.importing ? '导入中...' : '开始导入')
                .layoutWeight(1)
                .height(44)
                .fontSize(16)
                .fontColor('#FFFFFF')
                .backgroundColor(this.importing ? '#CCCCCC' : '#4CAF50')
                .borderRadius(22)
                .enabled(!this.importing)
                .accessibilityText('开始导入词书')
                .onClick(() => {
                  this.doImport();
                });
            }
            .width('100%')
            .margin({ top: 12 });
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12);

          if (this.importResult.length > 0) {
            Text(this.importResult)
              .fontSize(13)
              .fontColor(this.importResult.includes('✅') ? '#4CAF50' : '#F44336')
              .margin({ top: 12 })
              .width('100%')
              .textAlign(TextAlign.Center);
          }

          Blank().height(40);
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 32 });
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5');
  }
}
