// =====================================================
// WordDetailPage.ets - Word details page (Optimized)
// Shows definition, learning status, FSRS metrics and history summary
// =====================================================

import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';
import media from '@ohos.multimedia.media';

import { DesignTokens } from '../model/DesignTokens';
import { ColorsInterface } from '../model/TokenInterfaces';
import { ThemeManager } from '../manager/ThemeManager';
import { LoadingAnimation, LoadingType } from '../ui/LoadingAnimations';
import { DBManager } from '../database/DBManager';
import { AppSettings, WordDefinition, WordItem, WordStatus, WordMeaning, PhraseItem, ExampleItem, QueueItem } from '../model/WordModel';
import { DictionaryManager } from '../manager/DictionaryManager';
import { BuiltInDictionary } from '../manager/BuiltInDictionary';
import { WordDetailCache } from '../utils/WordDetailCache';
import { AddToBookDialog, AddToBookDialogResult } from '../components/AddToBookDialog';
import { CreateBookDialog, CreateBookDialogResult } from '../components/CreateBookDialog';
import { SessionTransferStore } from '../utils/SessionTransferStore';
import { ClickableText } from '../components/ClickableText';
import { WordDetailDialog } from './WordDetailDialog';
import { DialogState } from './ReadPageModels';
import { ContextWordMeaningStore } from '../utils/ContextWordMeaningStore';
import { SettingsStore } from '../utils/SettingsStore';
import { openUrl } from '../utils/UrlOpener';

interface WordDetailParams {
  wordId?: number;
  wordText?: string;
}

interface RouterParams {
  sessionId: string;
}

@Entry
@Component
struct WordDetailPage {
  @State private isLoading: boolean = true;
  @State private isDefinitionLoading: boolean = false;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();
  @State private definitionStatusText: string = '';
  @State private word: WordItem | null = null;
  @State private wordStatusRefresh: number = 0;
  @State private showAddToBookDialog: boolean = false;
  @State private showCreateBookDialog: boolean = false;
  @State private pendingAddWord: WordItem | null = null;
  @State private joinedBookIds: string[] = [];
  @State private isPlayingAudio: boolean = false;
  @State private expandedSections: Set<string> = new Set(['meaning', 'progress']);
  @State private isEnrichingDefinition: boolean = false;
  @State private isInLearningQueueState: boolean = false;
  @State private dialogState: DialogState = new DialogState();
  @State private meaningExpanded: boolean = true;
  @State private joinedBookCount: number = 0;
  @State private externalDictEnabled: boolean = true;
  @State private externalDictUrlTemplate: string = 'https://www.youdao.com/result?word={word}&lang=en';

  private wordId: number = 0;
  private wordText: string = '';
  private dbManager: DBManager = DBManager.getInstance();
  private dictManager: DictionaryManager = DictionaryManager.getInstance();
  private ctxWordMeaningStore: ContextWordMeaningStore = ContextWordMeaningStore.getInstance();
  private context: common.UIAbilityContext | null = null;
  private audioPlayer: media.AudioPlayer | null = null;
  private dialogLookupSeq: number = 0;

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
      if (this.context !== null) {
        try {
          await this.dbManager.initialize(this.context);
        } catch (initError) {
          console.warn('[WordDetailPage] Database already initialized:', initError);
        }
        this.ctxWordMeaningStore.injectContext(this.context);
        await this.ctxWordMeaningStore.initialize();
        const settingsStore = SettingsStore.getInstance();
        settingsStore.injectContext(this.context);
        await settingsStore.initialize();
        const settings: AppSettings | null = await settingsStore.getSettings();
        if (settings !== null) {
          this.externalDictEnabled = settings.externalDictEnabled;
          this.externalDictUrlTemplate = settings.externalDictUrlTemplate;
        }
      }

      const params = router.getParams() as WordDetailParams;
      this.wordId = Number(params?.wordId ?? 0);
      this.wordText = String(params?.wordText ?? '');
      if (this.wordId <= 0 && this.wordText.trim().length === 0) {
        promptAction.showToast({ message: '无法打开单词详情：参数缺失', duration: 1500 });
        router.back();
        return;
      }

      // 如果 wordId > 0，尝试从缓存或数据库获取
      if (this.wordId > 0) {
        const cached = WordDetailCache.getInstance().get(this.wordId);
        if (cached !== null) {
          this.word = cached;
          this.isLoading = false;
        }

        const w = await this.dbManager.getWordById(this.wordId);
        if (w !== null) {
          this.word = w;
          this.isInLearningQueueState = this.isInLearningQueue();
          WordDetailCache.getInstance().set(w);
          void this.ensureDefinitionAsync();

          // 如果缺少例句或词组，自动尝试获取
          if (w.definition.phrases.length === 0 || w.definition.examples.length === 0) {
            if (this.dictManager.isConfigured()) {
              void this.enrichDefinition();
            }
          }
          this.isLoading = false;
          return;
        }
      }
      
      // wordId <= 0 或数据库中没有，使用 wordText 创建临时单词
      if (this.wordText.trim().length > 0) {
        const placeholder = new WordItem(0, this.wordText);
        this.word = placeholder;
        this.isLoading = false;
        // 尝试获取单词定义
        void this.ensureDefinitionAsync();
        return;
      }
      
