/**
 * cipher.ts - Core ChaCha20-Poly1305 encryption/decryption
 * Port of .servers/modules/security/cipher.py to TypeScript
 * Matches Python cryptography library behavior: salt is used as AAD
 *   Python: cipher.encrypt(nonce, plaintext, salt)  ← salt = AAD
 */

import crypto from 'crypto';

export const KEY_LEN = 32;
export const SALT_LEN = 32;
export const NONCE_LEN = 12;
export const PBKDF2_ITERATIONS = 200_000;

export function deriveKey(secret: string | Buffer, salt: Buffer): Buffer {
  // Python: hashlib.pbkdf2_hmac('sha512', secret.encode(), salt, 200000, dklen=32)
  const keyStr = Buffer.isBuffer(secret) ? secret.toString('utf8') : secret;
  return crypto.pbkdf2Sync(keyStr, salt, PBKDF2_ITERATIONS, KEY_LEN, 'sha512');
}

export interface CipherResult {
  ciphertext: Buffer;  // ciphertext || authTag (16 bytes)
  salt: Buffer;
  nonce: Buffer;
}

export function encrypt(plaintext: Buffer, secret: string | Buffer, salt?: Buffer): CipherResult {
  if (!salt) salt = crypto.randomBytes(SALT_LEN);
  const nonce = crypto.randomBytes(NONCE_LEN);
  const key = deriveKey(secret, salt);

  // ChaCha20-Poly1305 with salt as AAD (matches Python cryptography library)
  const cipher = crypto.createCipheriv('chacha20-poly1305', key, nonce);
  (cipher as any).setAAD(salt);  // salt = additional authenticated data
  const ciphertext = Buffer.concat([
    cipher.update(plaintext),
    cipher.final(),
    cipher.getAuthTag()  // 16-byte Poly1305 tag appended
  ]);

  return { ciphertext, salt, nonce };
}

export function decrypt(
  ciphertext: Buffer,
  secret: string,
  salt: Buffer,
  nonce: Buffer
): Buffer {
  const key = deriveKey(secret, salt);

  // ChaCha20-Poly1305 with salt as AAD (matches encrypt)
  const decipher = crypto.createDecipheriv('chacha20-poly1305', key, nonce);

  // Separate auth tag (last 16 bytes) from ciphertext
  const authTag = ciphertext.subarray(ciphertext.length - 16);
  const actualCt = ciphertext.subarray(0, ciphertext.length - 16);

  (decipher as any).setAAD(salt);  // must match what was set during encrypt
  decipher.setAuthTag(authTag);

  return Buffer.concat([
    decipher.update(actualCt),
    decipher.final()
  ]);
}
