import preferences from '@ohos.data.preferences';
import type common from '@ohos.app.ability.common';

export class CurrentBookStore {
  private static readonly PREFERENCES_NAME: string = 'vignette_storage';
  private static readonly KEY_CURRENT_BOOK_ID: string = 'current_book_id';
  private static instance: CurrentBookStore | null = null;

  private prefs: preferences.Preferences | null = null;
  private abilityContext: common.UIAbilityContext | null = null;
  private isInitialized: boolean = false;

  private constructor() {}

  static getInstance(): CurrentBookStore {
    if (CurrentBookStore.instance === null) {
      CurrentBookStore.instance = new CurrentBookStore();
    }
    return CurrentBookStore.instance;
  }

  injectContext(context: common.UIAbilityContext): void {
    this.abilityContext = context;
  }

  async initialize(): Promise<boolean> {
    if (this.isInitialized) {
      return true;
    }
    if (this.abilityContext === null) {
      return false;
    }
    try {
      this.prefs = await preferences.getPreferences(this.abilityContext, CurrentBookStore.PREFERENCES_NAME);
      this.isInitialized = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  async getCurrentBookId(): Promise<string> {
    if (!await this.ensureInitialized()) {
      return '';
    }
    if (this.prefs === null) {
      return '';
    }
    const value = await this.prefs.get(CurrentBookStore.KEY_CURRENT_BOOK_ID, '') as string;
    return value;
  }

  async setCurrentBookId(bookId: string): Promise<void> {
    const normalized = bookId.trim();
    if (normalized.length === 0) {
      return;
    }
    if (!await this.ensureInitialized()) {
      return;
    }
    if (this.prefs === null) {
      return;
    }
    await this.prefs.put(CurrentBookStore.KEY_CURRENT_BOOK_ID, normalized);
    await this.prefs.flush();
  }

  private async ensureInitialized(): Promise<boolean> {
    if (!this.isInitialized) {
      return await this.initialize();
    }
    return true;
  }
}