      promptAction.showToast({ message: '单词不存在或已被删除', duration: 1500 });
      router.back();
      return;
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[WordDetailPage] init failed:', errMsg);
      promptAction.showToast({ message: '加载详情失败，请稍后重试', duration: 2000 });
    } finally {
      this.isLoading = false;
    }
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

  private isDefinitionMissing(word: WordItem): boolean {
    if (word.definition.commonMeanings.length > 0) {
      return false;
    }
    if (word.definition.contextMeaning.trim().length > 0) {
      return false;
    }
    if (word.definition.phonetic.trim().length > 0) {
      return false;
    }
    return true;
  }

  private async applyDefinitionToWord(definition: WordDefinition): Promise<void> {
    const current = this.word;
    if (current === null) {
      return;
    }
    const next = current.clone();
    next.definition = definition;
    next.updatedAt = Date.now();
    await this.dbManager.updateWord(next);
    this.word = next;
    WordDetailCache.getInstance().set(next);
  }

  private async ensureDefinitionAsync(): Promise<void> {
    const current = this.word;
    if (current === null) {
      return;
    }
    if (!this.isDefinitionMissing(current)) {
      return;
    }

    this.isDefinitionLoading = true;
    this.definitionStatusText = '正在获取释义...';
    const wordStr = current.word;
    const normalizedWord = wordStr.toLowerCase().trim();

    try {
      // 1. 检查数据库缓存
      const cached = await this.dbManager.getCachedDefinition(normalizedWord);
      if (cached !== null) {
        await this.applyDefinitionToWord(cached);
        return;
      }

      // 2. 使用内置词典
      const builtInDict = BuiltInDictionary.getInstance();
      const builtInDef = await builtInDict.lookup(normalizedWord);
      if (builtInDef !== null) {
        await this.applyDefinitionToWord(builtInDef);
        return;
      }

      // 3. 使用 AI API
      if (!this.dictManager.isConfigured()) {
        this.definitionStatusText = '暂无释义（可在设置中配置 API 后自动生成）';
        return;
      }

      this.definitionStatusText = '正在生成释义...';
      const generated = await this.dictManager.lookup(normalizedWord, '');
      if (generated.definition !== null) {
        await this.applyDefinitionToWord(generated.definition);
      } else {
        this.definitionStatusText = '释义生成失败，请稍后重试';
      }
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[WordDetailPage] ensureDefinition failed:', errMsg);
      this.definitionStatusText = '释义生成失败，请稍后重试';
    } finally {
      this.isDefinitionLoading = false;
    }
  }

  private async enrichDefinition(): Promise<void> {
    const current = this.word;
    if (current === null) {
      return;
    }
    if (!this.dictManager.isConfigured()) {
      promptAction.showToast({ message: '请先配置词典 API', duration: 1500 });
      return;
    }

    this.isEnrichingDefinition = true;
    promptAction.showToast({ message: '正在获取例句和词组...', duration: 1500 });

    try {
      const wordStr = current.word;
      const normalizedWord = wordStr.toLowerCase().trim();

      // 先清除缓存，强制从 AI 获取最新数据
      await this.dbManager.clearCachedDefinition(normalizedWord);

      const result = await this.dictManager.lookup(wordStr, '');
      if (result.definition !== null) {
        await this.applyDefinitionToWord(result.definition);
        promptAction.showToast({ message: '已更新单词详情', duration: 1500 });
      } else {
        promptAction.showToast({ message: '获取失败，请稍后重试', duration: 1500 });
      }
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[WordDetailPage] enrichDefinition failed:', errMsg);
      promptAction.showToast({ message: '获取失败，请稍后重试', duration: 1500 });
    } finally {
      this.isEnrichingDefinition = false;
    }
  }

  private getWordStatus(): WordStatus {
    // 强制依赖 wordStatusRefresh 触发 UI 更新
    const _ = this.wordStatusRefresh;
    return this.word?.status ?? WordStatus.NEW;
  }

  private getStatusText(status: WordStatus): string {
    switch (status) {
      case WordStatus.NEW: return '新词';
      case WordStatus.LEARNING: return '学习中';
      case WordStatus.REVIEW: return '复习';
      case WordStatus.RELEARNING: return '重新学习';
      case WordStatus.KNOWN: return '已知';
      default: return '未知';
    }
  }

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private getStatusColor(status: WordStatus): ResourceColor {
    switch (status) {
      case WordStatus.NEW: return this.colors.STATUS_NEW;
      case WordStatus.LEARNING: return this.colors.STATUS_LEARNING;
      case WordStatus.REVIEW: return this.colors.STATUS_REVIEW;
      case WordStatus.RELEARNING: return this.colors.STATUS_RELEARNING;
      case WordStatus.KNOWN: return this.colors.SUCCESS;
      default: return this.colors.GRAY_500;
    }
  }

  private getStatusGradient(status: WordStatus): [ResourceColor, ResourceColor] {
    if (this.themeRefreshToken >= 0) {
      return [this.colors.SURFACE_ELEVATED, this.colors.SURFACE_PRIMARY];
    }
    switch (status) {
      case WordStatus.NEW: return [this.colors.PRIMARY_LIGHTEST, this.colors.PRIMARY_LIGHT];
      case WordStatus.LEARNING: return [this.colors.WARNING_LIGHTEST, this.colors.WARNING_LIGHT];
      case WordStatus.REVIEW: return [this.colors.PURPLE, this.colors.INDIGO];
      case WordStatus.RELEARNING: return [this.colors.SECONDARY_LIGHTEST, this.colors.SECONDARY_LIGHT];
      case WordStatus.KNOWN: return [this.colors.SUCCESS_LIGHTEST, this.colors.SUCCESS_LIGHT];
      default: return [this.colors.BACKGROUND_SECONDARY, this.colors.BACKGROUND_TERTIARY];
    }
  }

  private formatTime(ts: number): string {
    if (ts <= 0) return '-';
    const d = new Date(ts);
    const pad = (n: number): string => (n < 10 ? `0${n}` : `${n}`);
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  private formatRelativeTime(ts: number): string {
    const diff = ts - Date.now();
    const minuteMs = 60 * 1000;
    const hourMs = 60 * minuteMs;
    const dayMs = 24 * hourMs;

    if (diff <= 0) return '现在';
    if (diff < hourMs) {
      const minutes = Math.max(1, Math.round(diff / minuteMs));
      return `${minutes}分钟`;
    }
    if (diff < dayMs) {
      const hours = Math.max(1, Math.round(diff / hourMs));
      return `${hours}小时`;
    }
    const days = Math.max(1, Math.round(diff / dayMs));
    return `${days}天`;
  }

  private getNextReviewLabel(word: WordItem): string {
    const formatted = this.formatTime(word.dueDate);
    const relative = this.formatRelativeTime(word.dueDate);
    if (relative === '现在') {
      return `${formatted}（现在可复习）`;
    }
    return `${formatted}（还有${relative}）`;
  }

  private buildMeaningLine(m: WordMeaning): string {
    const pos = m.pos.trim().length > 0 ? `${m.pos} ` : '';
    const cn = m.cn.trim().length > 0 ? m.cn : '-';
    return `${pos}${cn}`;
  }

  private toggleSection(section: string): void {
    const newSet = new Set(this.expandedSections);
    if (newSet.has(section)) {
      newSet.delete(section);
    } else {
      newSet.add(section);
    }
    this.expandedSections = newSet;
  }

  private async playPronunciation(): Promise<void> {
    if (this.word === null || this.isPlayingAudio) {
      return;
    }

    this.isPlayingAudio = true;
    try {
      const word = this.word.word;
      const audioUrl = `https://dict.youdao.com/dictvoice?type=2&audio=${encodeURIComponent(word)}`;

      if (this.audioPlayer === null) {
        this.audioPlayer = media.createAudioPlayer();
      }

      this.audioPlayer.src = audioUrl;
      this.audioPlayer.play();

      setTimeout(() => {
        this.isPlayingAudio = false;
      }, 2000);
    } catch (e) {
      console.error('[WordDetailPage] Play pronunciation failed:', e);
      this.isPlayingAudio = false;
      promptAction.showToast({ message: '播放失败', duration: 1500 });
    }
  }

  private async toggleLearningQueue(): Promise<void> {
    if (this.word === null) {
      return;
    }

    try {
      const updated = this.word.clone();
      const isInQueue = this.isInLearningQueue();
      
      if (isInQueue) {
        // 取消加入队列，恢复为 NEW 状态，dueDate 设为 1 天后
        updated.status = WordStatus.NEW;
        updated.dueDate = Date.now() + 24 * 60 * 60 * 1000;
      } else {
        // 加入今日学习队列，状态改为 LEARNING，dueDate 设为现在
        updated.status = WordStatus.LEARNING;
        updated.dueDate = Date.now();
      }
      updated.updatedAt = Date.now();
      await this.dbManager.updateWord(updated);
      this.word = updated;
      this.isInLearningQueueState = !isInQueue;
      WordDetailCache.getInstance().set(updated);
      promptAction.showToast({ message: isInQueue ? '已取消加入队列' : '已加入今日学习队列', duration: 1500 });
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[WordDetailPage] toggleLearningQueue failed:', errMsg);
      promptAction.showToast({ message: '操作失败', duration: 1500 });
    }
  }

  private isInLearningQueue(): boolean {
    if (this.word === null) {
      return false;
    }
    // 只有状态为 LEARNING 且 dueDate 在现在或之前，才认为在队列中
    return this.word.status === WordStatus.LEARNING && this.word.dueDate <= Date.now();
  }

  private async toggleKnown(): Promise<void> {
    if (this.word === null) {
      return;
    }

    try {
      let updated = this.word.clone();
      const isCurrentlyKnown = updated.status === WordStatus.KNOWN;
      
      // 如果单词不在数据库（id=0），先查找或插入
      if (updated.id === 0) {
        const existing = await this.dbManager.getWordByWord(updated.word);
        if (existing !== null) {
          updated = existing.clone();
        } else {
          const newId = await this.dbManager.insertWord(updated);
          if (newId > 0) {
            updated.id = newId;
          } else {
            // 插入失败，可能已存在，再次查找
            const retry = await this.dbManager.getWordByWord(updated.word);
            if (retry !== null) {
              updated = retry.clone();
            } else {
              promptAction.showToast({ message: '操作失败，请重试', duration: 1500 });
              return;
            }
          }
        }
      }
      
      if (isCurrentlyKnown) {
        updated.status = WordStatus.NEW;
        updated.dueDate = Date.now();
      } else {
        updated.status = WordStatus.KNOWN;
        updated.dueDate = 0;
      }
      updated.updatedAt = Date.now();
      await this.dbManager.updateWord(updated);
      this.word = updated;
      this.wordStatusRefresh = Date.now();
      WordDetailCache.getInstance().set(updated);
      promptAction.showToast({ message: isCurrentlyKnown ? '已恢复到学习队列' : '已标记为已知', duration: 1500 });
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[WordDetailPage] toggleKnown failed:', errMsg);
      promptAction.showToast({ message: '操作失败', duration: 1500 });
    }
  }

  private async markSeen(): Promise<void> {
    if (this.word === null) {
      return;
    }
    try {
      let updated = this.word.clone();
      if (updated.status === WordStatus.NEW) {
        // 如果单词不在数据库（id=0），先查找或插入
        if (updated.id === 0) {
          const existing = await this.dbManager.getWordByWord(updated.word);
          if (existing !== null) {
            updated = existing.clone();
            // 如果已经是 LEARNING 或更高状态，不需要再标记
            if (updated.status !== WordStatus.NEW) {
              this.word = updated;
              WordDetailCache.getInstance().set(updated);
              promptAction.showToast({ message: '该单词已在学习中', duration: 1200 });
              return;
            }
          } else {
            const newId = await this.dbManager.insertWord(updated);
            if (newId > 0) {
              updated.id = newId;
            } else {
              const retry = await this.dbManager.getWordByWord(updated.word);
              if (retry !== null) {
                updated = retry.clone();
              } else {
                promptAction.showToast({ message: '操作失败，请重试', duration: 1500 });
                return;
              }
            }
          }
        }
        updated.status = WordStatus.LEARNING;
        updated.dueDate = Date.now();
        updated.updatedAt = Date.now();
        await this.dbManager.updateWord(updated);
        this.word = updated;
        this.wordStatusRefresh = Date.now();
        WordDetailCache.getInstance().set(updated);
        promptAction.showToast({ message: '已标记为已见', duration: 1200 });
      }
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[WordDetailPage] markSeen failed:', errMsg);
      promptAction.showToast({ message: '操作失败', duration: 1500 });
    }
  }

  private async unmarkSeen(): Promise<void> {
    if (this.word === null) {
      return;
    }
    try {
      let updated = this.word.clone();
      if (updated.status === WordStatus.LEARNING) {
        // 如果单词不在数据库（id=0），先查找或插入
        if (updated.id === 0) {
          const existing = await this.dbManager.getWordByWord(updated.word);
          if (existing !== null) {
            updated = existing.clone();
          } else {
            const newId = await this.dbManager.insertWord(updated);
            if (newId > 0) {
              updated.id = newId;
            } else {
              const retry = await this.dbManager.getWordByWord(updated.word);
              if (retry !== null) {
                updated = retry.clone();
              } else {
                promptAction.showToast({ message: '操作失败，请重试', duration: 1500 });
                return;
              }
            }
          }
        }
        updated.status = WordStatus.NEW;
        updated.dueDate = 0;
        updated.updatedAt = Date.now();
        await this.dbManager.updateWord(updated);
        this.word = updated;
        this.wordStatusRefresh = Date.now();
        WordDetailCache.getInstance().set(updated);
        promptAction.showToast({ message: '已撤销标记', duration: 1200 });
      }
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      console.error('[WordDetailPage] unmarkSeen failed:', errMsg);
      promptAction.showToast({ message: '操作失败', duration: 1500 });
    }
  }

  private openAddToBookDialog(): void {
    if (this.word === null) {
      return;
    }
    this.pendingAddWord = this.word;
    this.showAddToBookDialog = true;
    this.showCreateBookDialog = false;
    void this.refreshJoinedBooksForDialog(this.word.word);
  }

  private dismissAddDialogs(): void {
    this.showAddToBookDialog = false;
    this.showCreateBookDialog = false;
    this.pendingAddWord = null;
  }

  private async refreshJoinedBooksForDialog(wordText: string): Promise<void> {
    try {
      const books = await this.dbManager.getUserWordBooksContainingWord(wordText);
      this.joinedBookIds = books.map((b) => b.id);
    } catch (e) {
      this.joinedBookIds = [];
    }
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
      promptAction.showToast({ message: `已加入「${bookName}」`, duration: 1500 });
      this.dismissAddDialogs();
    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      promptAction.showToast({ message: `加入失败：${errMsg}`, duration: 2000 });
    }
  }

  private getFrequencyStars(frequency: number): string {
    const stars = Math.min(5, Math.max(0, frequency));
    return '★'.repeat(stars) + '☆'.repeat(5 - stars);
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

  private hashContextText(text: string): string {
    const s = text.trim();
    let h = 2166136261;
    for (let i = 0; i < s.length; i += 1) {
      h ^= s.charCodeAt(i);
      h = Math.imul(h, 16777619);
    }
    return (h >>> 0).toString(16);
  }

  private async onWordInTextClick(word: string, contextText: string = ''): Promise<void> {
    if (word.length === 0) {
      return;
    }

    const normalizedWord = word.toLowerCase().trim();
    const normalizedContext = contextText.trim();

    // 初始化弹窗状态
    this.dialogLookupSeq += 1;
    const seq = this.dialogLookupSeq;
    const newDialogState = new DialogState();
    newDialogState.isVisible = true;
    newDialogState.word = normalizedWord;
    const peekedBase = this.dictManager.peekDefinition(normalizedWord);
    newDialogState.definition = peekedBase;
    newDialogState.isLoading = peekedBase === null;
    this.dialogState = newDialogState;

    try {
      // 查询单词
      const wordItem = await this.dbManager.getWordByWord(normalizedWord);
      if (this.dialogLookupSeq !== seq) {
        return;
      }
      if (wordItem !== null && this.isDefinitionUsable(wordItem.definition)) {
        const state = this.dialogState.clone();
        state.wordItem = wordItem;
        state.definition = wordItem.definition;
        state.isLoading = false;
        this.dialogState = state;
        if (normalizedContext.length > 0) {
          const contextKey = this.ctxWordMeaningStore.buildKey(normalizedWord, this.hashContextText(normalizedContext));
          const cachedMeaning = await this.ctxWordMeaningStore.getContextMeaning(contextKey);
          if (this.dialogLookupSeq !== seq) {
            return;
          }
          if (cachedMeaning.length > 0) {
            const merged = WordDefinition.fromJSON(wordItem.definition.toJSON());
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
              const merged = WordDefinition.fromJSON(wordItem.definition.toJSON());
              merged.contextMeaning = generatedMeaning;
              const next = this.dialogState.clone();
              next.definition = merged;
              next.isLoading = false;
              this.dialogState = next;
            }
          }
        }
        return;
      }

      // 从词典查询（会先检查缓存）
      const baseResult = await this.dictManager.lookup(normalizedWord, '');
      if (this.dialogLookupSeq !== seq) {
        return;
      }
      if (baseResult.success && baseResult.definition !== null) {
        const state = this.dialogState.clone();
        state.definition = baseResult.definition;
        if (wordItem !== null) {
          state.wordItem = wordItem;
        }
        state.isLoading = false;
        this.dialogState = state;
      } else {
        const state = this.dialogState.clone();
        state.definition = new WordDefinition(normalizedWord, '', '', baseResult.error.length > 0 ? baseResult.error : '未找到释义', [], 'local');
        state.isLoading = false;
        this.dialogState = state;
        return;
      }

      if (normalizedContext.length > 0) {
        const contextKey = this.ctxWordMeaningStore.buildKey(normalizedWord, this.hashContextText(normalizedContext));
        const cachedMeaning = await this.ctxWordMeaningStore.getContextMeaning(contextKey);
        if (this.dialogLookupSeq !== seq) {
          return;
        }
        if (cachedMeaning.length > 0) {
          const baseDef = baseResult.definition!;
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
            const baseDef = baseResult.definition!;
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
      console.error('[WordDetailPage] Failed to lookup word:', e);
      if (this.dialogLookupSeq !== seq) {
        return;
      }
      const state = this.dialogState.clone();
      state.definition = new WordDefinition(normalizedWord, '', '', '查询失败', [], 'local');
      state.isLoading = false;
      this.dialogState = state;
    }
  }

  private async saveWordToDatabase(word: string, definition: WordDefinition): Promise<void> {
    try {
      // 创建新单词并保存到数据库
      const newWord = new WordItem(
        0, // ID will be auto-generated
        word,
        WordStatus.NEW,
        undefined, // fsrsState
        undefined, // history
        definition,
        Date.now(), // dueDate
        Date.now(), // createdAt
        Date.now(), // updatedAt
        'user_added', // bookId
        [], // tags
        0, // lapseCount
        0, // leechLevel
        [], // errorTags
        0 // suspendUntil
      );
      await this.dbManager.insertWord(newWord);
      console.info(`[WordDetailPage] Saved word to database: ${word}`);
    } catch (e) {
      console.error('[WordDetailPage] Failed to save word:', e);
    }
  }

  private closeWordDialog(): void {
    this.dialogLookupSeq += 1;
    this.dialogState = new DialogState();
  }

  private playDialogPronunciation(word: string): void {
    if (this.audioPlayer === null) {
      this.audioPlayer = media.createAudioPlayer();
    }
    const audioUrl = `https://dict.youdao.com/dictvoice?type=2&audio=${encodeURIComponent(word)}`;
    this.audioPlayer.src = audioUrl;
    this.audioPlayer.play();
  }

  build() {
    Stack() {
      Column() {
        // Header
        this.buildHeader()

        if (this.isLoading) {
          this.buildLoadingView()
        } else if (this.word === null) {
          this.buildEmptyView()
        } else {
          Scroll() {
            Column() {
              // Word Header Card with Gradient
              this.buildWordHeaderCard()

              // Quick Actions
              this.buildQuickActions()

              // Meaning Section
              this.buildMeaningSection()

              // Phrases Section
              this.buildPhrasesSection()

              // Examples Section
              this.buildExamplesSection()

              // Learning Progress Card
              this.buildLearningProgressCard()

              // Tags Section
              this.buildTagsSection()

              // Add to Book Section
              this.buildAddToBookSection()
            }
            .width('100%')
            .padding({ left: DesignTokens.Layout.CONTAINER_PADDING, right: DesignTokens.Layout.CONTAINER_PADDING, bottom: 24 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.colors.BACKGROUND_PRIMARY)

      if (this.showAddToBookDialog || this.showCreateBookDialog) {
        this.buildAddToBookFlowDialogs()
      }

      // 单词详情弹窗（点击短语/例句中的单词时显示）
      if (this.dialogState.isVisible) {
        WordDetailDialog({
          dialogState: this.dialogState,
          meaningExpanded: this.meaningExpanded,
          newbieMode: false,
          joinedBookCount: this.joinedBookCount,
          onClose: () => this.closeWordDialog(),
          onPlayPronunciation: (word: string) => this.playDialogPronunciation(word),
          onAddToBook: () => {
            // 可以在这里添加加入词书的逻辑
            promptAction.showToast({ message: '功能开发中...', duration: 1500 });
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildHeader() {
    Row() {
      Text('←')
        .fontSize(22)
        .fontColor(this.colors.GRAY_900)
        .accessibilityText('返回')
        .onClick(() => router.back())
        .padding({ right: 12, top: 6, bottom: 6 })

      Text('单词详情')
        .fontSize(DesignTokens.Typography.FONT_SIZE_LG)
        .fontWeight(DesignTokens.Typography.FONT_WEIGHT_BOLD)
        .fontColor(this.colors.GRAY_900)

      Blank()
    }
    .width('100%')
    .padding({ left: DesignTokens.Layout.CONTAINER_PADDING, right: DesignTokens.Layout.CONTAINER_PADDING, top: 12, bottom: 12 })
  }

  @Builder
  private buildLoadingView() {
    Column() {
      LoadingAnimation({
        type: LoadingType.PULSE,
        animSize: 60,
        color: this.colors.PRIMARY,
        text: '加载中...'
      })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private buildEmptyView() {
    Column() {
      Text('暂无数据')
        .fontSize(16)
        .fontColor(this.colors.GRAY_600)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private buildWordHeaderCard() {
    Column() {
      // Top row: Word and Status
      Row() {
        Column() {
          Row() {
            Text(this.word!.word)
              .fontSize(36)
              .fontWeight(FontWeight.Bold)
              .fontColor(DesignTokens.Colors.GRAY_900)

            // Pronunciation Button
            Stack() {
              if (this.isPlayingAudio) {
                LoadingAnimation({
                  type: LoadingType.PULSE,
                  animSize: 24,
                  color: DesignTokens.Colors.PRIMARY,
                  text: ''
                })
              } else {
                Image($r('sys.media.ohos_ic_public_sound'))
                  .width(24)
                  .height(24)
                  .fillColor(DesignTokens.Colors.PRIMARY)
              }
            }
            .width(40)
            .height(40)
            .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
            .borderRadius(20)
            .margin({ left: 12 })
            .onClick(() => this.playPronunciation())
          }

          if (this.word!.definition.phonetic.trim().length > 0) {
            Text(this.word!.definition.phonetic)
              .fontSize(16)
              .fontColor(DesignTokens.Colors.GRAY_600)
              .margin({ top: 8 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // Status Badge
        Column() {
          Text(this.getStatusText(this.word!.status))
            .fontSize(12)
            .fontColor(DesignTokens.Colors.WHITE)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.getStatusColor(this.word!.status))
            .padding({ left: 12, right: 12, top: 4, bottom: 4 })
            .borderRadius(12)

          if (this.word!.isLeech()) {
            Text(`顽固词 L${this.word!.leechLevel}`)
              .fontSize(12)
              .fontColor(DesignTokens.Colors.WHITE)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(DesignTokens.Colors.WARNING_DARK)
              .padding({ left: 12, right: 12, top: 4, bottom: 4 })
              .borderRadius(12)
              .margin({ top: 8 })
          }
        }
      }
      .width('100%')

      // Exam Tags & Frequency
      if (this.word!.definition.examTags.length > 0 || this.word!.definition.frequency > 0) {
        Row() {
          if (this.word!.definition.examTags.length > 0) {
            ForEach(this.word!.definition.examTags, (tag: string) => {
              Text(tag)
                .fontSize(11)
                .fontColor(DesignTokens.Colors.PRIMARY)
                .backgroundColor(DesignTokens.Colors.PRIMARY_LIGHTEST)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .borderRadius(4)
                .margin({ right: 6 })
            }, (tag: string) => tag)
          }

          Blank()

          if (this.word!.definition.frequency > 0) {
            Text(this.getFrequencyStars(this.word!.definition.frequency))
              .fontSize(14)
              .fontColor(DesignTokens.Colors.WARNING)
          }
        }
        .width('100%')
        .margin({ top: 12 })
      }

    }
    .width('100%')
    .padding(20)
    .backgroundColor(this.getStatusGradient(this.word!.status)[0])
    .borderRadius(16)
  }

  @Builder
  private buildQuickActions() {
    Row() {
      this.buildActionButton(this.isInLearningQueueState ? '取消队列' : '加入队列', $r('sys.media.ohos_ic_public_play'), () => {
        void this.toggleLearningQueue();
      })

      if (this.getWordStatus() === WordStatus.NEW) {
        this.buildActionButton('标记已见', 'S', () => {
          void this.markSeen();
        })
      } else if (this.getWordStatus() === WordStatus.LEARNING) {
        this.buildActionButton('撤销已见', '↺', () => {
          void this.unmarkSeen();
        })
      }

      this.buildActionButton(this.getWordStatus() === WordStatus.KNOWN ? '恢复学习' : '标记已知', '✓', () => {
        void this.toggleKnown();
      })

      if (this.externalDictEnabled) {
        this.buildActionButton('外部词典', '↗', () => {
          if (this.word) {
            this.openExternalDict(this.word.word);
          }
        })
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceEvenly)
    .margin({ top: 16 })
  }

  @Builder
  private buildActionButton(text: string, icon: Resource | string, onClick: () => void) {
    Column() {
      if (typeof icon === 'string') {
        Text(icon)
          .fontSize(20)
          .fontColor(DesignTokens.Colors.PRIMARY)
          .width(24)
          .height(24)
          .textAlign(TextAlign.Center)
          .margin({ bottom: 4 })
      } else {
        Image(icon as Resource)
          .width(24)
          .height(24)
          .fillColor(DesignTokens.Colors.PRIMARY)
          .margin({ bottom: 4 })
      }

      Text(text)
        .fontSize(12)
        .fontColor(DesignTokens.Colors.GRAY_700)
    }
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(DesignTokens.Colors.BACKGROUND_SECONDARY)
    .borderRadius(12)
    .onClick(onClick)
  }

  @Builder
  private buildMeaningSection() {
    Column() {
      // Section Header
      Row() {
        Text('释义')
          .fontSize(16)
          .fontColor(this.colors.GRAY_900)
          .fontWeight(FontWeight.Bold)

        Blank()

        Text(this.expandedSections.has('meaning') ? '收起' : '展开')
          .fontSize(13)
          .fontColor(this.colors.PRIMARY)
          .onClick(() => this.toggleSection('meaning'))
      }
      .width('100%')

      if (this.expandedSections.has('meaning')) {
        if (this.isDefinitionLoading) {
          Column() {
            LoadingAnimation({
              type: LoadingType.PULSE,
              animSize: 36,
              color: this.colors.PRIMARY,
              text: ''
            })
            Text(this.definitionStatusText)
              .fontSize(13)
              .fontColor(this.colors.GRAY_600)
              .margin({ top: 8 })
          }
          .margin({ top: 12 })
        } else if (this.word!.definition.commonMeanings.length === 0) {
          Text(this.definitionStatusText.length > 0 ? this.definitionStatusText : '暂无释义（可在设置中配置 API 后自动生成）')
            .fontSize(14)
            .fontColor(this.colors.GRAY_500)
            .margin({ top: 12 })
        } else {
          Column() {
            ForEach(this.word!.definition.commonMeanings, (m: WordMeaning, idx: number) => {
              Row() {
                Text(`${idx + 1}`)
                  .fontSize(12)
                  .fontColor(this.colors.WHITE)
                  .fontWeight(FontWeight.Bold)
                  .width(20)
                  .height(20)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(this.colors.PRIMARY)
                  .borderRadius(10)

                Text(m.pos)
                  .fontSize(13)
                  .fontColor(this.colors.PRIMARY)
                  .fontWeight(FontWeight.Medium)
                  .width(50)
                  .margin({ left: 8 })

                Text(m.cn)
                  .fontSize(14)
                  .fontColor(this.colors.GRAY_800)
                  .layoutWeight(1)
              }
              .width('100%')
              .margin({ top: idx === 0 ? 0 : 12 })
            }, (m: WordMeaning, idx: number) => `${idx}-${m.pos}`)
          }
          .width('100%')
          .margin({ top: 12 })
        }
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.colors.BACKGROUND_SECONDARY)
    .borderRadius(16)
    .margin({ top: 12 })
  }

  @Builder
  private buildPhrasesSection() {
    Column() {
      if (this.word!.definition.phrases.length > 0) {
        // Section Header
        Row() {
          Text('常用搭配')
            .fontSize(16)
            .fontColor(this.colors.GRAY_900)
            .fontWeight(FontWeight.Bold)

          Blank()

          Text(this.expandedSections.has('phrases') ? '收起' : '展开')
            .fontSize(13)
            .fontColor(this.colors.PRIMARY)
            .onClick(() => this.toggleSection('phrases'))
        }
        .width('100%')

        if (this.expandedSections.has('phrases')) {
          Column() {
            ForEach(this.word!.definition.phrases, (phrase: PhraseItem, idx: number) => {
              Column() {
                // 可点击的短语
                ClickableText({
                  text: phrase.phrase,
                  fontSize: 14,
                  fontColor: this.colors.GRAY_900,
                  wordColor: this.colors.PRIMARY,
                  fontWeight: FontWeight.Medium,
                  onWordClick: (word: string) => {
                    void this.onWordInTextClick(word, phrase.phrase);
                  }
                })

                Text(phrase.meaning)
                  .fontSize(13)
                  .fontColor(this.colors.GRAY_600)
                  .margin({ top: 4 })

                if (phrase.example.length > 0) {
                  // 可点击的例句
                  ClickableText({
                    text: phrase.example,
                    fontSize: 12,
                    fontColor: this.colors.GRAY_500,
                    wordColor: this.colors.PRIMARY,
                    onWordClick: (word: string) => {
                      void this.onWordInTextClick(word, phrase.example);
                    }
                  })
                    .margin({ top: 4 })
                }
              }
              .width('100%')
              .margin({ top: idx === 0 ? 0 : 12 })
              .padding(12)
              .backgroundColor(this.colors.SURFACE_PRIMARY)
              .borderRadius(8)
              .alignItems(HorizontalAlign.Start)
            }, (phrase: PhraseItem, idx: number) => `${idx}-${phrase.phrase}`)
          }
          .width('100%')
          .margin({ top: 12 })
        }
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.colors.BACKGROUND_SECONDARY)
    .borderRadius(16)
    .margin({ top: 12 })
  }

  @Builder
  private buildExamplesSection() {
    Column() {
      if (this.word!.definition.examples.length > 0) {
        // Section Header
        Row() {
          Text('例句')
            .fontSize(16)
            .fontColor(this.colors.GRAY_900)
            .fontWeight(FontWeight.Bold)

          Blank()

          Text(this.expandedSections.has('examples') ? '收起' : '展开')
            .fontSize(13)
            .fontColor(this.colors.PRIMARY)
            .onClick(() => this.toggleSection('examples'))
        }
        .width('100%')

        if (this.expandedSections.has('examples')) {
          Column() {
            ForEach(this.word!.definition.examples, (example: ExampleItem, idx: number) => {
              Column() {
                // 可点击的英文例句
                ClickableText({
                  text: example.sentence,
                  fontSize: 14,
                  fontColor: this.colors.GRAY_800,
                  wordColor: this.colors.PRIMARY,
                  fontWeight: FontWeight.Medium,
                  onWordClick: (word: string) => {
                    void this.onWordInTextClick(word, example.sentence);
                  }
                })

                Text(example.translation)
                  .fontSize(13)
                  .fontColor(this.colors.GRAY_600)
                  .margin({ top: 6 })
              }
              .width('100%')
              .margin({ top: idx === 0 ? 0 : 12 })
              .padding(12)
              .backgroundColor(this.colors.SURFACE_PRIMARY)
              .borderRadius(8)
              .alignItems(HorizontalAlign.Start)
            }, (example: ExampleItem, idx: number) => `${idx}-${example.sentence.slice(0, 20)}`)
          }
          .width('100%')
          .margin({ top: 12 })
        }
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.colors.BACKGROUND_SECONDARY)
    .borderRadius(16)
    .margin({ top: 12 })
  }

  @Builder
  private buildLearningProgressCard() {
    Column() {
      // Section Header
      Row() {
        Text('学习进度')
          .fontSize(16)
          .fontColor(this.colors.GRAY_900)
          .fontWeight(FontWeight.Bold)

        Blank()

        Text(this.expandedSections.has('progress') ? '收起' : '展开')
          .fontSize(13)
          .fontColor(this.colors.PRIMARY)
          .onClick(() => this.toggleSection('progress'))
      }
      .width('100%')

      if (this.expandedSections.has('progress')) {
        Column() {
          // Progress Info
          this.buildProgressItem('下次复习', this.getNextReviewLabel(this.word!));
          this.buildProgressItem('复习次数', `${this.word!.history.getReviewCount()} 次`);
          this.buildProgressItem('错误次数', `${this.word!.lapseCount} 次`);
        }
        .width('100%')
        .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.colors.BACKGROUND_SECONDARY)
    .borderRadius(16)
    .margin({ top: 12 })
  }

  @Builder
  private buildProgressRing() {
    Stack() {
      // Background circle
      Circle()
        .width(80)
        .height(80)
        .fill('transparent')
        .stroke(this.colors.GRAY_200)
        .strokeWidth(8)

      // Progress arc - 使用正确的圆周计算
      Circle()
        .width(80)
        .height(80)
        .fill('transparent')
        .stroke(this.getStatusColor(this.word!.status))
        .strokeWidth(8)
        .strokeLineCap(LineCapStyle.Round)
        .strokeDashArray([this.getProgressArcLength(), 251.2])

      Column() {
        Text(`${this.getMasteryPercentage()}%`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colors.GRAY_900)

        Text('掌握度')
          .fontSize(10)
          .fontColor(this.colors.GRAY_500)
      }
    }
    .width(80)
    .height(80)
  }

  private getMasteryPercentage(): number {
    if (this.word === null) {
      return 0;
    }
    // 根据 FSRS 稳定性计算掌握度，最大 100%
    const percentage = Math.min(100, Math.round(this.word.fsrsState.stability * 10));
    return percentage;
  }

  private getProgressArcLength(): number {
    // 圆周 = 2 * PI * r = 2 * 3.14159 * 40 ≈ 251.2
    const circumference = 251.2;
    const percentage = this.getMasteryPercentage() / 100;
    return circumference * percentage;
  }

  @Builder
  private buildProgressItem(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(this.colors.GRAY_600)

      Blank()

      Text(value)
        .fontSize(13)
        .fontColor(this.colors.GRAY_900)
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .margin({ top: 8 })
  }

  @Builder
  private buildFsrsBadge(label: string, value: string) {
    Column() {
      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colors.PRIMARY)

      Text(label)
        .fontSize(11)
        .fontColor(this.colors.GRAY_500)
        .margin({ top: 2 })
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(this.colors.SURFACE_PRIMARY)
    .borderRadius(8)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildTagsSection() {
    Column() {
      if (this.word!.tags.length > 0 || this.word!.errorTags.length > 0) {
        Text('标签')
          .fontSize(16)
          .fontColor(DesignTokens.Colors.GRAY_900)
          .fontWeight(FontWeight.Bold)

        Row() {
          if (this.word!.tags.length > 0) {
            ForEach(this.word!.tags, (tag: string) => {
              Text(tag)
                .fontSize(12)
                .fontColor(DesignTokens.Colors.PRIMARY)
                .backgroundColor(DesignTokens.Colors.PRIMARY_LIGHTEST)
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .borderRadius(12)
                .margin({ right: 8 })
            }, (tag: string) => tag)
          }

          if (this.word!.errorTags.length > 0) {
            ForEach(this.word!.errorTags, (tag: string) => {
              Text(tag)
                .fontSize(12)
                .fontColor(DesignTokens.Colors.ERROR)
                .backgroundColor(DesignTokens.Colors.ERROR_LIGHTEST)
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .borderRadius(12)
                .margin({ right: 8 })
            }, (tag: string) => tag)
          }
        }
        .width('100%')
        .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(DesignTokens.Colors.BACKGROUND_SECONDARY)
    .borderRadius(16)
    .margin({ top: 12 })
  }

  @Builder
  private buildAddToBookSection() {
    Column() {
      Row() {
        Column() {
          Text('加入单词本')
            .fontSize(16)
            .fontColor(DesignTokens.Colors.GRAY_900)
            .fontWeight(FontWeight.Bold)

          Text('把这个单词加入你的词书，方便集中复习。')
            .fontSize(13)
            .fontColor(DesignTokens.Colors.GRAY_600)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('加入')
          .type(ButtonType.Normal)
          .height(36)
          .fontSize(14)
          .fontColor(DesignTokens.Colors.WHITE)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(DesignTokens.Colors.PRIMARY)
          .borderRadius(18)
          .padding({ left: 20, right: 20 })
          .onClick(() => this.openAddToBookDialog())
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(DesignTokens.Colors.BACKGROUND_SECONDARY)
    .borderRadius(16)
    .margin({ top: 12, bottom: 24 })
  }

  @Builder
  private buildAddToBookFlowDialogs() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(DesignTokens.Colors.BLACK)
        .opacity(0.45)
        .onClick(() => this.dismissAddDialogs());

      if (this.showAddToBookDialog) {
        Column() {
          AddToBookDialog({
            visible: this.showAddToBookDialog,
            word: this.pendingAddWord,
            joinedBookIds: this.joinedBookIds,
            onDismiss: () => this.dismissAddDialogs(),
            onSelectBook: (result: AddToBookDialogResult) => this.handleAddDialogSelect(result),
            onRequestCreateBook: () => this.handleAddDialogRequestCreate()
          });
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center);
      }

      if (this.showCreateBookDialog) {
        Column() {
          CreateBookDialog({
            visible: this.showCreateBookDialog,
            onCancel: () => this.handleCreateBookCancel(),
            onCreate: (result: CreateBookDialogResult) => this.handleCreateBookSubmit(result)
          });
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center);
      }
    }
    .width('100%')
    .height('100%')
    .id('wordDetail_' + this.themeRefreshToken)
  }
}
