// =====================================================
// WebDavCrypto.ets - Password-based encryption for WebDAV sync
//
// Algorithm:
// - PBKDF2-HMAC-SHA256 to derive 64 bytes from password + salt.
//   - first 32 bytes: AES-256 key
//   - next 32 bytes: HMAC-SHA256 key
// - AES-256-CTR for encryption
// - HMAC-SHA256 over (salt || iv || ciphertext) for integrity
//
// Notes:
// - Uses cryptoFramework for secure random number generation.
// =====================================================

import { Base64Util } from './Base64Util';
import { sha256 } from './Sha256';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';

export class CryptoError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'CryptoError';
  }
}

export interface EncryptedPayload {
  v: number;            // version
  alg: string;          // algorithm
  salt: string;         // base64
  iv: string;           // base64
  ct: string;           // base64
  mac: string;          // base64
}

function concatBytes(a: Uint8Array, b: Uint8Array): Uint8Array {
  const out = new Uint8Array(a.length + b.length);
  out.set(a, 0);
  out.set(b, a.length);
  return out;
}

function concat3(a: Uint8Array, b: Uint8Array, c: Uint8Array): Uint8Array {
  return concatBytes(concatBytes(a, b), c);
}

function xorBytes(a: Uint8Array, b: Uint8Array): Uint8Array {
  const n = Math.min(a.length, b.length);
  const out = new Uint8Array(n);
  for (let i = 0; i < n; i++) {
    out[i] = (a[i] ^ b[i]) & 0xff;
  }
  return out;
}

function yieldToEventLoop(): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    setTimeout(() => {
      resolve();
    }, 0);
  });
}

function constantTimeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= (a[i] ^ b[i]);
  }
  return diff === 0;
}

async function randomBytes(len: number): Promise<Uint8Array> {
  try {
    // Use cryptoFramework for secure random number generation
    const rand = cryptoFramework.createRandom();
    const randomBlob = await rand.generateRandom(len);
    return new Uint8Array(randomBlob.data);
  } catch (e) {
    // Fallback: use Math.random() only if cryptoFramework fails
    console.warn('[WebDavCrypto] cryptoFramework failed, using fallback:', e);
    const out = new Uint8Array(len);
    for (let i = 0; i < len; i++) {
      out[i] = Math.floor(Math.random() * 256) & 0xff;
    }
    return out;
  }
}

function int32be(i: number): Uint8Array {
  const out = new Uint8Array(4);
  out[0] = (i >>> 24) & 0xff;
  out[1] = (i >>> 16) & 0xff;
  out[2] = (i >>> 8) & 0xff;
  out[3] = i & 0xff;
  return out;
}

// ==================== HMAC / PBKDF2 ====================

export function hmacSha256(key: Uint8Array, msg: Uint8Array): Uint8Array {
  const blockSize = 64;

  let k = key;
  if (k.length > blockSize) {
    k = sha256(k);
  }

  const keyBlock = new Uint8Array(blockSize);
  keyBlock.set(k, 0);

  const oKeyPad = new Uint8Array(blockSize);
  const iKeyPad = new Uint8Array(blockSize);
  for (let i = 0; i < blockSize; i++) {
    oKeyPad[i] = (keyBlock[i] ^ 0x5c) & 0xff;
    iKeyPad[i] = (keyBlock[i] ^ 0x36) & 0xff;
  }

  const inner = sha256(concatBytes(iKeyPad, msg));
  return sha256(concatBytes(oKeyPad, inner));
}

export function pbkdf2Sha256(password: Uint8Array, salt: Uint8Array, iterations: number, dkLen: number): Uint8Array {
  if (iterations <= 0) {
    throw new CryptoError('PBKDF2 iterations must be > 0');
  }
  if (dkLen <= 0) {
    throw new CryptoError('PBKDF2 dkLen must be > 0');
  }

  const hLen = 32;
  const l = Math.ceil(dkLen / hLen);
  const r = dkLen - (l - 1) * hLen;

  const out = new Uint8Array(dkLen);
  let outPos = 0;
  for (let i = 1; i <= l; i++) {
    const u1 = hmacSha256(password, concatBytes(salt, int32be(i)));
    let t = u1;
    let u = u1;
    for (let j = 2; j <= iterations; j++) {
      u = hmacSha256(password, u);
      t = xorBytes(t, u);
    }

    const take = (i === l) ? r : hLen;
    out.set(t.slice(0, take), outPos);
    outPos += take;
  }
  return out;
}

