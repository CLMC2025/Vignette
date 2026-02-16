// =====================================================
// Base64Util.ets - Minimal Base64 + UTF-8 helpers (ArkTS)
// =====================================================

const B64_CHARS: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

function yieldToEventLoop(): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    setTimeout(() => {
      resolve();
    }, 0);
  });
}

export class Base64Util {
  static encode(data: Uint8Array): string {
    let out = '';
    let i = 0;
    while (i < data.length) {
      const b0 = data[i++];
      const b1 = i < data.length ? data[i++] : -1;
      const b2 = i < data.length ? data[i++] : -1;

      const n0 = b0 >> 2;
      const n1 = ((b0 & 0x03) << 4) | (b1 >= 0 ? (b1 >> 4) : 0);
      const n2 = b1 >= 0 ? (((b1 & 0x0f) << 2) | (b2 >= 0 ? (b2 >> 6) : 0)) : 64;
      const n3 = b2 >= 0 ? (b2 & 0x3f) : 64;

      out += B64_CHARS.charAt(n0);
      out += B64_CHARS.charAt(n1);
      out += n2 === 64 ? '=' : B64_CHARS.charAt(n2);
      out += n3 === 64 ? '=' : B64_CHARS.charAt(n3);
    }
    return out;
  }

  static async encodeAsync(data: Uint8Array): Promise<string> {
    const parts: string[] = [];
    let i = 0;
    let blocks = 0;
    while (i < data.length) {
      const b0 = data[i++];
      const b1 = i < data.length ? data[i++] : -1;
      const b2 = i < data.length ? data[i++] : -1;

      const n0 = b0 >> 2;
      const n1 = ((b0 & 0x03) << 4) | (b1 >= 0 ? (b1 >> 4) : 0);
      const n2 = b1 >= 0 ? (((b1 & 0x0f) << 2) | (b2 >= 0 ? (b2 >> 6) : 0)) : 64;
      const n3 = b2 >= 0 ? (b2 & 0x3f) : 64;

      parts.push(B64_CHARS.charAt(n0));
      parts.push(B64_CHARS.charAt(n1));
      parts.push(n2 === 64 ? '=' : B64_CHARS.charAt(n2));
      parts.push(n3 === 64 ? '=' : B64_CHARS.charAt(n3));

      blocks++;
      if (blocks % 4096 === 0) {
        await yieldToEventLoop();
      }
    }
    return parts.join('');
  }

  static decode(b64: string): Uint8Array {
    const clean = b64.replace(/\s+/g, '');
    let padding = 0;
    if (clean.endsWith('==')) padding = 2;
    else if (clean.endsWith('=')) padding = 1;

    const outLen = Math.max(0, (clean.length * 3) / 4 - padding);
    const out = new Uint8Array(outLen);
    let outIdx = 0;

    let i = 0;
    while (i < clean.length) {
      const c0 = clean.charAt(i++);
      const c1 = clean.charAt(i++);
      const c2 = i < clean.length ? clean.charAt(i++) : 'A';
      const c3 = i < clean.length ? clean.charAt(i++) : 'A';

      const n0 = B64_CHARS.indexOf(c0);
      const n1 = B64_CHARS.indexOf(c1);
      const n2 = c2 === '=' ? -1 : B64_CHARS.indexOf(c2);
      const n3 = c3 === '=' ? -1 : B64_CHARS.indexOf(c3);

      if (n0 < 0 || n1 < 0) break;

      const b0 = (n0 << 2) | (n1 >> 4);
      if (outIdx < out.length) out[outIdx++] = b0;

      if (n2 >= 0) {
        const b1 = ((n1 & 0x0f) << 4) | (n2 >> 2);
        if (outIdx < out.length) out[outIdx++] = b1;
      }

      if (n3 >= 0 && n2 >= 0) {
        const b2 = ((n2 & 0x03) << 6) | n3;
        if (outIdx < out.length) out[outIdx++] = b2;
      }
    }
    return out;
  }

  static encodeUtf8String(str: string): string {
    return Base64Util.encode(Base64Util.utf8Encode(str));
  }

  static decodeUtf8String(b64: string): string {
    return Base64Util.utf8Decode(Base64Util.decode(b64));
  }

