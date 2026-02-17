import { WebDavCrypto } from './WebDavCrypto';

@Concurrent
export async function encryptPayload(plainText: string, password: string): Promise<string> {
  return WebDavCrypto.encryptUtf8Async(plainText, password);
}

@Concurrent
export async function decryptPayload(payloadJson: string, password: string): Promise<string> {
  return WebDavCrypto.decryptUtf8Async(payloadJson, password);
}

@Concurrent
export async function stringifyJson(obj: object): Promise<string> {
  return JSON.stringify(obj);
}

@Concurrent
export async function parseJson(json: string): Promise<object> {
  return JSON.parse(json) as object;
}
