import http from '@ohos.net.http';
import fs from '@ohos.file.fs';
import type common from '@ohos.app.ability.common';

export interface TtsFetchResult {
  filePath: string;
  fromCache: boolean;
}

interface AbilityContextLike {
  cacheDir?: string;
}

export function isLikelyAudioResponse(statusCode: number, contentType: string, byteLength: number): boolean {
  if (statusCode !== 200) {
    return false;
  }
  const ct = contentType.trim().toLowerCase();
  if (!ct.startsWith('audio/')) {
    return false;
  }
  return byteLength >= 256;
}

export class TtsAudioFetcher {
  private static instance: TtsAudioFetcher | null = null;
  private abilityContext: common.UIAbilityContext | null = null;
  private memoryCache: Map<string, string> = new Map<string, string>();

  private constructor() {}

  static getInstance(): TtsAudioFetcher {
    if (TtsAudioFetcher.instance === null) {
      TtsAudioFetcher.instance = new TtsAudioFetcher();
    }
    return TtsAudioFetcher.instance;
  }

  injectContext(context: common.UIAbilityContext): void {
    this.abilityContext = context;
  }

  async getOrFetchYoudaoTts(word: string, voiceType: number, url: string): Promise<TtsFetchResult> {
    const normalizedWord = word.trim().toLowerCase();
    if (normalizedWord.length === 0) {
      throw new Error('tts_empty_word');
    }
    const key = this.buildKey(normalizedWord, voiceType);
    const cached = this.memoryCache.get(key);
    if (cached !== undefined && cached.length > 0) {
      if (this.existsSyncSafe(cached)) {
        const hit: TtsFetchResult = { filePath: cached, fromCache: true };
        return hit;
      }
      this.memoryCache.delete(key);
    }
    const filePath = await this.fetchToCacheFile(key, url);
    this.memoryCache.set(key, filePath);
    const result: TtsFetchResult = { filePath: filePath, fromCache: false };
    return result;
  }

  private buildKey(word: string, voiceType: number): string {
    const type = Math.max(0, Math.min(9, Math.floor(voiceType)));
    const hash = this.hashString(`${word}|${type}`);
    return `tts_${hash}_${type}`;
  }

  private getCacheDirPath(): string {
    if (this.abilityContext === null) {
      throw new Error('tts_no_context');
    }
    const dir = String((this.abilityContext as object as AbilityContextLike).cacheDir ?? '');
    if (dir.trim().length === 0) {
      throw new Error('tts_no_cache_dir');
    }
    return dir;
  }

  private async fetchToCacheFile(key: string, url: string): Promise<string> {
    const cacheDir = this.getCacheDirPath();
    const filePath = `${cacheDir}/${key}.mp3`;
    if (this.existsSyncSafe(filePath)) {
      return filePath;
    }

    const httpRequest = http.createHttp();
    const headers = {} as Record<string, string>;
    headers['Accept'] = 'audio/*,*/*';
    headers['User-Agent'] = 'Mozilla/5.0';
    const requestOptions = {
      method: http.RequestMethod.GET,
      header: headers,
      connectTimeout: 8000,
      readTimeout: 8000
    } as http.HttpRequestOptions;

    try {
      const response = await httpRequest.request(url, requestOptions);
      const statusCode = response.responseCode;
      const contentType = this.getHeaderValue(response.header as Record<string, string | string[] | number | undefined>, 'content-type');
      const bytes = response.result as ArrayBuffer;
      const byteLength = bytes instanceof ArrayBuffer ? bytes.byteLength : 0;

      if (!isLikelyAudioResponse(statusCode, contentType, byteLength)) {
        throw new Error(`tts_non_audio_response_${statusCode}_${contentType}_${byteLength}`);
      }

      this.writeFileFromArrayBuffer(filePath, bytes);
      return filePath;
    } finally {
      httpRequest.destroy();
    }
  }

  private getHeaderValue(
    headers: Record<string, string | string[] | number | undefined>,
    key: string
  ): string {
    const needle = key.toLowerCase();
    for (const k of Object.keys(headers)) {
      if (k.toLowerCase() !== needle) {
        continue;
      }
      const v = headers[k];
      if (v === undefined) {
        return '';
      }
      if (Array.isArray(v)) {
        return v.join(',');
      }
      return String(v);
    }
    return '';
  }

  private writeFileFromArrayBuffer(filePath: string, bytes: ArrayBuffer): void {
    const u8 = new Uint8Array(bytes);
    const fd = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(fd.fd, u8);
    } finally {
      fs.closeSync(fd);
    }
  }

  private existsSyncSafe(filePath: string): boolean {
    try {
      return fs.accessSync(filePath);
    } catch (e) {
      return false;
    }
  }

  private hashString(value: string): string {
    let hash = 5381;
    for (let i = 0; i < value.length; i++) {
      hash = ((hash << 5) + hash) + value.charCodeAt(i);
      hash = hash & 0x7fffffff;
    }
    return hash.toString(16);
  }
}

