// =====================================================
// WebDavClient.ets - Minimal WebDAV client via @ohos.net.http
// Supports PUT/GET/HEAD/DELETE with Basic Auth.
// =====================================================

import http from '@ohos.net.http';
import { Base64Util } from './Base64Util';
import { WebDavLogger } from '../../utils/WebDavLogger';
import type { IWebDavBackend } from './IWebDavBackend';

export interface WebDavResponse {
  statusCode: number;
  headers: Record<string, string>;
  body: string;
}

interface HttpErrorInfo {
  code: string;
  message: string;
}

export class WebDavClient implements IWebDavBackend {
  private endpoint: string;
  private authHeader: string;
  private static readonly MAX_REDIRECTS: number = 2;

  constructor(endpoint: string, username: string, password: string) {
    this.endpoint = endpoint.replace(/\/+$/g, '');
    const raw = `${username}:${password}`;
    this.authHeader = `Basic ${Base64Util.encodeUtf8String(raw)}`;
  }

  async get(path: string): Promise<WebDavResponse> {
    return this.request(http.RequestMethod.GET, path, {}, undefined);
  }

  async head(path: string): Promise<WebDavResponse> {
    return this.request(http.RequestMethod.HEAD, path, {}, undefined);
  }

  async put(path: string, body: string, contentType: string = 'application/octet-stream', extraHeaders: Record<string, string> = {}, ensureDir: boolean = true): Promise<WebDavResponse> {
    const headers: Record<string, string> = { 'Content-Type': contentType };
    Object.keys(extraHeaders).forEach((key: string) => {
      headers[key] = extraHeaders[key];
    });

    // 自动创建父目录
    if (ensureDir) {
      await this.ensureParentExists(path);
    }

    return this.request(http.RequestMethod.PUT, path, headers, body);
  }

  private async ensureParentExists(path: string): Promise<void> {
    const lastSlash = path.lastIndexOf('/');
    if (lastSlash <= 0) return;

    const parent = path.substring(0, lastSlash);
    if (parent.length === 0 || parent === '/') return;

    try {
      const headRes = await this.head(parent);
      if (headRes.statusCode === 404) {
        console.info(`[WebDavClient] Creating parent directory: ${parent}`);
        // 递归创建父目录
        await this.ensureParentExists(parent);
        await this.mkcol(parent);
      }
    } catch (e) {
      // 忽略检查错误，让 PUT 自己失败
      const errMsg = e instanceof Error ? e.message : String(e);
      console.warn(`[WebDavClient] ensureParentExists failed for ${parent}: ${errMsg} (will continue)`);
    }
  }

  async delete(path: string): Promise<WebDavResponse> {
    return this.request(http.RequestMethod.DELETE, path, {}, undefined);
  }

  async mkcol(path: string): Promise<WebDavResponse> {
    // 使用 PUT 创建目录（WebDAV 服务器通常支持 PUT 到目录路径）
    // 或者尝试 PUT 一个空文件到 .keep 文件来创建目录
    const keepFile = path.endsWith('/') ? `${path}.keep` : `${path}/.keep`;
    return this.request(http.RequestMethod.PUT, keepFile, { 'Content-Type': 'text/plain' }, '');
  }

  private buildUrl(path: string): string {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    if (!path.startsWith('/')) {
      path = `/${path}`;
    }
    return `${this.endpoint}${path}`;
  }

  private normalizeHeaders(headers: Record<string, string | string[] | number | undefined>): Record<string, string> {
    const out: Record<string, string> = {};
    for (const k of Object.keys(headers)) {
      const v = headers[k];
      if (v === undefined) continue;
      if (Array.isArray(v)) {
        out[k.toLowerCase()] = v.join(',');
      } else {
        out[k.toLowerCase()] = String(v);
      }
    }
    return out;
  }

  private async request(method: http.RequestMethod, path: string, headers: Record<string, string>, body?: string): Promise<WebDavResponse> {
    const requestId = this.newRequestId();
    return this.requestWithRedirect(method, path, headers, body, WebDavClient.MAX_REDIRECTS, requestId);
  }