  static utf8Encode(str: string): Uint8Array {
    const bytes: number[] = [];
    for (let i = 0; i < str.length; i++) {
      let codePoint = str.charCodeAt(i);

      // Surrogate pairs
      if (codePoint >= 0xD800 && codePoint <= 0xDBFF && i + 1 < str.length) {
        const next = str.charCodeAt(i + 1);
        if (next >= 0xDC00 && next <= 0xDFFF) {
          const high = codePoint - 0xD800;
          const low = next - 0xDC00;
          codePoint = 0x10000 + ((high << 10) | low);
          i++;
        }
      }

      if (codePoint <= 0x7F) {
        bytes.push(codePoint);
      } else if (codePoint <= 0x7FF) {
        bytes.push(0xC0 | (codePoint >> 6));
        bytes.push(0x80 | (codePoint & 0x3F));
      } else if (codePoint <= 0xFFFF) {
        bytes.push(0xE0 | (codePoint >> 12));
        bytes.push(0x80 | ((codePoint >> 6) & 0x3F));
        bytes.push(0x80 | (codePoint & 0x3F));
      } else {
        bytes.push(0xF0 | (codePoint >> 18));
        bytes.push(0x80 | ((codePoint >> 12) & 0x3F));
        bytes.push(0x80 | ((codePoint >> 6) & 0x3F));
        bytes.push(0x80 | (codePoint & 0x3F));
      }
    }
    return new Uint8Array(bytes);
  }

  static async utf8EncodeAsync(str: string): Promise<Uint8Array> {
    const bytes: number[] = [];
    let step = 0;
    for (let i = 0; i < str.length; i++) {
      let codePoint = str.charCodeAt(i);

      if (codePoint >= 0xD800 && codePoint <= 0xDBFF && i + 1 < str.length) {
        const next = str.charCodeAt(i + 1);
        if (next >= 0xDC00 && next <= 0xDFFF) {
          const high = codePoint - 0xD800;
          const low = next - 0xDC00;
          codePoint = 0x10000 + ((high << 10) | low);
          i++;
        }
      }

      if (codePoint <= 0x7F) {
        bytes.push(codePoint);
      } else if (codePoint <= 0x7FF) {
        bytes.push(0xC0 | (codePoint >> 6));
        bytes.push(0x80 | (codePoint & 0x3F));
      } else if (codePoint <= 0xFFFF) {
        bytes.push(0xE0 | (codePoint >> 12));
        bytes.push(0x80 | ((codePoint >> 6) & 0x3F));
        bytes.push(0x80 | (codePoint & 0x3F));
      } else {
        bytes.push(0xF0 | (codePoint >> 18));
        bytes.push(0x80 | ((codePoint >> 12) & 0x3F));
        bytes.push(0x80 | ((codePoint >> 6) & 0x3F));
        bytes.push(0x80 | (codePoint & 0x3F));
      }

      step++;
      if (step % 8192 === 0) {
        await yieldToEventLoop();
      }
    }
    return new Uint8Array(bytes);
  }

  static utf8Decode(bytes: Uint8Array): string {
    let out = '';
    let i = 0;
    while (i < bytes.length) {
      const b0 = bytes[i++];
      if ((b0 & 0x80) === 0) {
        out += String.fromCharCode(b0);
        continue;
      }

      if ((b0 & 0xE0) === 0xC0) {
        const b1 = i < bytes.length ? bytes[i++] : 0;
        const cp = ((b0 & 0x1F) << 6) | (b1 & 0x3F);
        out += String.fromCharCode(cp);
        continue;
      }

      if ((b0 & 0xF0) === 0xE0) {
        const b1 = i < bytes.length ? bytes[i++] : 0;
        const b2 = i < bytes.length ? bytes[i++] : 0;
        const cp = ((b0 & 0x0F) << 12) | ((b1 & 0x3F) << 6) | (b2 & 0x3F);
        out += String.fromCharCode(cp);
        continue;
      }

      const b1 = i < bytes.length ? bytes[i++] : 0;
      const b2 = i < bytes.length ? bytes[i++] : 0;
      const b3 = i < bytes.length ? bytes[i++] : 0;
      let cp = ((b0 & 0x07) << 18) | ((b1 & 0x3F) << 12) | ((b2 & 0x3F) << 6) | (b3 & 0x3F);
      cp -= 0x10000;
      const high = 0xD800 + (cp >> 10);
      const low = 0xDC00 + (cp & 0x3FF);
      out += String.fromCharCode(high, low);
    }
    return out;
  }
}
