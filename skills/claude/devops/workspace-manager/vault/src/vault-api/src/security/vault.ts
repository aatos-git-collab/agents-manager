/**
 * vault.ts - Two-factor vault operations
 * High-level API combining .anc and .seal
 * Port of .servers/modules/security/vault.py to TypeScript
 */

import { createSeal, extractSeal, SEAL_MAGIC, SEAL_VERSION } from './seal.js';
import { encrypt, decrypt } from './cipher.js';
import { ANC_MAGIC, ANC_VERSION, encryptFile, decryptFile, unpack } from './anc.js';
import crypto from 'crypto';

export { base64Encode, base64Decode } from './vault-utils.js';

export interface VaultEncryptResult {
  anc: string;   // base64-encoded .anc bytes
  seal: string;  // base64-encoded .seal bytes
}

export interface VaultEncryptFileResult {
  ancPath: string;
  sealPath: string;
  anc: string;
  seal: string;
}

/**
 * Two-factor encrypt a string.
 *   .anc  = encrypt(plaintext,  perSecretSeal)   → packed .anc
 *   .seal = encrypt(perSecretSeal, rootSeal)    → packed .seal
 * Returns: { anc: base64(.anc), seal: base64(.seal) }
 */
export function encryptString(
  text: string,
  perSecretSeal: string | Buffer,
  rootSeal: string
): VaultEncryptResult {
  // Step 1: encrypt plaintext with perSecretSeal → .anc
  const { ciphertext: ancCt, salt: ancSalt, nonce: ancNonce } = encrypt(
    Buffer.from(text, 'utf8'),
    perSecretSeal
  );

  // Pack .anc: MAGIC(8) + VERSION(1) + SALT(32) + NONCE(12) + CIPHERTEXT + HASH(8)
  const ancHeader = Buffer.concat([ANC_MAGIC, ANC_VERSION, ancSalt, ancNonce]);
  const ancHash = crypto.createHash('sha3-256')
    .update(Buffer.concat([ancHeader, ancCt]))
    .digest().subarray(0, 8);
  const ancData = Buffer.concat([ancHeader, ancCt, ancHash]);

  // Step 2: encrypt perSecretSeal (as bytes) with rootSeal → .seal
  const perSecretBytes = Buffer.isBuffer(perSecretSeal) ? perSecretSeal : Buffer.from(perSecretSeal, 'utf8');
  const { ciphertext: sealCt, salt: sealSalt, nonce: sealNonce } = encrypt(
    perSecretBytes,
    rootSeal
  );

  // Pack .seal: MAGIC(8) + VERSION(1) + SALT(32) + NONCE(12) + CIPHERTEXT + HASH(8)
  const sealHeader = Buffer.concat([SEAL_MAGIC, SEAL_VERSION, sealSalt, sealNonce]);
  const sealHash = crypto.createHash('sha3-256')
    .update(Buffer.concat([sealHeader, sealCt]))
    .digest().subarray(0, 8);
  const sealData = Buffer.concat([sealHeader, sealCt, sealHash]);

  return {
    anc:  ancData.toString('base64'),
    seal: sealData.toString('base64'),
  };
}

/**
 * Two-factor decrypt a string.
 *   1. Decode .seal → decrypt with rootSeal → perSecretSeal
 *   2. Decode .anc  → decrypt with perSecretSeal → plaintext
 */
export function decryptString(
  ancB64: string,
  sealB64: string,
  rootSeal: string
): string {
  const ancData  = Buffer.from(ancB64,  'base64');
  const sealData = Buffer.from(sealB64, 'base64');

  // Step 1: Extract perSecretSeal from .seal
  const perSecretSeal = extractSeal(sealData, rootSeal);

  // Step 2: Decrypt .anc
  const { ciphertext, salt, nonce } = unpack(ancData);
  const plaintext = decrypt(ciphertext, perSecretSeal, salt, nonce);

  return plaintext.toString('utf8');
}

/**
 * Two-factor encrypt a file.
 */
export function encryptFileVault(
  inputPath: string,
  perSecretSeal: string,
  rootSeal: string,
  outputDir?: string
): VaultEncryptFileResult {
  const fs   = require('fs') as typeof import('fs');
  const path = require('path') as typeof import('path');

  const inputName = path.basename(inputPath);
  const outDir = outputDir ? path.resolve(outputDir) : path.dirname(inputPath);
  fs.mkdirSync(outDir, { recursive: true });

  // .anc: encrypt file content with perSecretSeal
  const ancOut = path.join(outDir, `${inputName}.anc`);
  encryptFile(inputPath, perSecretSeal, ancOut);
  const ancBytes = fs.readFileSync(ancOut);

  // .seal: encrypt perSecretSeal with rootSeal
  const sealData = createSeal(perSecretSeal, rootSeal);
  const sealOut  = path.join(outDir, `${inputName}.seal`);
  fs.writeFileSync(sealOut, sealData);

  return {
    ancPath: ancOut,
    sealPath: sealOut,
    anc:  ancBytes.toString('base64'),
    seal: sealData.toString('base64'),
  };
}

/**
 * Two-factor decrypt a file.
 */
export function decryptFileVault(
  ancPath: string,
  sealPath: string,
  rootSeal: string,
  outputPath?: string
): string {
  const fs   = require('fs') as typeof import('fs');
  const path = require('path') as typeof import('path');

  const perSecretSeal = extractSeal(fs.readFileSync(sealPath), rootSeal);
  const outPath = outputPath
    ?? (ancPath.endsWith('.anc') ? ancPath.replace(/\.anc$/, '') : ancPath + '.dec');
  decryptFile(ancPath, perSecretSeal, outPath);
  return outPath;
}