  private async requestWithRedirect(
    method: http.RequestMethod,
    path: string,
    headers: Record<string, string>,
    body: string | undefined,
    redirectsLeft: number,
    requestId: string
  ): Promise<WebDavResponse> {
    const startMs = Date.now();
    const request = http.createHttp();

    const url = this.buildUrl(path);
    // Merge headers manually to avoid spread operator issues
    const allHeaders: Record<string, string> = {
      'Authorization': this.authHeader,
      'Accept': '*/*'
    };
    // Add custom headers
    Object.keys(headers).forEach((key: string) => {
      allHeaders[key] = headers[key];
    });

    try {
      const options: http.HttpRequestOptions = {
        method,
        header: allHeaders,
        connectTimeout: 15000,
        readTimeout: 20000
      };
      if (body !== undefined && (method === http.RequestMethod.PUT || method === http.RequestMethod.POST)) {
        options.extraData = body;
      }
      const res = await request.request(url, options);

      const statusCode = res.responseCode ?? 0;
      // Ensure res.header is treated as the correct type
      const resHeaders = this.normalizeHeaders(res.header as Record<string, string | string[] | number | undefined>);
      const raw = res.result;
      let bodyStr = '';
      if (typeof raw === 'string') {
        bodyStr = raw;
      } else if (raw instanceof ArrayBuffer) {
        // Decode as UTF-8-ish text (best-effort)
        const bytes = new Uint8Array(raw);
        bodyStr = '';
        for (const b of bytes) bodyStr += String.fromCharCode(b);
      } else {
        bodyStr = '';
      }

      request.destroy();
      const elapsed = Date.now() - startMs;
      if (redirectsLeft > 0 && (statusCode === 301 || statusCode === 302 || statusCode === 303 || statusCode === 307 || statusCode === 308)) {
        const location = resHeaders['location'] ?? '';
        WebDavLogger.infoRequest(requestId, String(method), url, statusCode, location, elapsed);
        if (location.length > 0) {
          return this.requestWithRedirect(method, location, headers, body, redirectsLeft - 1, requestId);
        }
      }
      WebDavLogger.infoRequest(requestId, String(method), url, statusCode, '', elapsed);
      return { statusCode, headers: resHeaders, body: bodyStr };
    } catch (e) {
      request.destroy();
      const err = this.buildHttpErrorInfo(e as (object | string | number | boolean | null | undefined));
      const elapsed = Date.now() - startMs;
      WebDavLogger.errorRequest(requestId, String(method), url, err.code, err.message, elapsed);
      return { statusCode: 0, headers: {}, body: err.message };
    }
  }

  private buildHttpErrorInfo(e: object | string | number | boolean | null | undefined): HttpErrorInfo {
    if (e === null || e === undefined) {
      return { code: '', message: 'unknown_error' };
    }
    if (typeof e === 'string' || typeof e === 'number' || typeof e === 'boolean') {
      return { code: '', message: String(e) };
    }
    if (e instanceof Error) {
      const name = e.name ?? '';
      const msg = e.message ?? '';
      if (name.length > 0 && msg.length > 0) {
        return { code: '', message: `${name}: ${msg}` };
      }
      if (msg.length > 0) {
        return { code: '', message: msg };
      }
      return { code: '', message: name.length > 0 ? name : 'error' };
    }

    const obj = e as Record<string, string | number | boolean | object | undefined | null>;
    const codeVal = obj['code'];
    const messageVal = obj['message'];
    const nameVal = obj['name'];

    const code = (typeof codeVal === 'string' || typeof codeVal === 'number') ? String(codeVal) : '';
    const message = typeof messageVal === 'string' ? messageVal : '';
    const name = typeof nameVal === 'string' ? nameVal : '';
    const raw = this.safeJsonStringify(obj);

    if (code.length > 0 || message.length > 0) {
      const title = name.length > 0 ? name : 'BusinessError';
      const core = `${title}: ${message.length > 0 ? message : 'unknown'}`;
      if (raw.length > 0) {
        return { code, message: `${core} raw=${raw}` };
      }
      return { code, message: core };
    }
    if (raw.length > 0) {
      return { code: '', message: raw };
    }
    return { code: '', message: 'unknown_error_object' };
  }

  private safeJsonStringify(obj: Record<string, string | number | boolean | object | undefined | null>): string {
    try {
      const s = JSON.stringify(obj);
      if (typeof s === 'string') {
        return s;
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  private newRequestId(): string {
    const rand = Math.random().toString(36).substring(2, 8);
    return `${Date.now()}_${rand}`;
  }
}
