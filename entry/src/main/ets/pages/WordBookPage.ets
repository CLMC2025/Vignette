// =====================================================
// WordBookPage.ets - Word book catalog & management
// =====================================================

import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';
import { DBManager } from '../database/DBManager';
import resourceManager from '@ohos.resourceManager';
import { BuiltInWordBooks, buildWordItemsForBook, WordBookDefinition } from '../model/WordBookCatalog';
import { WordStatus } from '../model/WordModel';
import { DesignTokens } from '../model/DesignTokens';

interface WordBookCardData {
  id: string;
  name: string;
  total: number;
  hasUpdate: boolean;
  isCustom: boolean;
  source?: string;
  license?: string;
  isImported: boolean;
}

@Entry
@Component
struct WordBookPage {
  @State private searchText: string = '';
  @State private currentBookId: string = '';
  @State private wordCounts: Map<string, number> = new Map();
  @State private masteredCounts: Map<string, number> = new Map();
  @State private customBooks: WordBookCardData[] = [];

  private readonly STORAGE_KEY_CURRENT_BOOK: string = 'current_book_id';
  private dbManager: DBManager = DBManager.getInstance();
  private initialized: boolean = false;
  private resourceMgr: resourceManager.ResourceManager | null = null;
  // Issue #6 fix: Prevent multiple rapid clicks causing freeze/crash
  private isNavigating: boolean = false;
  private readonly NAVIGATION_COOLDOWN_MS: number = 1000;

  aboutToAppear(): void {
    this.ensureDB();
  }

  async onPageShow(): Promise<void> {
    if (this.initialized) {
      await this.loadBookCounts();
    }
  }

