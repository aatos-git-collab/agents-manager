/**
 * anc.ts - .anc file format (encrypted data)
 * Format: MAGIC + VERSION + SALT + NONCE + CIPHERTEXT + HASH
 * Port of .servers/modules/security/anc.py to TypeScript
 */

import { encrypt, decrypt, SALT_LEN, NONCE_LEN } from './cipher.js';

export const ANC_MAGIC = Buffer.from([0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x00, 0x11]);
export const ANC_VERSION = Buffer.from([0x03]);  // matches Python version

export interface AncComponents {
  ciphertext: Buffer;
  salt: Buffer;
  nonce: Buffer;
}

function sha3_256(data: Buffer): Buffer {
  const crypto = require('crypto') as typeof import('crypto');
  return crypto.createHash('sha3-256').update(data).digest();
}

export function pack(ciphertext: Buffer, salt: Buffer, nonce: Buffer): Buffer {
  // MAGIC(8) + VERSION(1) + SALT(32) + NONCE(12) + CIPHERTEXT + HASH(8)
  const header = Buffer.concat([ANC_MAGIC, ANC_VERSION, salt, nonce]);
  const hash = sha3_256(Buffer.concat([header, ciphertext])).subarray(0, 8);
  return Buffer.concat([header, ciphertext, hash]);
}

export function unpack(data: Buffer): AncComponents {
  // Verify MAGIC
  const magic = data.subarray(0, 8);
  if (!magic.equals(ANC_MAGIC)) throw new Error('Not .anc format');

  // Verify VERSION
  const version = data[8];
  if (version !== ANC_VERSION[0]) throw new Error('Unknown .anc version');

  let offset = 9;
  const salt = data.subarray(offset, offset + SALT_LEN);
  offset += SALT_LEN;
  const nonce = data.subarray(offset, offset + NONCE_LEN);
  offset += NONCE_LEN;
  const ciphertext = data.subarray(offset, data.length - 8);

  // Verify hash
  const storedHash = data.subarray(data.length - 8);
  const computedHash = sha3_256(data.subarray(0, data.length - 8)).subarray(0, 8);
  if (!storedHash.equals(computedHash)) throw new Error('Corrupted .anc');

  return { ciphertext, salt, nonce };
}

/**
 * Encrypt a file → .anc format
 */
export function encryptFile(inputPath: string, sealSecret: string, outputPath: string): string {
  const fs = require('fs') as typeof import('fs');
  const plaintext = fs.readFileSync(inputPath);
  const { ciphertext, salt, nonce } = encrypt(plaintext, sealSecret);
  const data = pack(ciphertext, salt, nonce);
  fs.writeFileSync(outputPath, data);
  return outputPath;
}

/**
 * Decrypt a .anc file
 */
export function decryptFile(inputPath: string, sealSecret: string, outputPath?: string): string {
  const fs = require('fs') as typeof import('fs');
  const data = fs.readFileSync(inputPath);
  const { ciphertext, salt, nonce } = unpack(data);
  const plaintext = decrypt(ciphertext, sealSecret, salt, nonce);

  if (!outputPath) {
    outputPath = inputPath.endsWith('.anc')
      ? inputPath.replace(/\.anc$/, '')
      : inputPath + '.dec';
  }
  fs.writeFileSync(outputPath, plaintext);
  return outputPath;
}
