// Shared TypeScript types for vault-api

export interface Seal {
  id?: number;
  sealName: string;
  agentId?: string;
  sealB64?: string;    // optional — omitted in list view
  perKeyB64?: string;  // base64(key bytes) — the actual encryption key for anc
  createdAt?: Date;
  isActive?: boolean;
  metadata?: Record<string, unknown>;
}

export interface Secret {
  id: string;
  name: string;
  secretType: SecretType;
  ancPath: string;
  ancB64?: string;
  sealB64?: string;   // base64(.seal) for two-factor decrypt
  sealName: string;
  createdAt?: Date;
  updatedAt?: Date;
  metadata?: Record<string, unknown>;
  creatorTag?: string;
}

export type SecretType = 'generic' | 'password' | 'api-key' | 'license';

export interface EncryptRequest {
  name: string;
  plaintext: string;
  sealName?: string;
  secretType?: SecretType;
  metadata?: Record<string, unknown>;
  creatorTag?: string;
}

export interface DecryptRequest {
  ancB64: string;
  sealB64: string;
}

export interface DecryptAgentRequest {
  secretId: string;
  perAgentSeal: string;
}

export interface ApiResponse<T = unknown> {
  data?: T;
  error?: string;
  message?: string;
}
