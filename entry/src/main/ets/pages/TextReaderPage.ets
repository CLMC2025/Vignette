import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';
import media from '@ohos.multimedia.media';

import { DesignTokens } from '../model/DesignTokens';
import { ColorsInterface } from '../model/TokenInterfaces';
import { ThemeManager } from '../manager/ThemeManager';
import { DBManager } from '../database/DBManager';
import { DictionaryManager } from '../manager/DictionaryManager';
import { ClickableText } from '../components/ClickableText';
import { AddToBookDialog, AddToBookDialogResult } from '../components/AddToBookDialog';
import { CreateBookDialog, CreateBookDialogResult } from '../components/CreateBookDialog';
import { ContextWordMeaningStore } from '../utils/ContextWordMeaningStore';
import { SettingsStore } from '../utils/SettingsStore';
import { openUrl } from '../utils/UrlOpener';
import { DialogState } from './ReadPageModels';
import { AppSettings, WordDefinition, WordItem, WordStatus } from '../model/WordModel';
import { WordSidePanel } from './WordSidePanel';

interface TextReaderPageParams {
  textId?: number;
}

@Entry
@Component
struct TextReaderPage {
  @State private textId: number = 0;
  @State private title: string = '';
  @State private content: string = '';
  @State private isLoading: boolean = true;

  @State private dialogState: DialogState = new DialogState();
  @State private meaningExpanded: boolean = true;
  @State private joinedBookIds: string[] = [];
  @State private joinedBookCount: number = 0;
  @State private showAddToBookDialog: boolean = false;
  @State private showCreateBookDialog: boolean = false;
  @State private pendingAddWord: WordItem | null = null;
  @State private externalDictEnabled: boolean = true;
  @State private externalDictUrlTemplate: string = 'https://www.youdao.com/result?word={word}&lang=en';
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private context: common.UIAbilityContext | null = null;
  private dbManager: DBManager = DBManager.getInstance();
  private dictManager: DictionaryManager = DictionaryManager.getInstance();
  private ctxWordMeaningStore: ContextWordMeaningStore = ContextWordMeaningStore.getInstance();
  private audioPlayer: media.AudioPlayer | null = null;
  private dialogLookupSeq: number = 0;

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  aboutToAppear(): void {
    this.context = getContext(this) as common.UIAbilityContext;
    void this.init();
  }

  aboutToDisappear(): void {
    if (this.audioPlayer !== null) {
      this.audioPlayer.release();
      this.audioPlayer = null;
    }
  }

