import type { DecryptedCredential } from '../types/vault';

/**
 * Future-ready Browser Extension Messaging & Domain Matching Contract (Manifest V3).
 *
 * Architectural boundary:
 * - Standard web origins (like this VaultX web app) cannot inspect DOM forms on third-party
 *   websites due to Browser Same-Origin Policy (SOP).
 * - A future Chrome/Edge Manifest V3 extension runs a content script on visited origins
 *   to detect `<input type="password">`, `autocomplete="new-password"`, and login forms,
 *   then communicates with a Background Service Worker that syncs with the user's
 *   encrypted Firestore vault and prompts explicit user confirmation before autofilling
 *   or saving credentials.
 */

export type ExtensionMessageType =
  | 'VAULTX_EXT_PING'
  | 'VAULTX_DETECTED_FORM'
  | 'VAULTX_REQUEST_MATCHING_CREDENTIALS'
  | 'VAULTX_AUTHORIZE_AUTOFILL'
  | 'VAULTX_OFFER_SAVE_CREDENTIAL';

export type DetectedFormKind = 'login' | 'registration' | 'password-change';

export interface ExtensionFormDetectionEvent {
  type: 'VAULTX_DETECTED_FORM';
  origin: string;
  pathname: string;
  formKind: DetectedFormKind;
  usernameFieldSelector?: string;
  passwordFieldSelector?: string;
  detectedAt: number;
}

export interface ExtensionAutofillAuthorization {
  type: 'VAULTX_AUTHORIZE_AUTOFILL';
  credentialId: string;
  targetOrigin: string;
  authorizedByUserGesture: boolean;
}

/**
 * Extracts normalized hostname/domain for strict origin matching before autofill suggestions.
 */
export function extractNormalizedHost(rawUrl: string): string | null {
  const trimmed = rawUrl.trim();
  if (!trimmed) return null;
  try {
    const withProtocol = /^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`;
    const parsed = new URL(withProtocol);
    return parsed.hostname.toLowerCase().replace(/^www\./, '');
  } catch {
    return null;
  }
}

/**
 * Finds vault credentials matching a given target origin (never matches wildcards or empty URLs).
 */
export function findMatchingCredentialsForOrigin(
  credentials: DecryptedCredential[],
  targetUrl: string
): DecryptedCredential[] {
  const targetHost = extractNormalizedHost(targetUrl);
  if (!targetHost) return [];

  return credentials.filter((cred) => {
    if (cred.decryptionError || !cred.url) return false;
    const credHost = extractNormalizedHost(cred.url);
    if (!credHost) return false;
    return credHost === targetHost || targetHost.endsWith(`.${credHost}`);
  });
}

export const EXTENSION_MANIFEST_V3_BLUEPRINT = {
  manifest_version: 3,
  name: 'VaultX Cloud Password Companion',
  permissions: ['storage', 'activeTab', 'scripting'],
  host_permissions: ['https://*/*'],
  architectureNotes: [
    'Content Script detects login, registration, and password-change forms via DOM heuristics.',
    'Origin normalization prevents subdomain spoofing and cross-origin credential leaks.',
    'Autofill requires explicit user click authorization and an unlocked session key.',
    'All encryption/decryption happens locally inside the extension service worker using Web Crypto + Argon2id.',
  ],
};
