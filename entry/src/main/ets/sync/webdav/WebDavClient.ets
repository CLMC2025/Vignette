// =====================================================
// WebDavClient.ets - Minimal WebDAV client via @ohos.net.http
// Supports PUT/GET/PROPFIND with Basic Auth.
// =====================================================

import http from '@ohos.net.http';
import { Base64Util } from './Base64Util';

export interface WebDavResponse {
  statusCode: number;
  headers: Record<string, string>;
  body: string;
}

export class WebDavClient {
  private endpoint: string;
  private authHeader: string;

  constructor(endpoint: string, username: string, password: string) {
    this.endpoint = endpoint.replace(/\/+$/g, '');
    const raw = `${username}:${password}`;
    this.authHeader = `Basic ${Base64Util.encodeUtf8String(raw)}`;
  }

  async get(path: string): Promise<WebDavResponse> {
    return this.request('GET', path, {}, undefined);
  }

  async mkcol(path: string): Promise<WebDavResponse> {
    return this.request('MKCOL', path, {}, '');
  }

  async put(path: string, body: string, contentType: string = 'application/octet-stream'): Promise<WebDavResponse> {
    return this.request('PUT', path, { 'Content-Type': contentType }, body);
  }

  async propfind(path: string, depth: string = '0'): Promise<WebDavResponse> {
    const xml = `<?xml version="1.0" encoding="utf-8" ?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:getetag/>
    <d:getlastmodified/>
  </d:prop>
</d:propfind>`;

    return this.request(
      'PROPFIND',
      path,
      {
        'Depth': depth,
        'Content-Type': 'text/xml'
      },
      xml
    );
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

  private async request(method: string, path: string, headers: Record<string, string>, body?: string): Promise<WebDavResponse> {
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
      const res = await request.request(url, {
        method: method as http.RequestMethod,
        header: allHeaders,
        connectTimeout: 15000,
        readTimeout: 20000,
        extraData: body ?? ''
      });

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
      return { statusCode, headers: resHeaders, body: bodyStr };
    } catch (e) {
      request.destroy();
      const msg = e instanceof Error ? e.message : String(e);
      return { statusCode: 0, headers: {}, body: msg };
    }
  }
}
