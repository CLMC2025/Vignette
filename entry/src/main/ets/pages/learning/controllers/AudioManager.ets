import media from '@ohos.multimedia.media';
import fs from '@ohos.file.fs';
import promptAction from '@ohos.promptAction';
import { DictionaryManager } from '../../../manager/DictionaryManager';
import { SystemTtsManager } from '../../../utils/SystemTtsManager';
import { TtsAudioFetcher } from '../../../utils/TtsAudioFetcher';

export class ReadPageAudioManager {
  private avPlayer: media.AVPlayer | null = null;
  private currentTtsFile: fs.File | null = null;
  private avPlayerState: string = 'idle';
  private avPlayerLastError: string = '';
  private pronunciationToken: number = 0;
  private ttsInFlight: boolean = false;

  private dictionaryManager: DictionaryManager;
  private systemTtsManager: SystemTtsManager;
  private ttsAudioFetcher: TtsAudioFetcher;
  
  private onPlayingStateChange: (isPlaying: boolean) => void;

  constructor(
    dictionaryManager: DictionaryManager,
    systemTtsManager: SystemTtsManager,
    ttsAudioFetcher: TtsAudioFetcher,
    onPlayingStateChange: (isPlaying: boolean) => void
  ) {
    this.dictionaryManager = dictionaryManager;
    this.systemTtsManager = systemTtsManager;
    this.ttsAudioFetcher = ttsAudioFetcher;
    this.onPlayingStateChange = onPlayingStateChange;
  }

  public async init(): Promise<void> {
    await this.initAudioPlayer();
  }

  public async release(): Promise<void> {
    await this.stopCurrentAudio();
    if (this.avPlayer) {
      await this.avPlayer.release();
      this.avPlayer = null;
    }
  }

