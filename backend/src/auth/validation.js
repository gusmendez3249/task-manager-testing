'use strict';

const EMAIL_MAX_LENGTH = 254;
const PASSWORD_MIN_LENGTH = 8;
// bcrypt only uses the first 72 bytes, so longer passwords would be silently truncated.
const PASSWORD_MAX_LENGTH = 72;

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/**
 * Normalizes and validates an email address.
 *
 * @param {unknown} value
 * @returns {string} Lower-cased, trimmed email.
 * @throws {TypeError}
 */
function validateEmail(value) {
  if (typeof value !== 'string') {
    throw new TypeError('Enter a valid email.');
  }
  const email = value.trim().toLowerCase();
  if (email.length === 0 || email.length > EMAIL_MAX_LENGTH || !EMAIL_PATTERN.test(email)) {
    throw new TypeError('Enter a valid email.');
  }
  return email;
}

/**
 * Validates a password. Passwords are never trimmed or logged.
 *
 * @param {unknown} value
 * @returns {string}
 * @throws {TypeError}
 */
function validatePassword(value) {
  if (typeof value !== 'string') {
    throw new TypeError('Password must be 8 to 72 characters.');
  }
  const bytes = Buffer.byteLength(value, 'utf8');
  if (value.length < PASSWORD_MIN_LENGTH || bytes > PASSWORD_MAX_LENGTH) {
    throw new TypeError('Password must be 8 to 72 characters.');
  }
  return value;
}

module.exports = {
  EMAIL_MAX_LENGTH,
  PASSWORD_MIN_LENGTH,
  PASSWORD_MAX_LENGTH,
  validateEmail,
  validatePassword,
};
