import { WebDavCrypto } from './WebDavCrypto';

@Concurrent
export async function encryptPayload(plainText: string, password: string): Promise<string> {
  return WebDavCrypto.encryptUtf8Async(plainText, password);
}

@Concurrent
export async function decryptPayload(payloadJson: string, password: string): Promise<string> {
  return WebDavCrypto.decryptUtf8Async(payloadJson, password);
}
