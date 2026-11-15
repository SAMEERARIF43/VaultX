import type {
  DecryptedCredential,
  ReusedGroup,
  SecurityAuditReport,
  SecurityIssueItem,
} from '../types/vault';
import { evaluatePasswordStrength } from './passwordGenerator';

// Local offline corpus of common breached / dictionary passwords (never transmitted externally)
const KNOWN_COMPROMISED_PASSWORDS = new Set([
  '123456',
  '12345678',
  '123456789',
  '1234567890',
  'password',
  'password1',
  'password123',
  'p@ssword',
  'p@ssw0rd',
  'qwerty',
  'qwerty123',
  'qwertyuiop',
  'admin',
  'admin123',
  'administrator',
  'letmein',
  'welcome',
  'welcome123',
  'monkey',
  'dragon',
  'master',
  'football',
  'baseball',
  'iloveyou',
  'trustno1',
  'sunshine',
  'princess',
  'abc123',
  '111111',
  '000000',
  'passw0rd',
  'changeme',
  'secret',
  'login',
  'default',
  'guest',
  'root',
  'toor',
  'zaq12wsx',
  '1qaz2wsx',
  'test123',
  'vaultx',
  'superman',
  'batman',
]);

const STALE_PASSWORD_DAYS = 180;

/**
 * Performs a 100% client-side, zero-knowledge security audit across decrypted credentials.
 * No plaintext passwords ever leave the browser.
 */
export function runSecurityAudit(credentials: DecryptedCredential[]): SecurityAuditReport {
  const validCredentials = credentials.filter((c) => !c.decryptionError);
  const weakPasswords: SecurityIssueItem[] = [];
  const compromisedPasswords: SecurityIssueItem[] = [];
  const missingInfoAccounts: SecurityIssueItem[] = [];
  const passwordBuckets = new Map<string, DecryptedCredential[]>();

  const now = Date.now();
  const staleMs = STALE_PASSWORD_DAYS * 86400 * 1000;

  for (const cred of validCredentials) {
    const pw = cred.password || '';
    const lowerPw = pw.toLowerCase();

    // 1. Reused password grouping
    if (pw.length > 0) {
      const list = passwordBuckets.get(pw) || [];
      list.push(cred);
      passwordBuckets.set(pw, list);
    }

    // 2. Compromised / breached dictionary check
    const containsUsername =
      cred.username.length >= 4 &&
      lowerPw.includes(cred.username.split('@')[0].toLowerCase());

    if (KNOWN_COMPROMISED_PASSWORDS.has(lowerPw)) {
      compromisedPasswords.push({
        credential: cred,
        reason: 'Matches a widely leaked common password list.',
        severity: 'high',
      });
    } else if (containsUsername) {
      compromisedPasswords.push({
        credential: cred,
        reason: 'Password contains your username or email prefix.',
        severity: 'high',
      });
    }

    // 3. Weak password evaluation
    const strength = evaluatePasswordStrength(pw);
    if (strength.score <= 1) {
      weakPasswords.push({
        credential: cred,
        reason: `Critical/Weak (${strength.entropyBits} bits entropy, ${pw.length} chars).`,
        severity: 'high',
      });
    } else if (strength.score === 2) {
      weakPasswords.push({
        credential: cred,
        reason: `Fair strength (${strength.entropyBits} bits entropy) — increase length or complexity.`,
        severity: 'medium',
      });
    }

    // 4. Missing security information or stale rotation
    const missingReasons: string[] = [];
    if (!cred.url || cred.url.trim().length === 0) {
      missingReasons.push('Missing website URL (limits domain matching)');
    }
    if (!cred.username || cred.username.trim().length === 0) {
      missingReasons.push('Missing username or email');
    }
    if (now - cred.updatedAt.getTime() > staleMs) {
      missingReasons.push(`Not rotated in over ${STALE_PASSWORD_DAYS} days`);
    }
    if (missingReasons.length > 0) {
      missingInfoAccounts.push({
        credential: cred,
        reason: missingReasons.join(' · '),
        severity: 'low',
      });
    }
  }

  const reusedGroups: ReusedGroup[] = [];
  let reusedCount = 0;
  for (const [, group] of passwordBuckets) {
    if (group.length > 1) {
      reusedGroups.push({
        credentials: group,
        count: group.length,
      });
      reusedCount += group.length;
    }
  }

  // Overall vault hygiene score (transparent formula based on real issues)
  let healthPercentage = 100;
  if (validCredentials.length > 0) {
    const compromisedPenalty = compromisedPasswords.length * 25;
    const weakPenalty = weakPasswords.length * 14;
    const reusedPenalty = Math.max(0, reusedCount - reusedGroups.length) * 12;
    const missingPenalty = missingInfoAccounts.length * 4;
    const totalPenalty = compromisedPenalty + weakPenalty + reusedPenalty + missingPenalty;
    healthPercentage = Math.max(0, Math.min(100, Math.round(100 - totalPenalty / Math.max(1, validCredentials.length / 2))));
  }

  return {
    totalChecked: validCredentials.length,
    weakPasswords,
    reusedGroups,
    reusedCount,
    compromisedPasswords,
    missingInfoAccounts,
    healthPercentage,
  };
}