  private async init(): Promise<void> {
    this.isLoading = true;
    try {
      await this.dbManager.initialize(this.context!);
    } catch (_) {}
    this.ctxWordMeaningStore.injectContext(this.context!);
    try {
      await this.ctxWordMeaningStore.initialize();
    } catch (_) {}
    const settingsStore = SettingsStore.getInstance();
    settingsStore.injectContext(this.context!);
    try {
      await settingsStore.initialize();
      const settings: AppSettings | null = await settingsStore.getSettings();
      if (settings !== null) {
        this.externalDictEnabled = settings.externalDictEnabled;
        this.externalDictUrlTemplate = settings.externalDictUrlTemplate;
      }
    } catch (_) {}

    try {
      const params = router.getParams() as TextReaderPageParams;
      const id = Number(params?.textId ?? 0);
      this.textId = id;
      if (id <= 0) {
        promptAction.showToast({ message: '无法打开文本：参数缺失', duration: 1500 });
        router.back();
        return;
      }
      const row = await this.dbManager.getTextById(id);
      if (row === null) {
        promptAction.showToast({ message: '文本不存在或已被删除', duration: 1500 });
        router.back();
        return;
      }
      this.title = row.title ?? '未命名文本';
      this.content = row.content ?? '';
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `加载失败：${msg}`, duration: 1500 });
      router.back();
    } finally {
      this.isLoading = false;
    }
  }

  private splitParagraphs(text: string): string[] {
    const normalized = text.replace(/\r\n/g, '\n');
    const parts = normalized.split(/\n\s*\n/);
    const out: string[] = [];
    for (const p of parts) {
      const trimmed = p.trim();
      if (trimmed.length > 0) {
        out.push(trimmed);
      }
    }
    return out;
  }

  private hashContextText(text: string): string {
    const s = text.trim();
    let h = 2166136261;
    for (let i = 0; i < s.length; i += 1) {
      h ^= s.charCodeAt(i);
      h = Math.imul(h, 16777619);
    }
    return (h >>> 0).toString(16);
  }

  private isDefinitionUsable(definition: WordDefinition): boolean {
    if (definition.word.trim().length === 0) {
      return false;
    }
    if (definition.contextMeaning.trim().length > 0) {
      return true;
    }
    return definition.commonMeanings.length > 0;
  }

  private closeWordPanel(): void {
    this.dialogLookupSeq += 1;
    this.dialogState = new DialogState();
    this.joinedBookIds = [];
    this.joinedBookCount = 0;
  }

  private playPronunciation(word: string): void {
    if (this.audioPlayer === null) {
      this.audioPlayer = media.createAudioPlayer();
    }
    const audioUrl = `https://dict.youdao.com/dictvoice?type=2&audio=${encodeURIComponent(word)}`;
    this.audioPlayer.src = audioUrl;
    this.audioPlayer.play();
  }

  private buildExternalDictUrl(word: string): string {
    const w = word.trim().toLowerCase();
    if (w.length === 0) {
      return '';
    }
    const template = this.externalDictUrlTemplate.trim();
    if (template.length === 0) {
      return '';
    }
    return template.replace(/\{word\}/g, encodeURIComponent(w));
  }

  private openExternalDict(word: string): void {
    if (!this.externalDictEnabled || this.context === null) {
      return;
    }
    const url = this.buildExternalDictUrl(word);
    if (url.length === 0) {
      promptAction.showToast({ message: '外部词典链接未配置', duration: 1200 });
      return;
    }
    void openUrl(this.context, url);
  }

  private async toggleKnownFromPanel(item: WordItem): Promise<void> {
    try {
      const nextItem = item.clone();
      nextItem.status = nextItem.status === WordStatus.KNOWN ? WordStatus.LEARNING : WordStatus.KNOWN;
      nextItem.updatedAt = Date.now();
      await this.dbManager.updateWord(nextItem);
      const next = this.dialogState.clone();
      next.wordItem = nextItem;
      this.dialogState = next;
      promptAction.showToast({ message: nextItem.status === WordStatus.KNOWN ? '已标记为已知' : '已恢复学习', duration: 900 });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `操作失败：${msg}`, duration: 1500 });
    }
  }

  private async ensureWordItem(word: string): Promise<WordItem | null> {
    const normalized = word.trim().toLowerCase();
    if (normalized.length === 0) {
      return null;
    }
    const existing = await this.dbManager.getWordByWord(normalized);
    if (existing !== null) {
      return existing;
    }
    const item = new WordItem(0, normalized);
    item.bookId = 'user_added';
    item.updatedAt = Date.now();
    const rowId = await this.dbManager.insertWord(item);
    if (rowId > 0) {
      const after = await this.dbManager.getWordByWord(normalized);
      return after;
    }
    return await this.dbManager.getWordByWord(normalized);
  }

  private async refreshJoinedBooksForDialog(wordText: string): Promise<void> {
    try {
      const books = await this.dbManager.getUserWordBooksContainingWord(wordText);
      this.joinedBookIds = books.map((b) => b.id);
      this.joinedBookCount = this.joinedBookIds.length;
    } catch (_) {
      this.joinedBookIds = [];
      this.joinedBookCount = 0;
    }
  }

  private openAddToBookDialog(): void {
    const item = this.dialogState.wordItem;
    if (item === null) {
      return;
    }
    this.pendingAddWord = item;
    this.showAddToBookDialog = true;
    this.showCreateBookDialog = false;
    void this.refreshJoinedBooksForDialog(item.word);
  }

  private dismissAddDialogs(): void {
    this.showAddToBookDialog = false;
    this.showCreateBookDialog = false;
    this.pendingAddWord = null;
  }

  private handleAddDialogSelect(result: AddToBookDialogResult): void {
    void this.joinPendingWordToBook(result.bookId, result.bookName);
  }

  private handleAddDialogRequestCreate(): void {
    this.showAddToBookDialog = false;
    this.showCreateBookDialog = true;
  }

  private handleCreateBookCancel(): void {
    this.showCreateBookDialog = false;
    if (this.pendingAddWord !== null) {
      this.showAddToBookDialog = true;
    }
  }

  private handleCreateBookSubmit(result: CreateBookDialogResult): void {
    void this.createBookAndJoin(result.name);
  }

  private async createBookAndJoin(bookName: string): Promise<void> {
    if (this.pendingAddWord === null) {
      return;
    }
    try {
      const bookId = await this.dbManager.createUserWordBook(bookName);
      await this.joinPendingWordToBook(bookId, bookName);
      this.dismissAddDialogs();
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `创建词书失败：${errMsg}`, duration: 2000 });
      this.showCreateBookDialog = false;
      this.showAddToBookDialog = true;
    }
  }

  private async joinPendingWordToBook(bookId: string, bookName: string): Promise<void> {
    if (this.pendingAddWord === null) {
      return;
    }
    try {
      await this.dbManager.addWordToUserWordBook(bookId, this.pendingAddWord.word);
      promptAction.showToast({ message: `已加入「${bookName}」`, duration: 1200 });
      await this.refreshJoinedBooksForDialog(this.pendingAddWord.word);
      this.dismissAddDialogs();
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `加入失败：${errMsg}`, duration: 2000 });
    }
  }

  private async addToNotebook(): Promise<void> {
    const word = this.dialogState.word;
    if (word.length === 0) {
      return;
    }
    try {
      await this.dbManager.addWordToNotebook(word);
      const next = this.dialogState.clone();
      next.inNotebook = true;
      this.dialogState = next;
      promptAction.showToast({ message: '已收藏', duration: 1000 });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `加入失败：${msg}`, duration: 1500 });
    }
  }

  private async removeFromNotebook(): Promise<void> {
    const word = this.dialogState.word;
    if (word.length === 0) {
      return;
    }
    try {
      await this.dbManager.removeWordFromNotebook(word);
      const next = this.dialogState.clone();
      next.inNotebook = false;
      this.dialogState = next;
      promptAction.showToast({ message: '已取消收藏', duration: 1000 });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `操作失败：${msg}`, duration: 1500 });
    }
  }

  private async onWordClick(word: string, contextText: string): Promise<void> {
    const normalizedWord = word.toLowerCase().trim();
    if (normalizedWord.length === 0) {
      return;
    }
    const normalizedContext = contextText.trim();

    this.dialogLookupSeq += 1;
    const seq = this.dialogLookupSeq;
    const newDialogState = new DialogState();
    newDialogState.isVisible = true;
    newDialogState.word = normalizedWord;
    const peekedBase = this.dictManager.peekDefinition(normalizedWord);
    newDialogState.definition = peekedBase;
    newDialogState.isLoading = peekedBase === null;
    this.dialogState = newDialogState;
    this.meaningExpanded = true;
    this.joinedBookIds = [];
    this.joinedBookCount = 0;

    try {
      const wordItem = await this.ensureWordItem(normalizedWord);
      if (this.dialogLookupSeq !== seq) {
        return;
      }
      const inNotebook = await this.dbManager.isWordInNotebook(normalizedWord);
      if (this.dialogLookupSeq !== seq) {
        return;
      }
      await this.refreshJoinedBooksForDialog(normalizedWord);
      if (this.dialogLookupSeq !== seq) {
        return;
      }

      if (wordItem !== null && this.isDefinitionUsable(wordItem.definition)) {
        const state = this.dialogState.clone();
        state.wordItem = wordItem;
        state.definition = wordItem.definition;
        state.inNotebook = inNotebook;
        state.isLoading = false;
        this.dialogState = state;
      } else {
        const baseResult = await this.dictManager.lookup(normalizedWord, '');
        if (this.dialogLookupSeq !== seq) {
          return;
        }
        if (baseResult.success && baseResult.definition !== null) {
          const state = this.dialogState.clone();
          state.definition = baseResult.definition;
          state.wordItem = wordItem;
          state.inNotebook = inNotebook;
          state.isLoading = false;
          this.dialogState = state;
        } else {
          const state = this.dialogState.clone();
          state.definition = new WordDefinition(normalizedWord, '', '', baseResult.error.length > 0 ? baseResult.error : '未找到释义', [], 'local');
          state.wordItem = wordItem;
          state.inNotebook = inNotebook;
          state.isLoading = false;
          this.dialogState = state;
          return;
        }
      }

      if (wordItem !== null && wordItem.status === WordStatus.NEW) {
        try {
          const updated = wordItem.clone();
          updated.status = WordStatus.LEARNING;
          updated.dueDate = Date.now();
          updated.updatedAt = Date.now();
          await this.dbManager.updateWord(updated);
          if (this.dialogLookupSeq !== seq) {
            return;
          }
          const next = this.dialogState.clone();
          next.wordItem = updated;
          this.dialogState = next;
        } catch (_) {}
      }

      if (normalizedContext.length > 0) {
        const contextKey = this.ctxWordMeaningStore.buildKey(normalizedWord, this.hashContextText(normalizedContext));
        const cachedMeaning = await this.ctxWordMeaningStore.getContextMeaning(contextKey);
        if (this.dialogLookupSeq !== seq) {
          return;
        }
        if (cachedMeaning.length > 0) {
          const baseDef = this.dialogState.definition ?? new WordDefinition(normalizedWord);
          const merged = WordDefinition.fromJSON(baseDef.toJSON());
          merged.contextMeaning = cachedMeaning;
          const next = this.dialogState.clone();
          next.definition = merged;
          next.isLoading = false;
          this.dialogState = next;
          return;
        }
        if (this.dictManager.isConfigured()) {
          const generatedMeaning = await this.dictManager.lookupContextMeaning(normalizedWord, normalizedContext);
          if (this.dialogLookupSeq !== seq) {
            return;
          }
          if (generatedMeaning.length > 0) {
            void this.ctxWordMeaningStore.setContextMeaning(contextKey, generatedMeaning);
            const baseDef = this.dialogState.definition ?? new WordDefinition(normalizedWord);
            const merged = WordDefinition.fromJSON(baseDef.toJSON());
            merged.contextMeaning = generatedMeaning;
            const next = this.dialogState.clone();
            next.definition = merged;
            next.isLoading = false;
            this.dialogState = next;
          }
        }
      }
    } catch (e) {
      if (this.dialogLookupSeq !== seq) {
        return;
      }
      const state = this.dialogState.clone();
      state.definition = new WordDefinition(normalizedWord, '', '', '查询失败', [], 'local');
      state.isLoading = false;
      this.dialogState = state;
    }
  }

  @Builder
  buildAddToBookDialogs() {
    Stack() {
      if (this.pendingAddWord !== null) {
        AddToBookDialog({
          visible: this.showAddToBookDialog,
          word: this.pendingAddWord,
          joinedBookIds: this.joinedBookIds,
          onDismiss: () => this.dismissAddDialogs(),
          onSelectBook: (result: AddToBookDialogResult) => this.handleAddDialogSelect(result),
          onRequestCreateBook: () => this.handleAddDialogRequestCreate()
        })

        CreateBookDialog({
          visible: this.showCreateBookDialog,
          onCancel: () => this.handleCreateBookCancel(),
          onCreate: (result: CreateBookDialogResult) => this.handleCreateBookSubmit(result)
        })
      }
    }
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text(this.title.length > 0 ? this.title : '文本阅读')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.colors.GRAY_900)
            .layoutWeight(1)

          Text('编辑')
            .fontSize(14)
            .fontColor(this.colors.PRIMARY)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(this.colors.PRIMARY_LIGHTEST)
            .borderRadius(14)
            .onClick(() => {
              router.pushUrl({ url: 'pages/TextEditPage', params: { textId: this.textId } });
            })

          Text('返回')
            .fontSize(14)
            .fontColor(this.colors.GRAY_600)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .margin({ left: 8 })
            .onClick(() => router.back())
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
          Scroll() {
            Column({ space: 14 }) {
              ForEach(this.splitParagraphs(this.content), (p: string, idx: number) => {
                Column() {
                  ClickableText({
                    text: p,
                    fontSize: 16,
                    fontColor: this.colors.GRAY_900,
                    wordColor: this.colors.PRIMARY,
                    lineHeight: 26,
                    onWordClick: (w: string) => { void this.onWordClick(w, p); }
                  })
                }
                .width('100%')
                .padding(14)
                .backgroundColor(this.colors.SURFACE_PRIMARY)
                .borderRadius(14)
              }, (_: string, idx: number) => `p-${idx}`)
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

      if (this.dialogState.isVisible) {
        WordSidePanel({
          dialogState: this.dialogState,
          meaningExpanded: this.meaningExpanded,
          newbieMode: false,
          joinedBookCount: this.joinedBookCount,
          externalDictEnabled: this.externalDictEnabled,
          onClose: () => this.closeWordPanel(),
          onPlayPronunciation: (word: string) => this.playPronunciation(word),
          onAddToBook: () => this.openAddToBookDialog(),
          onAddToNotebook: () => { void this.addToNotebook(); },
          onRemoveFromNotebook: () => { void this.removeFromNotebook(); },
          onOpenExternalDict: (word: string) => this.openExternalDict(word),
          onToggleKnown: (wordItem: WordItem) => { void this.toggleKnownFromPanel(wordItem); }
        })
        .align(Alignment.Bottom)
      }

      if (this.showAddToBookDialog || this.showCreateBookDialog) {
        this.buildAddToBookDialogs()
      }
    }
  }
}
