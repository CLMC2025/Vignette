import { DictionaryManager } from './DictionaryManager';

/**
 * TTS Player helper class
 */
export class TTSPlayer {
  private static instance: TTSPlayer | null = null;
  private dictionaryManager: DictionaryManager;

  private constructor() {
    this.dictionaryManager = DictionaryManager.getInstance();
  }

  static getInstance(): TTSPlayer {
    if (TTSPlayer.instance === null) {
      TTSPlayer.instance = new TTSPlayer();
    }
    return TTSPlayer.instance;
  }

  /**
   * Get the TTS URL for playback
   */
  getAudioUrl(word: string, usAccent: boolean = true): string {
    const type = usAccent ? 1 : 2;
    return this.dictionaryManager.getTTSUrl(word, type);
  }
}