  public async playPronunciation(
    word: string,
    enableTTS: boolean,
    mode: string,
    preferSystemTts: boolean
  ): Promise<void> {
    // 1. Input validation and TTS switch check
    if (!word || word.length === 0) {
      console.warn('[ReadPageAudioManager] Cannot play pronunciation: empty word');
      return;
    }

    if (!enableTTS) {
      console.warn('[ReadPageAudioManager] TTS disabled in settings');
      promptAction.showToast({ message: '发音功能已关闭', duration: 1500 });
      return;
    }

    const token = ++this.pronunciationToken;
    this.ttsInFlight = true;

    try {
      if (token !== this.pronunciationToken) {
        return;
      }
      try {
        await this.stopCurrentAudio();
      } catch (e) {
        console.warn('[ReadPageAudioManager] Error stopping previous audio:', e);
      }
      if (token !== this.pronunciationToken) {
        return;
      }

      console.log('[ReadPageAudioManager] playPronunciation start:', word, 'mode:', mode, 'token:', token);
      
      // System TTS Mode
      if (mode === 'system') {
        console.log('[ReadPageAudioManager] Using system TTS');
        const ok = await this.systemTtsManager.speak(word, `${Date.now()}_${token}`);
        if (!ok && token === this.pronunciationToken) {
          promptAction.showToast({ message: '系统发音不可用，请稍后重试', duration: 2000 });
        }
        return;
      }
      
      // Auto Mode with System Preference
      if (mode === 'auto' && preferSystemTts) {
        const sysOk = await this.systemTtsManager.speak(word, `${Date.now()}_${token}`);
        if (sysOk) {
          return;
        }
      }

      // 3. Player check and init
      if (this.avPlayer === null) {
        console.log('[ReadPageAudioManager] Audio player not initialized, initializing...');
        try {
          await this.initAudioPlayer();
        } catch (e) {
          console.error('[ReadPageAudioManager] Failed to initialize audio player:', e);
          if (token === this.pronunciationToken) {
            promptAction.showToast({ message: '发音初始化失败', duration: 2000 });
          }
          return;
        }
      }
      if (token !== this.pronunciationToken) {
        return;
      }

      // 4. Retry mechanism
      const TTS_VOICE_TYPE_US = 1; // US pronunciation
      const TTS_VOICE_TYPE_UK = 2; // UK pronunciation (backup)
      const maxRetries = 3;
      let retryCount = 0;
      let useBackupVoice = false;
      let lastRemoteUrl: string = '';
      
      // Local flag to track if we should switch to system TTS for next attempts
      let currentPreferSystemTts = preferSystemTts;

      while (retryCount < maxRetries) {
        if (token !== this.pronunciationToken) {
          return;
        }
        try {
          console.log(`[ReadPageAudioManager] Attempting pronunciation playback (attempt ${retryCount + 1})`);

          // Switch source
          const voiceType = useBackupVoice ? TTS_VOICE_TYPE_UK : TTS_VOICE_TYPE_US;
          const url = this.dictionaryManager.getTTSUrl(word, voiceType);
          lastRemoteUrl = url;

          if (this.avPlayer !== null) {
            // Reset player
            if (retryCount > 0) {
              await this.avPlayer.reset();
            }

            const local = await this.ttsAudioFetcher.getOrFetchYoudaoTts(word, voiceType, url);
            console.log('[ReadPageAudioManager] TTS file ready:', local.fromCache ? 'cache' : 'network', local.filePath);
            if (token !== this.pronunciationToken) {
              return;
            }
            this.closeCurrentTtsFile();
            const file = fs.openSync(local.filePath, fs.OpenMode.READ_ONLY);
            this.currentTtsFile = file;
            this.avPlayer.url = `fd://${file.fd}`;

            await this.prepareWithTimeout(5000);
            if (token !== this.pronunciationToken) {
              return;
            }

            // Play
            await this.avPlayer.play();

            console.log(`[ReadPageAudioManager] Pronunciation playback successful for "${word}" (voice: ${voiceType})`);
            return; // Success
          }
        } catch (error) {
          retryCount++;
          console.error(`[ReadPageAudioManager] Pronunciation attempt ${retryCount} failed:`, error);
          const errText = error instanceof Error ? error.message : String(error);
          const errLower = errText.toLowerCase();
          const lastPlayerErrLower = this.avPlayerLastError.toLowerCase();
          
          const isNetworkOrParamError = (e: string) => 
            e.includes('not fd://') || e.includes('network address') || 
            e.includes('invalid parameter') || e.includes('invalid parameters');
            
          const isFormatError = (e: string) => 
            e.includes('unsupported format') || e.includes('unsupport container format type') || 
            e.includes('unsupport interface');

          if (isNetworkOrParamError(errLower) || isNetworkOrParamError(lastPlayerErrLower)) {
            if (lastRemoteUrl.length > 0) {
              const ok = await this.tryPlayRemoteUrlDirect(lastRemoteUrl, token);
              if (ok) {
                return;
              }
            }
            if (mode === 'auto' && token === this.pronunciationToken) {
              const sysOk = await this.systemTtsManager.speak(word, `${Date.now()}_${token}`);
              if (sysOk) {
                return;
              }
            }
            return;
          }

          if (isFormatError(errLower) || isFormatError(lastPlayerErrLower)) {
            if (lastRemoteUrl.length > 0) {
              const ok = await this.tryPlayRemoteUrlDirect(lastRemoteUrl, token);
              if (ok) {
                return;
              }
            }
            currentPreferSystemTts = true; // Suggest switching preference
            if (mode === 'auto' && token === this.pronunciationToken) {
              const sysOk = await this.systemTtsManager.speak(word, `${Date.now()}_${token}`);
              if (sysOk) {
                return;
              }
            }
            return;
          }

          if (errLower.includes('unsupport prepare operation') || errLower.includes('current state is not stopped or initialized')) {
            if (token === this.pronunciationToken) {
              console.warn('[ReadPageAudioManager] Detected AVPlayer state error, recreating player');
              try {
                await this.initAudioPlayer();
              } catch (e) {
                console.warn('[ReadPageAudioManager] Failed to recreate audio player after state error:', e);
              }
            }
          }

          // Switch to backup voice
          if (retryCount === Math.ceil(maxRetries / 2)) {
            useBackupVoice = true;
            console.log('[ReadPageAudioManager] Switching to backup voice type');
          }

          if (retryCount >= maxRetries) {
            console.error('[ReadPageAudioManager] All pronunciation attempts failed');
            this.onPlayingStateChange(false);
            this.closeCurrentTtsFile();

            if (lastRemoteUrl.length > 0) {
              const ok = await this.tryPlayRemoteUrlDirect(lastRemoteUrl, token);
              if (ok) {
                return;
              }
            }

            if (mode === 'auto') {
              const sysOk = await this.systemTtsManager.speak(word, `${Date.now()}_${token}`);
              if (sysOk) {
                return;
              }
            }

            const errorMessage = this.getPronunciationErrorMessage(error as Error);
            if (token === this.pronunciationToken) {
              promptAction.showToast({ message: errorMessage, duration: 2000 });
            }
            return;
          }

          if (errLower.includes('unsupport prepare operation') || errLower.includes('current state is not stopped or initialized')) {
            continue;
          }
          await new Promise<void>(resolve => setTimeout(resolve, 1000 * retryCount));
        }
      }
    } finally {
      if (token === this.pronunciationToken) {
        this.ttsInFlight = false;
      }
    }
  }

  public async stopCurrentAudio(): Promise<void> {
    if (this.avPlayer === null) {
      return;
    }
    try {
      await this.avPlayer.stop();
    } catch (e) {
      // ignore
    }
    try {
      await this.avPlayer.reset();
    } catch (e) {
      // ignore
    } finally {
      this.onPlayingStateChange(false);
      this.closeCurrentTtsFile();
    }
  }