  private async ensureDB(): Promise<void> {
    if (this.initialized) {
      return;
    }
    try {
      const context = getContext(this) as common.UIAbilityContext;
      await this.dbManager.initialize(context);
      this.resourceMgr = context.resourceManager;
      this.initialized = true;
      await this.loadBookCounts();
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `数据库初始化失败: ${errMsg}`, duration: 2000 });
    }
  }

  private async loadBookCounts(): Promise<void> {
    try {
      const words = await this.dbManager.getAllWords();
      const counts = new Map<string, number>();
      const mastered = new Map<string, number>();
      for (const item of words) {
        const key = item.bookId ?? '';
        if (key.length === 0) {
          continue;
        }
        counts.set(key, (counts.get(key) ?? 0) + 1);
        if (item.status === WordStatus.MASTERED) {
          mastered.set(key, (mastered.get(key) ?? 0) + 1);
        }
      }
      this.wordCounts = counts;
      this.masteredCounts = mastered;
      this.customBooks = this.buildCustomBooks(counts);
      this.ensureCurrentBook(counts);
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[WordBookPage] Failed to load book counts:', errMsg);
    }
  }

  private buildCustomBooks(counts: Map<string, number>): WordBookCardData[] {
    const builtInIds = new Set(BuiltInWordBooks.map((book) => book.id));
    const list: WordBookCardData[] = [];
    counts.forEach((count: number, id: string) => {
      if (!builtInIds.has(id)) {
        list.push({
          id,
          name: id,
          total: count,
          hasUpdate: false,
          isCustom: true,
          isImported: true
        });
      }
    });
    return list;
  }

  private ensureCurrentBook(counts: Map<string, number>): void {
    const stored = AppStorage.get<string>(this.STORAGE_KEY_CURRENT_BOOK) ?? '';
    if (stored.length > 0) {
      this.currentBookId = stored;
      return;
    }
    const countEntries = Array.from(counts.keys());
    if (countEntries.length > 0) {
      this.currentBookId = countEntries[0];
      AppStorage.setOrCreate(this.STORAGE_KEY_CURRENT_BOOK, this.currentBookId);
      return;
    }
    if (BuiltInWordBooks.length > 0) {
      this.currentBookId = BuiltInWordBooks[0].id;
      AppStorage.setOrCreate(this.STORAGE_KEY_CURRENT_BOOK, this.currentBookId);
    }
  }

  private getSystemBooks(): WordBookCardData[] {
    return BuiltInWordBooks.map((book) => ({
      id: book.id,
      name: book.name,
      total: this.wordCounts.get(book.id) ?? book.wordCount,
      hasUpdate: book.hasUpdate,
      isCustom: false,
      source: book.source,
      license: book.license,
      isImported: (this.wordCounts.get(book.id) ?? 0) > 0
    } as WordBookCardData));
  }

  private async importBook(book: WordBookDefinition): Promise<void> {
    await this.ensureDB();
    if (this.resourceMgr === null) {
      promptAction.showToast({ message: '资源管理器未就绪', duration: 1500 });
      return;
    }
    const words = await buildWordItemsForBook(book, this.resourceMgr);
    if (words.length === 0) {
      promptAction.showToast({ message: '词书内容为空', duration: 1500 });
      return;
    }
    try {
      const inserted = await this.dbManager.insertWords(words);
      this.wordCounts.set(book.id, (this.wordCounts.get(book.id) ?? 0) + inserted);
      this.wordCounts = new Map(this.wordCounts);
      this.currentBookId = book.id;
      AppStorage.setOrCreate(this.STORAGE_KEY_CURRENT_BOOK, book.id);
      promptAction.showToast({ message: `已导入 ${inserted} 个单词`, duration: 1500 });
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `导入失败: ${errMsg}`, duration: 2000 });
    }
  }

  private setCurrentBook(bookId: string): void {
    this.currentBookId = bookId;
    AppStorage.setOrCreate(this.STORAGE_KEY_CURRENT_BOOK, bookId);
  }

  private openImportPage(): void {
    router.pushUrl({ url: 'pages/ImportPage' });
  }

  build() {
    Column() {
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor(DesignTokens.Colors.GRAY_900)
          .accessibilityText('返回')
          .onClick(() => router.back());

        Text('词书管理')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(DesignTokens.Colors.GRAY_900)
          .margin({ left: 16 });

        Blank();
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#F5F7FB');

      Scroll() {
        Column() {
          Row() {
            Text('🔍')
              .fontSize(18)
              .fontColor(DesignTokens.Colors.GRAY_600);

            TextInput({ text: this.searchText, placeholder: '搜索词书名称' })
              .layoutWeight(1)
              .height(44)
              .fontSize(14)
              .backgroundColor(Color.Transparent)
              .onChange((value: string) => (this.searchText = value));
          }
          .width('100%')
          .height(52)
          .padding({ left: 12, right: 12 })
          .backgroundColor('#FFFFFFCC')
          .borderRadius(DesignTokens.BorderRadius.LG)
          .margin({ top: 16 });

          this.buildSectionHeader('系统词书')
          ForEach(this.getSystemBooks().filter((book) => this.filterBook(book)), (book: WordBookCardData) => {
            this.buildBookCard(book)
          }, (book: WordBookCardData) => book.id)

          this.buildSectionHeader('可下载词书')
          if (this.getSystemBooks().length === 0) {
            this.buildEmptyCustomHint()
          } else {
            Text('暂无可下载词书')
              .fontSize(14)
              .fontColor(DesignTokens.Colors.GRAY_500)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 12, bottom: 12 });
          }

          this.buildSectionHeader('我的词书')
          if (this.customBooks.length === 0) {
            this.buildEmptyCustomHint()
          } else {
            ForEach(this.customBooks.filter((book) => this.filterBook(book)), (book: WordBookCardData) => {
              this.buildBookCard(book)
            }, (book: WordBookCardData) => book.id)
          }

          Button('导入词书')
            .width('100%')
            .height(48)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(DesignTokens.Colors.PRIMARY)
            .backgroundColor(DesignTokens.Colors.PRIMARY_LIGHTEST)
            .borderRadius(DesignTokens.BorderRadius.FULL)
            .margin({ top: 24, bottom: 12 })
            .onClick(() => this.openImportPage());
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 32 });
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off);
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FB');
  }

  @Builder
  buildSectionHeader(title: string) {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor(DesignTokens.Colors.GRAY_800)
      .margin({ top: 20, bottom: 12 })
      .width('100%');
  }

  @Builder
  buildEmptyCustomHint() {
    Column() {
      Text('暂无自建词书')
        .fontSize(14)
        .fontColor(DesignTokens.Colors.GRAY_500)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 12, bottom: 12 });
    }
  }

  @Builder
  buildBookCard(book: WordBookCardData) {
    Column() {
      Text(book.name)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(DesignTokens.Colors.GRAY_900);

      Row() {
        Text(`${book.total} 词`)
          .fontSize(12)
          .fontColor(DesignTokens.Colors.GRAY_600);

        Text(this.getDifficultyLabel(book.id))
          .fontSize(12)
          .fontColor(DesignTokens.Colors.PRIMARY)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .margin({ left: 8 })
          .borderRadius(12)
          .backgroundColor(DesignTokens.Colors.PRIMARY_LIGHTEST);
      }
      .width('100%')
      .margin({ top: 8 });

      if (!book.isCustom && book.source) {
        Text(`${book.source} · ${book.license ?? ''}`)
          .fontSize(11)
          .fontColor(DesignTokens.Colors.GRAY_500)
          .margin({ top: 6 })
          .width('100%');
      }

      if (this.getProgressValue(book.id) > 0) {
        Progress({
          value: this.getProgressValue(book.id),
          total: 100,
          type: ProgressType.Linear
        })
          .height(6)
          .width('100%')
          .color(DesignTokens.Colors.PRIMARY)
          .backgroundColor(DesignTokens.Colors.GRAY_200)
          .margin({ top: 12 });
      }

      Row({ space: 8 }) {
        if (!book.isCustom) {
          Button(book.isImported ? '已导入' : '导入')
            .layoutWeight(1)
            .height(36)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(book.isImported ? DesignTokens.Colors.GRAY_500 : DesignTokens.Colors.PRIMARY)
            .backgroundColor(book.isImported ? DesignTokens.Colors.GRAY_200 : DesignTokens.Colors.PRIMARY_LIGHTEST)
            .borderRadius(DesignTokens.BorderRadius.FULL)
            .enabled(!book.isImported)
            .onClick(() => {
              const def = BuiltInWordBooks.find((item) => item.id === book.id);
              if (def) {
                this.importBook(def);
              }
            });
        }

        Button('选择学习')
          .layoutWeight(1)
          .height(36)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(DesignTokens.Colors.WHITE)
          .backgroundColor(this.currentBookId === book.id ? DesignTokens.Colors.PRIMARY_DARK : DesignTokens.Colors.PRIMARY)
          .borderRadius(DesignTokens.BorderRadius.FULL)
          .onClick(() => this.setCurrentBook(book.id));
      }
      .width('100%')
      .margin({ top: 12 });
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFFCC')
    .borderRadius(DesignTokens.BorderRadius.XL)
    .border({ width: 1, color: '#E5ECF7' })
    .margin({ bottom: 12 })
    .onClick(() => {
      // Issue #6 fix: Debounce navigation to prevent freeze/crash from multiple clicks
      if (this.isNavigating) {
        console.log('[WordBookPage] Navigation already in progress, ignoring click');
        return;
      }
      
      this.isNavigating = true;
      this.setCurrentBook(book.id);
      
      router.pushUrl({
        url: 'pages/WordListPage',
        params: {
          bookId: book.id,
          bookName: book.name
        }
      }).then(() => {
        // Reset flag after navigation completes
        setTimeout(() => {
          this.isNavigating = false;
        }, this.NAVIGATION_COOLDOWN_MS);
      }).catch((err) => {
        console.error('[WordBookPage] Navigation failed:', err);
        this.isNavigating = false;
      });
    });
  }

  private filterBook(book: WordBookCardData): boolean {
    const keyword = this.searchText.trim().toLowerCase();
    if (keyword.length === 0) {
      return true;
    }
    return book.name.toLowerCase().includes(keyword) || book.id.toLowerCase().includes(keyword);
  }

  private getDifficultyLabel(bookId: string): string {
    if (bookId.includes('cet4')) {
      return 'CET4';
    }
    if (bookId.includes('cet6')) {
      return 'CET6';
    }
    if (bookId.includes('kaoyan')) {
      return '考研';
    }
    if (bookId.toLowerCase().includes('tem')) {
      return '专八';
    }
    return '自定义';
  }

  private getProgressValue(bookId: string): number {
    const total = this.wordCounts.get(bookId) ?? 0;
    if (total <= 0) {
      return 0;
    }
    const mastered = this.masteredCounts.get(bookId) ?? 0;
    return Math.min(100, Math.max(0, (mastered / total) * 100));
  }
}