async function pbkdf2Sha256Async(password: Uint8Array, salt: Uint8Array, iterations: number, dkLen: number): Promise<Uint8Array> {
  if (iterations <= 0) {
    throw new CryptoError('PBKDF2 iterations must be > 0');
  }
  if (dkLen <= 0) {
    throw new CryptoError('PBKDF2 dkLen must be > 0');
  }

  const hLen = 32;
  const l = Math.ceil(dkLen / hLen);
  const r = dkLen - (l - 1) * hLen;

  const out = new Uint8Array(dkLen);
  let outPos = 0;
  for (let i = 1; i <= l; i++) {
    await yieldToEventLoop();
    const u1 = hmacSha256(password, concatBytes(salt, int32be(i)));
    let t = u1;
    let u = u1;
    for (let j = 2; j <= iterations; j++) {
      u = hmacSha256(password, u);
      t = xorBytes(t, u);
      if (j % 32 === 0) {
        await yieldToEventLoop();
      }
    }

    const take = (i === l) ? r : hLen;
    out.set(t.slice(0, take), outPos);
    outPos += take;
  }
  return out;
}

// ==================== AES-256 (CTR) ====================

// S-box table
const SBOX: number[] = [
  0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
  0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
  0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
  0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
  0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
  0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
  0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
  0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
  0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
  0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
  0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
  0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
  0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
  0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
  0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
  0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16
];

const RCON: number[] = [
  0x00,0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80,0x1b,0x36
];

function xtime(a: number): number {
  return ((a << 1) ^ (((a >>> 7) & 1) * 0x1b)) & 0xff;
}

function subBytes(state: Uint8Array): void {
  for (let i = 0; i < 16; i++) {
    state[i] = SBOX[state[i]] & 0xff;
  }
}

function shiftRows(state: Uint8Array): void {
  // state is column-major
  const t = state.slice(0);
  state[0]  = t[0];  state[4]  = t[4];  state[8]  = t[8];  state[12] = t[12];
  state[1]  = t[5];  state[5]  = t[9];  state[9]  = t[13]; state[13] = t[1];
  state[2]  = t[10]; state[6]  = t[14]; state[10] = t[2];  state[14] = t[6];
  state[3]  = t[15]; state[7]  = t[3];  state[11] = t[7];  state[15] = t[11];
}

function mixColumns(state: Uint8Array): void {
  for (let c = 0; c < 4; c++) {
    const i = c * 4;
    const a0 = state[i];
    const a1 = state[i + 1];
    const a2 = state[i + 2];
    const a3 = state[i + 3];

    const t = (a0 ^ a1 ^ a2 ^ a3) & 0xff;
    const u0 = a0;

    state[i]     = (a0 ^ t ^ xtime((a0 ^ a1) & 0xff)) & 0xff;
    state[i + 1] = (a1 ^ t ^ xtime((a1 ^ a2) & 0xff)) & 0xff;
    state[i + 2] = (a2 ^ t ^ xtime((a2 ^ a3) & 0xff)) & 0xff;
    state[i + 3] = (a3 ^ t ^ xtime((a3 ^ u0) & 0xff)) & 0xff;
  }
}

function addRoundKey(state: Uint8Array, roundKey: Uint8Array, offset: number): void {
  for (let i = 0; i < 16; i++) {
    state[i] = (state[i] ^ roundKey[offset + i]) & 0xff;
  }
}

function rotWord(w: Uint8Array): Uint8Array {
  return new Uint8Array([w[1], w[2], w[3], w[0]]);
}

function subWord(w: Uint8Array): Uint8Array {
  return new Uint8Array([SBOX[w[0]] & 0xff, SBOX[w[1]] & 0xff, SBOX[w[2]] & 0xff, SBOX[w[3]] & 0xff]);
}

function xorWord(a: Uint8Array, b: Uint8Array): Uint8Array {
  return new Uint8Array([
    (a[0] ^ b[0]) & 0xff,
    (a[1] ^ b[1]) & 0xff,
    (a[2] ^ b[2]) & 0xff,
    (a[3] ^ b[3]) & 0xff
  ]);
}

function expandKeyAes256(key: Uint8Array): Uint8Array {
  if (key.length !== 32) {
    throw new CryptoError('AES-256 key must be 32 bytes');
  }

  const Nk = 8;
  const Nr = 14;
  const Nb = 4;
  const wCount = Nb * (Nr + 1); // 60 words

  const w = new Array<Uint8Array>(wCount);
  for (let i = 0; i < Nk; i++) {
    w[i] = key.slice(i * 4, i * 4 + 4);
  }

  for (let i = Nk; i < wCount; i++) {
    let temp = w[i - 1];
    if (i % Nk === 0) {
      const rw = rotWord(temp);
      const sw = subWord(rw);
      const rc = new Uint8Array([RCON[i / Nk] & 0xff, 0x00, 0x00, 0x00]);
      temp = xorWord(sw, rc);
    } else if (i % Nk === 4) {
      temp = subWord(temp);
    }
    w[i] = xorWord(w[i - Nk], temp);
  }

  // Flatten to round keys bytes
  const out = new Uint8Array((Nr + 1) * 16);
  for (let r = 0; r <= Nr; r++) {
    for (let c = 0; c < 4; c++) {
      const word = w[r * 4 + c];
      out.set(word, r * 16 + c * 4);
    }
  }
  return out;
}