  private async initAudioPlayer(): Promise<void> {
    if (this.avPlayer !== null) {
      await this.avPlayer.release();
    }
    this.avPlayer = await media.createAVPlayer();
    this.avPlayerState = 'idle';
    
    this.avPlayer.on('stateChange', (state: string, reason: media.StateChangeReason) => {
      console.log(`[ReadPageAudioManager] AVPlayer state change: ${this.avPlayerState} -> ${state}`);
      this.avPlayerState = state;
      switch (state) {
        case 'idle':
        case 'initialized':
        case 'stopped':
        case 'prepared':
        case 'paused':
        case 'completed':
          if (state === 'completed') {
            this.onPlayingStateChange(false);
          }
          break;
        case 'playing':
          this.onPlayingStateChange(true);
          break;
        case 'error':
          this.onPlayingStateChange(false);
          break;
      }
    });

    this.avPlayer.on('error', (err: Error) => {
      console.error('[ReadPageAudioManager] AVPlayer error:', err);
      this.avPlayerLastError = err.message;
      this.onPlayingStateChange(false);
    });
  }

  private async tryPlayRemoteUrlDirect(url: string, token: number): Promise<boolean> {
    if (this.avPlayer === null) {
      return false;
    }
    if (token !== this.pronunciationToken) {
      return false;
    }
    try {
      await this.avPlayer.reset();
      this.closeCurrentTtsFile();
      this.avPlayer.url = url;
      await this.prepareWithTimeout(5000);
      if (token !== this.pronunciationToken) {
        return false;
      }
      await this.avPlayer.play();
      return true;
    } catch (e) {
      return false;
    }
  }

  private closeCurrentTtsFile(): void {
    if (this.currentTtsFile !== null) {
      try {
        fs.closeSync(this.currentTtsFile);
      } catch (e) {
        console.warn('[ReadPageAudioManager] Failed to close TTS file:', e);
      }
      this.currentTtsFile = null;
    }
  }

  private async prepareWithTimeout(timeoutMs: number): Promise<void> {
    if (this.avPlayer === null) {
      throw new Error('Audio player not initialized');
    }
    if (this.avPlayerState !== 'initialized' && this.avPlayerState !== 'stopped' && this.avPlayerState !== 'prepared') {
      const ok = await this.waitForAvPlayerState(['initialized', 'stopped', 'prepared'], 1500);
      if (!ok) {
        throw new Error(`Audio player not ready for prepare: ${this.avPlayerState}`);
      }
    }
    const timeout = Math.max(1000, Math.min(15000, timeoutMs));
    const preparePromise: Promise<void> = this.avPlayer.prepare();
    const timeoutPromise = new Promise<void>((resolve, reject) => {
      const t = setTimeout(() => {
        clearTimeout(t);
        reject(new Error('Audio prepare timeout'));
      }, timeout);
    });
    await Promise.race([preparePromise, timeoutPromise]);
  }

  private async waitForAvPlayerState(expected: string[], timeoutMs: number): Promise<boolean> {
    if (this.avPlayer === null) {
      return false;
    }
    const timeout = Math.max(200, Math.min(5000, timeoutMs));
    for (const s of expected) {
      if (s === this.avPlayerState) {
        return true;
      }
    }

    const player = this.avPlayer;
    const result = await new Promise<boolean>((resolve) => {
      let finished = false;
      const handler = (state: string): void => {
        // Update local state tracking just in case
        if (player === this.avPlayer) {
           this.avPlayerState = state;
        }
        
        if (finished) {
          return;
        }
        for (const s of expected) {
          if (s === state) {
            finished = true;
            try {
              player.off('stateChange', handler);
            } catch (e) {
              // ignore
            }
            clearTimeout(timer);
            resolve(true);
            return;
          }
        }
      };
      const timer = setTimeout(() => {
        if (finished) {
          return;
        }
        finished = true;
        try {
          player.off('stateChange', handler);
        } catch (e) {
          // ignore
        }
        resolve(false);
      }, timeout);
      try {
        player.on('stateChange', handler);
      } catch (e) {
        clearTimeout(timer);
        resolve(false);
      }
    });
    return result;
  }

  private getPronunciationErrorMessage(error: Error): string {
    const errorMessage = error.message.toLowerCase();

    if (errorMessage.includes('network') || errorMessage.includes('timeout')) {
      return '网络连接异常，请检查网络后重试';
    } else if (errorMessage.includes('tts_non_audio_response') || errorMessage.includes('tts_no_context') || errorMessage.includes('tts_no_cache_dir')) {
      return '发音服务暂不可用，请稍后重试';
    } else if (errorMessage.includes('prepare') || errorMessage.includes('format')) {
      return '音频格式错误，请稍后重试';
    } else if (errorMessage.includes('initialize') || errorMessage.includes('init')) {
      return '音频播放器初始化失败，请重启应用';
    } else {
      return '发音播放失败，请稍后重试';
    }
  }
}
