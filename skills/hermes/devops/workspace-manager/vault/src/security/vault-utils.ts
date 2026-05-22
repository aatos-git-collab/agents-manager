/**
 * vault-utils.ts - Shared encoding utilities
 */

export function base64Encode(data: Buffer): string {
  return data.toString('base64');
}

export function base64Decode(str: string): Buffer {
  return Buffer.from(str, 'base64');
}
