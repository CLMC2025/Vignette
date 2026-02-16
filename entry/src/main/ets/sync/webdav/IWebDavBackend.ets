import type { WebDavResponse } from './WebDavClient';

export interface IWebDavBackend {
  head(path: string): Promise<WebDavResponse>;
  get(path: string): Promise<WebDavResponse>;
  put(path: string, body: string, contentType?: string, extraHeaders?: Record<string, string>): Promise<WebDavResponse>;
  delete(path: string): Promise<WebDavResponse>;
}

