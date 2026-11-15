import type { PasswordGeneratorOptions, PasswordStrengthResult } from '../types/vault';

const UPPERCASE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const LOWERCASE = 'abcdefghijklmnopqrstuvwxyz';
const NUMBERS = '0123456789';
const SYMBOLS = '!@#$%^&*()-_=+[]{}|;:,.<>?';
const AMBIGUOUS = new Set(['0', 'O', 'o', '1', 'l', 'I', '|']);

function filterAmbiguous(chars: string, exclude: boolean): string {
  if (!exclude) return chars;
  return [...chars].filter((c) => !AMBIGUOUS.has(c)).join('');
}

/**
 * Returns a cryptographically uniform random integer in [0, maxExclusive)
 * using Web Crypto API rejection sampling to avoid modulo bias.
 */
function secureRandomInt(maxExclusive: number): number {
  if (maxExclusive <= 0) {
    throw new Error('maxExclusive must be positive');
  }
  const range = 0x100000000;
  const limit = Math.floor(range / maxExclusive) * maxExclusive;
  const buf = new Uint32Array(1);
  while (true) {
    crypto.getRandomValues(buf);
    if (buf[0] < limit) {
      return buf[0] % maxExclusive;
    }
  }
}

function secureShuffle<T>(items: T[]): T[] {
  const arr = [...items];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = secureRandomInt(i + 1);
    const tmp = arr[i];
    arr[i] = arr[j];
    arr[j] = tmp;
  }
  return arr;
}

export function generateSecurePassword(options: PasswordGeneratorOptions): string {
  const pools: string[] = [];
  if (options.uppercase) pools.push(filterAmbiguous(UPPERCASE, options.excludeAmbiguous));
  if (options.lowercase) pools.push(filterAmbiguous(LOWERCASE, options.excludeAmbiguous));
  if (options.numbers) pools.push(filterAmbiguous(NUMBERS, options.excludeAmbiguous));
  if (options.symbols) pools.push(filterAmbiguous(SYMBOLS, options.excludeAmbiguous));

  const activePools = pools.filter((p) => p.length > 0);
  if (activePools.length === 0) {
    throw new Error('Select at least one character type to generate a password.');
  }

  const length = Math.max(8, Math.min(128, options.length));
  const combined = activePools.join('');
  const chars: string[] = [];

  // Guarantee at least one character from each enabled pool
  for (const pool of activePools) {
    if (chars.length < length) {
      chars.push(pool[secureRandomInt(pool.length)]);
    }
  }

  while (chars.length < length) {
    chars.push(combined[secureRandomInt(combined.length)]);
  }

  return secureShuffle(chars).join('');
}

function formatCrackTime(seconds: number): string {
  if (seconds < 1) return 'Instant';
  if (seconds < 60) return `${Math.round(seconds)} seconds`;
  if (seconds < 3600) return `${Math.round(seconds / 60)} minutes`;
  if (seconds < 86400) return `${Math.round(seconds / 3600)} hours`;
  if (seconds < 86400 * 365) return `${Math.round(seconds / 86400)} days`;
  const years = seconds / (86400 * 365.25);
  if (years < 1000) return `${Math.round(years)} years`;
  if (years < 1_000_000) return `${Math.round(years / 1000)}k years`;
  if (years < 1_000_000_000) return `${Math.round(years / 1_000_000)}M years`;
  return 'Centuries+';
}

export function evaluatePasswordStrength(password: string): PasswordStrengthResult {
  if (!password) {
    return {
      score: 0,
      label: 'Critical',
      entropyBits: 0,
      crackTimeLabel: 'Instant',
      feedback: ['Enter a password to evaluate strength.'],
    };
  }

  const hasLower = /[a-z]/.test(password);
  const hasUpper = /[A-Z]/.test(password);
  const hasDigits = /[0-9]/.test(password);
  const hasSymbols = /[^a-zA-Z0-9]/.test(password);

  let poolSize = 0;
  if (hasLower) poolSize += 26;
  if (hasUpper) poolSize += 26;
  if (hasDigits) poolSize += 10;
  if (hasSymbols) poolSize += 32;
  if (poolSize === 0) poolSize = 26;

  // Penalize repeated characters or obvious sequences
  const uniqueChars = new Set(password).size;
  const uniquenessRatio = uniqueChars / password.length;
  const hasSequential = /(0123|1234|2345|3456|4567|5678|6789|abcd|bcde|qwer|asdf|password|admin)/i.test(password);

  let entropyBits = password.length * Math.log2(poolSize);
  if (uniquenessRatio < 0.5) entropyBits *= 0.65;
  if (hasSequential) entropyBits *= 0.7;
  entropyBits = Math.round(entropyBits);

  // Offline GPU cracking benchmark (~10^10 guesses/sec for fast hashes)
  const combinations = Math.pow(2, Math.min(entropyBits, 128));
  const secondsToCrack = combinations / (2 * 1e10);
  const crackTimeLabel = formatCrackTime(secondsToCrack);

  const feedback: string[] = [];
  if (password.length < 12) feedback.push('Use at least 12 characters (16+ recommended).');
  if (!hasUpper) feedback.push('Add uppercase letters.');
  if (!hasLower) feedback.push('Add lowercase letters.');
  if (!hasDigits) feedback.push('Add numeric digits.');
  if (!hasSymbols) feedback.push('Add special symbols.');
  if (hasSequential) feedback.push('Avoid dictionary words or keyboard sequences.');

  let score: 0 | 1 | 2 | 3 | 4 = 0;
  let label: PasswordStrengthResult['label'] = 'Critical';
  if (entropyBits >= 90 && password.length >= 14 && !hasSequential) {
    score = 4;
    label = 'Very Strong';
  } else if (entropyBits >= 68 && password.length >= 12) {
    score = 3;
    label = 'Strong';
  } else if (entropyBits >= 48 && password.length >= 8) {
    score = 2;
    label = 'Fair';
  } else if (entropyBits >= 28) {
    score = 1;
    label = 'Weak';
  }

  return {
    score,
    label,
    entropyBits,
    crackTimeLabel,
    feedback,
  };
}