function encryptBlockAes256(input: Uint8Array, roundKeys: Uint8Array): Uint8Array {
  if (input.length !== 16) {
    throw new CryptoError('AES block must be 16 bytes');
  }
  const Nr = 14;
  const state = input.slice(0);

  addRoundKey(state, roundKeys, 0);

  for (let round = 1; round < Nr; round++) {
    subBytes(state);
    shiftRows(state);
    mixColumns(state);
    addRoundKey(state, roundKeys, round * 16);
  }

  subBytes(state);
  shiftRows(state);
  addRoundKey(state, roundKeys, Nr * 16);
  return state;
}

function incCounter(counter: Uint8Array): void {
  // increment as big-endian
  for (let i = 15; i >= 0; i--) {
    const v = (counter[i] + 1) & 0xff;
    counter[i] = v;
    if (v !== 0) break;
  }
}

export function aes256CtrCrypt(data: Uint8Array, key: Uint8Array, iv: Uint8Array): Uint8Array {
  if (iv.length !== 16) {
    throw new CryptoError('AES-CTR iv must be 16 bytes');
  }
  const roundKeys = expandKeyAes256(key);
  const out = new Uint8Array(data.length);
  const counter = iv.slice(0);

  let offset = 0;
  while (offset < data.length) {
    const ks = encryptBlockAes256(counter, roundKeys);
    const blockLen = Math.min(16, data.length - offset);
    for (let i = 0; i < blockLen; i++) {
      out[offset + i] = (data[offset + i] ^ ks[i]) & 0xff;
    }
    offset += blockLen;
    incCounter(counter);
  }
  return out;
}

async function aes256CtrCryptAsync(data: Uint8Array, key: Uint8Array, iv: Uint8Array): Promise<Uint8Array> {
  if (iv.length !== 16) {
    throw new CryptoError('AES-CTR iv must be 16 bytes');
  }
  const roundKeys = expandKeyAes256(key);
  const out = new Uint8Array(data.length);
  const counter = iv.slice(0);

  const chunkSize = 4096;
  const chunks = Math.ceil(data.length / chunkSize);
  
  for (let chunk = 0; chunk < chunks; chunk++) {
    const start = chunk * chunkSize;
    const end = Math.min(start + chunkSize, data.length);
    
    for (let offset = start; offset < end; ) {
      const ks = encryptBlockAes256(counter, roundKeys);
      const blockLen = Math.min(16, end - offset);
      for (let i = 0; i < blockLen; i++) {
        out[offset + i] = (data[offset + i] ^ ks[i]) & 0xff;
      }
      offset += blockLen;
      incCounter(counter);
    }
    
    if (chunk % 16 === 0) {
      console.info(`[WebDAV] crypto aes progress bytes=${end}/${data.length}`);
    }
    
    await new Promise<void>((resolve) => setTimeout(resolve, 5));
  }
  
  return out;
}

// ==================== Public APIs ====================

export class WebDavCrypto {
  static readonly ALG: string = 'PBKDF2-HMAC-SHA256/AES-256-CTR/HMAC-SHA256';
  static readonly VERSION: number = 1;

  static async encryptUtf8(plainText: string, password: string): Promise<string> {
    const plainBytes = Base64Util.utf8Encode(plainText);
    const pwdBytes = Base64Util.utf8Encode(password);
    const salt = await randomBytes(16);
    const dk = pbkdf2Sha256(pwdBytes, salt, 10000, 64);
    const keyEnc = dk.slice(0, 32);
    const keyMac = dk.slice(32, 64);
    const iv = await randomBytes(16);

    const ct = aes256CtrCrypt(plainBytes, keyEnc, iv);
    const macBytes = hmacSha256(keyMac, concat3(salt, iv, ct));

    const payload: EncryptedPayload = {
      v: WebDavCrypto.VERSION,
      alg: WebDavCrypto.ALG,
      salt: Base64Util.encode(salt),
      iv: Base64Util.encode(iv),
      ct: Base64Util.encode(ct),
      mac: Base64Util.encode(macBytes)
    };
    return JSON.stringify(payload);
  }

