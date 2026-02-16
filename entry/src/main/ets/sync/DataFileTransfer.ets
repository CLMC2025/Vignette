import { picker, fileIo as fs } from '@kit.CoreFileKit';
import type common from '@ohos.app.ability.common';
import { BusinessError } from '@ohos.base';
import { Base64Util } from './webdav/Base64Util';

interface ReadSyncOptions {
  offset: number;
  length: number;
}

export interface SaveJsonResult {
  ok: boolean;
  cancelled: boolean;
  error: string;
}

export interface ReadJsonResult {
  ok: boolean;
  cancelled: boolean;
  data: string;
  error: string;
}

interface ErrorInfo {
  code: number;
  message: string;
}

export class DataFileTransfer {
  private static getErrorInfo(e: Error | BusinessError | string | number | boolean): ErrorInfo {
    let code = -1;
    let message = String(e);
    if (e instanceof Error) {
      message = e.message;
    }
    const be = e as BusinessError;
    if (typeof be.code === 'number') {
      code = be.code;
    }
    if (typeof be.message === 'string') {
      message = be.message;
    }
    return { code, message };
  }

  static async saveJsonToPickedFile(context: common.UIAbilityContext, defaultFileName: string, jsonText: string): Promise<SaveJsonResult> {
    const documentSaveOptions = new picker.DocumentSaveOptions();
    documentSaveOptions.newFileNames = [defaultFileName];
    const documentPicker = new picker.DocumentViewPicker(context);

    let uris: Array<string> = [];
    try {
      uris = await documentPicker.save(documentSaveOptions);
    } catch (e) {
      const info = DataFileTransfer.getErrorInfo(e as Error | BusinessError | string | number | boolean);
      console.error(`[DataFileTransfer] picker.save failed code=${info.code} msg=${info.message}`);
      return { ok: false, cancelled: false, error: info.message };
    }
    if (uris.length <= 0) {
      return { ok: false, cancelled: true, error: '' };
    }

    const uri = uris[0];
    const uriScheme = uri.split(':', 1)[0] ?? '';

    let f: fs.File | null = null;
    try {
      f = fs.openSync(uri, fs.OpenMode.WRITE_ONLY);
    } catch (e) {
      const info = DataFileTransfer.getErrorInfo(e as Error | BusinessError | string | number | boolean);
      console.error(`[DataFileTransfer] openSync failed scheme=${uriScheme} code=${info.code} msg=${info.message}`);
      return { ok: false, cancelled: false, error: info.message };
    }

    try {
      try {
        fs.writeSync(f.fd, jsonText);
      } catch (e) {
        const info = DataFileTransfer.getErrorInfo(e as Error | BusinessError | string | number | boolean);
        console.error(`[DataFileTransfer] writeSync failed scheme=${uriScheme} code=${info.code} msg=${info.message}`);
        return { ok: false, cancelled: false, error: info.message };
      }
      return { ok: true, cancelled: false, error: '' };
    } finally {
      try {
        fs.closeSync(f);
      } catch (e) {
        const info = DataFileTransfer.getErrorInfo(e as Error | BusinessError | string | number | boolean);
        console.error(`[DataFileTransfer] closeSync failed scheme=${uriScheme} code=${info.code} msg=${info.message}`);
      }
    }
  }

  static async readJsonFromPickedFile(context: common.UIAbilityContext): Promise<ReadJsonResult> {
    const documentSelectOptions = new picker.DocumentSelectOptions();
    documentSelectOptions.maxSelectNumber = 1;
    const documentPicker = new picker.DocumentViewPicker(context);

    let uris: Array<string> = [];
    try {
      uris = await documentPicker.select(documentSelectOptions);
    } catch (e) {
      const info = DataFileTransfer.getErrorInfo(e as Error | BusinessError | string | number | boolean);
      console.error(`[DataFileTransfer] picker.select failed code=${info.code} msg=${info.message}`);
      return { ok: false, cancelled: false, data: '', error: info.message };
    }
    if (uris.length <= 0) {
      return { ok: false, cancelled: true, data: '', error: '' };
    }

    const uri = uris[0];
    const uriScheme = uri.split(':', 1)[0] ?? '';

    let f: fs.File | null = null;
    try {
      f = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    } catch (e) {
      const info = DataFileTransfer.getErrorInfo(e as Error | BusinessError | string | number | boolean);
      console.error(`[DataFileTransfer] openSync(read) failed scheme=${uriScheme} code=${info.code} msg=${info.message}`);
      return { ok: false, cancelled: false, data: '', error: info.message };
    }

    try {
      const chunkSize = 64 * 1024;
      const chunks: Uint8Array[] = [];
      let offset = 0;
      while (true) {
        const buf = new ArrayBuffer(chunkSize);
        const opts: ReadSyncOptions = { offset, length: chunkSize };
        let readBytes = 0;
        try {
          readBytes = fs.readSync(f.fd, buf, opts);
        } catch (e) {
          const info = DataFileTransfer.getErrorInfo(e as Error | BusinessError | string | number | boolean);
          console.error(`[DataFileTransfer] readSync failed scheme=${uriScheme} code=${info.code} msg=${info.message}`);
          return { ok: false, cancelled: false, data: '', error: info.message };
        }
        if (readBytes <= 0) {
          break;
        }
        chunks.push(new Uint8Array(buf, 0, readBytes));
        offset += readBytes;
        if (offset > 50 * 1024 * 1024) {
          return { ok: false, cancelled: false, data: '', error: 'file too large' };
        }
      }
      if (chunks.length <= 0) {
        return { ok: false, cancelled: false, data: '', error: 'empty file' };
      }
      const all = new Uint8Array(offset);
      let pos = 0;
      for (const c of chunks) {
        all.set(c, pos);
        pos += c.length;
      }
      return { ok: true, cancelled: false, data: Base64Util.utf8Decode(all), error: '' };
    } finally {
      try {
        fs.closeSync(f);
      } catch (e) {
        const info = DataFileTransfer.getErrorInfo(e as Error | BusinessError | string | number | boolean);
        console.error(`[DataFileTransfer] closeSync(read) failed scheme=${uriScheme} code=${info.code} msg=${info.message}`);
      }
    }
  }
}
