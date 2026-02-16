import { textToSpeech } from '@kit.CoreSpeechKit';

export class SystemTtsManager {
  private static instance: SystemTtsManager | null = null;
  private engine: textToSpeech.TextToSpeechEngine | null = null;
  private initInFlight: Promise<boolean> | null = null;

  private constructor() {}

  static getInstance(): SystemTtsManager {
    if (SystemTtsManager.instance === null) {
      SystemTtsManager.instance = new SystemTtsManager();
    }
    return SystemTtsManager.instance;
  }

  async ensureReady(): Promise<boolean> {
    if (!canIUse('SystemCapability.AI.TextToSpeech')) {
      return false;
    }
    if (this.engine !== null) {
      return true;
    }
    if (this.initInFlight !== null) {
      return await this.initInFlight;
    }
    this.initInFlight = this.createEngine();
    try {
      return await this.initInFlight;
    } finally {
      this.initInFlight = null;
    }
  }

  async speak(text: string, requestId: string): Promise<boolean> {
    const ready = await this.ensureReady();
    if (!ready || this.engine === null) {
      return false;
    }
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      return false;
    }
    try {
      if (this.engine.isBusy()) {
        this.engine.stop();
      }
      const params: textToSpeech.SpeakParams = { requestId: requestId };
      this.engine.speak(trimmed, params);
      return true;
    } catch (e) {
      return false;
    }
  }

  stop(): void {
    if (this.engine === null) {
      return;
    }
    try {
      this.engine.stop();
    } catch (e) {
      // ignore
    }
  }

  shutdown(): void {
    if (this.engine === null) {
      return;
    }
    try {
      this.engine.stop();
    } catch (e) {
      // ignore
    }
    try {
      this.engine.shutdown();
    } catch (e) {
      // ignore
    } finally {
      this.engine = null;
    }
  }

  private async createEngine(): Promise<boolean> {
    try {
      const params: textToSpeech.CreateEngineParams = {
        language: 'zh-CN',
        person: 0,
        online: 1
      };
      this.engine = await textToSpeech.createEngine(params);
      return this.engine !== null;
    } catch (e) {
      this.engine = null;
      return false;
    }
  }
}