  static async encryptUtf8Async(plainText: string, password: string): Promise<string> {
    console.info('[WebDAV] crypto encrypt step=utf8');
    const plainBytes = await Base64Util.utf8EncodeAsync(plainText);
    const pwdBytes = Base64Util.utf8Encode(password);
    const salt = await randomBytes(16);
    console.info('[WebDAV] crypto encrypt step=pbkdf2');
    const dk = await pbkdf2Sha256Async(pwdBytes, salt, 10000, 64);
    const keyEnc = dk.slice(0, 32);
    const keyMac = dk.slice(32, 64);
    const iv = await randomBytes(16);

    console.info('[WebDAV] crypto encrypt step=aes');
    const ct = await aes256CtrCryptAsync(plainBytes, keyEnc, iv);
    const macBytes = hmacSha256(keyMac, concat3(salt, iv, ct));

    console.info('[WebDAV] crypto encrypt step=base64');
    const saltB64 = await Base64Util.encodeAsync(salt);
    const ivB64 = await Base64Util.encodeAsync(iv);
    const ctB64 = await Base64Util.encodeAsync(ct);
    const macB64 = await Base64Util.encodeAsync(macBytes);
    const payload: EncryptedPayload = {
      v: WebDavCrypto.VERSION,
      alg: WebDavCrypto.ALG,
      salt: saltB64,
      iv: ivB64,
      ct: ctB64,
      mac: macB64
    };
    return JSON.stringify(payload);
  }

  static async encryptUtf8Offloaded(plainText: string, password: string): Promise<string> {
    console.info('[WebDAV] crypto encrypt mode=async');
    return await WebDavCrypto.encryptUtf8Async(plainText, password);
  }

  static decryptUtf8(payloadJson: string, password: string): string {
    let payload: EncryptedPayload;
    try {
      payload = JSON.parse(payloadJson) as EncryptedPayload;
    } catch (e) {
      throw new CryptoError('Invalid encrypted payload JSON');
    }

    if (payload.v !== WebDavCrypto.VERSION) {
      throw new CryptoError(`Unsupported payload version: ${payload.v}`);
    }
    if (payload.alg !== WebDavCrypto.ALG) {
      throw new CryptoError('Unsupported encryption algorithm');
    }

    const salt = Base64Util.decode(payload.salt);
    const iv = Base64Util.decode(payload.iv);
    const ct = Base64Util.decode(payload.ct);
    const mac = Base64Util.decode(payload.mac);

    const pwdBytes = Base64Util.utf8Encode(password);
    const dk = pbkdf2Sha256(pwdBytes, salt, 10000, 64);
    const keyEnc = dk.slice(0, 32);
    const keyMac = dk.slice(32, 64);

    const expectedMac = hmacSha256(keyMac, concat3(salt, iv, ct));
    if (!constantTimeEqual(mac, expectedMac)) {
      throw new CryptoError('MAC verification failed');
    }

    const plainBytes = aes256CtrCrypt(ct, keyEnc, iv);
    return Base64Util.utf8Decode(plainBytes);
  }

  static async decryptUtf8Async(payloadJson: string, password: string): Promise<string> {
    let payload: EncryptedPayload;
    try {
      payload = JSON.parse(payloadJson) as EncryptedPayload;
    } catch (e) {
      throw new CryptoError('Invalid encrypted payload JSON');
    }

    if (payload.v !== WebDavCrypto.VERSION) {
      throw new CryptoError(`Unsupported payload version: ${payload.v}`);
    }
    if (payload.alg !== WebDavCrypto.ALG) {
      throw new CryptoError('Unsupported encryption algorithm');
    }

    const salt = Base64Util.decode(payload.salt);
    const iv = Base64Util.decode(payload.iv);
    const ct = Base64Util.decode(payload.ct);
    const mac = Base64Util.decode(payload.mac);

    const pwdBytes = Base64Util.utf8Encode(password);
    const dk = await pbkdf2Sha256Async(pwdBytes, salt, 10000, 64);
    const keyEnc = dk.slice(0, 32);
    const keyMac = dk.slice(32, 64);

    const expectedMac = hmacSha256(keyMac, concat3(salt, iv, ct));
    if (!constantTimeEqual(mac, expectedMac)) {
      throw new CryptoError('MAC verification failed');
    }

    const plainBytes = await aes256CtrCryptAsync(ct, keyEnc, iv);
    return Base64Util.utf8Decode(plainBytes);
  }

  static async decryptUtf8Offloaded(payloadJson: string, password: string): Promise<string> {
    console.info('[WebDAV] crypto decrypt mode=async');
    return await WebDavCrypto.decryptUtf8Async(payloadJson, password);
  }
}
