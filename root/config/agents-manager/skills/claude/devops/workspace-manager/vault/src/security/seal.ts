/**
 * seal.ts - .seal file format (encrypted secret)
 * Format: MAGIC + VERSION + SALT + NONCE + CIPHERTEXT + HASH
 * Stores the SEAL encrypted with ROOT-SEAL
 * Port of .servers/modules/security/seal.py to TypeScript
 */

import crypto from 'crypto';
import { encrypt, decrypt, SALT_LEN, NONCE_LEN } from './cipher.js';

export const SEAL_MAGIC = Buffer.from([0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88]);
export const SEAL_VERSION = Buffer.from([0x01]);

export interface SealComponents {
  ciphertext: Buffer;
  salt: Buffer;
  nonce: Buffer;
}

function sha3_256(data: Buffer): Buffer {
  return crypto.createHash('sha3-256').update(data).digest();
}

export function pack(ciphertext: Buffer, salt: Buffer, nonce: Buffer): Buffer {
  // MAGIC(8) + VERSION(1) + SALT(32) + NONCE(12) + CIPHERTEXT + HASH(8)
  const header = Buffer.concat([SEAL_MAGIC, SEAL_VERSION, salt, nonce]);
  const hash = sha3_256(Buffer.concat([header, ciphertext])).subarray(0, 8);
  return Buffer.concat([header, ciphertext, hash]);
}

export function unpack(data: Buffer): SealComponents {
  // Verify MAGIC
  const magic = data.subarray(0, 8);
  if (!magic.equals(SEAL_MAGIC)) throw new Error('Not .seal format');

  // Verify VERSION
  const version = data[8];
  if (version !== SEAL_VERSION[0]) throw new Error('Unknown .seal version');

  let offset = 9;
  const salt = data.subarray(offset, offset + SALT_LEN);
  offset += SALT_LEN;
  const nonce = data.subarray(offset, offset + NONCE_LEN);
  offset += NONCE_LEN;
  const ciphertext = data.subarray(offset, data.length - 8);

  // Verify hash
  const storedHash = data.subarray(data.length - 8);
  const computedHash = sha3_256(data.subarray(0, data.length - 8)).subarray(0, 8);
  if (!storedHash.equals(computedHash)) throw new Error('Corrupted .seal');

  return { ciphertext, salt, nonce };
}

/**
 * Create a .seal binary: encrypt(seal: string | Buffer, rootSeal: string) → packed .seal bytes
 */
export function createSeal(seal: string | Buffer, rootSeal: string): Buffer {
  const { ciphertext, salt, nonce } = encrypt(Buffer.from(seal), rootSeal);
  return pack(ciphertext, salt, nonce);
}

/**
 * Extract SEAL string from .seal bytes using ROOT-SEAL
 */
export function extractSeal(sealBytes: Buffer, rootSeal: string): string {
  const { ciphertext, salt, nonce } = unpack(sealBytes);
  return decrypt(ciphertext, rootSeal, salt, nonce).toString('utf8');
}
