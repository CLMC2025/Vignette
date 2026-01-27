// =====================================================
// Sha256.ets - Pure ArkTS SHA-256 (Uint8Array -> Uint8Array)
// Minimal, dependency-free.
// =====================================================

function rotr(x: number, n: number): number {
  return (x >>> n) | (x << (32 - n));
}

function ch(x: number, y: number, z: number): number {
  return (x & y) ^ (~x & z);
}

function maj(x: number, y: number, z: number): number {
  return (x & y) ^ (x & z) ^ (y & z);
}

function bigSigma0(x: number): number {
  return rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22);
}

function bigSigma1(x: number): number {
  return rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25);
}

function smallSigma0(x: number): number {
  return rotr(x, 7) ^ rotr(x, 18) ^ (x >>> 3);
}

function smallSigma1(x: number): number {
  return rotr(x, 17) ^ rotr(x, 19) ^ (x >>> 10);
}

const K: number[] = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
];

const H0: number[] = [
  0x6a09e667,
  0xbb67ae85,
  0x3c6ef372,
  0xa54ff53a,
  0x510e527f,
  0x9b05688c,
  0x1f83d9ab,
  0x5be0cd19
];

function toUint32(x: number): number {
  return x >>> 0;
}

export function sha256(data: Uint8Array): Uint8Array {
  // Pre-processing (padding)
  const l = data.length;
  const bitLen = l * 8;

  // New length: l + 1 (0x80) + padding + 8 bytes length
  let withOne = l + 1;
  while ((withOne % 64) !== 56) {
    withOne++;
  }
  const totalLen = withOne + 8;
  const msg = new Uint8Array(totalLen);
  msg.set(data, 0);
  msg[l] = 0x80;

  // Append length in bits as big-endian 64-bit
  const hi = Math.floor(bitLen / 0x100000000);
  const lo = bitLen >>> 0;
  msg[totalLen - 8] = (hi >>> 24) & 0xff;
  msg[totalLen - 7] = (hi >>> 16) & 0xff;
  msg[totalLen - 6] = (hi >>> 8) & 0xff;
  msg[totalLen - 5] = hi & 0xff;
  msg[totalLen - 4] = (lo >>> 24) & 0xff;
  msg[totalLen - 3] = (lo >>> 16) & 0xff;
  msg[totalLen - 2] = (lo >>> 8) & 0xff;
  msg[totalLen - 1] = lo & 0xff;

  let h0 = H0[0];
  let h1 = H0[1];
  let h2 = H0[2];
  let h3 = H0[3];
  let h4 = H0[4];
  let h5 = H0[5];
  let h6 = H0[6];
  let h7 = H0[7];

  const w = new Array<number>(64);

  for (let offset = 0; offset < msg.length; offset += 64) {
    // Prepare message schedule
    for (let i = 0; i < 16; i++) {
      const idx = offset + i * 4;
      w[i] = (
        (msg[idx] << 24) |
        (msg[idx + 1] << 16) |
        (msg[idx + 2] << 8) |
        (msg[idx + 3])
      ) >>> 0;
    }
    for (let i = 16; i < 64; i++) {
      const s0 = smallSigma0(w[i - 15]);
      const s1 = smallSigma1(w[i - 2]);
      w[i] = toUint32(w[i - 16] + s0 + w[i - 7] + s1);
    }

    // Initialize working variables
    let a = h0;
    let b = h1;
    let c = h2;
    let d = h3;
    let e = h4;
    let f = h5;
    let g = h6;
    let h = h7;

    // Compression
    for (let i = 0; i < 64; i++) {
      const t1 = toUint32(h + bigSigma1(e) + ch(e, f, g) + K[i] + w[i]);
      const t2 = toUint32(bigSigma0(a) + maj(a, b, c));
      h = g;
      g = f;
      f = e;
      e = toUint32(d + t1);
      d = c;
      c = b;
      b = a;
      a = toUint32(t1 + t2);
    }

    // Add the compressed chunk to the current hash value
    h0 = toUint32(h0 + a);
    h1 = toUint32(h1 + b);
    h2 = toUint32(h2 + c);
    h3 = toUint32(h3 + d);
    h4 = toUint32(h4 + e);
    h5 = toUint32(h5 + f);
    h6 = toUint32(h6 + g);
    h7 = toUint32(h7 + h);
  }

  // Produce the final hash value (big-endian)
  const out = new Uint8Array(32);
  const hs = [h0, h1, h2, h3, h4, h5, h6, h7];
  for (let i = 0; i < hs.length; i++) {
    const v = hs[i];
    out[i * 4] = (v >>> 24) & 0xff;
    out[i * 4 + 1] = (v >>> 16) & 0xff;
    out[i * 4 + 2] = (v >>> 8) & 0xff;
    out[i * 4 + 3] = v & 0xff;
  }
  return out;
}
