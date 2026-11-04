'use strict';

const TITLE_MAX_LENGTH = 120;

/**
 * Trims and validates a task title.
 *
 * @param {unknown} value - Untrusted title input.
 * @returns {string} The validated title.
 * @throws {TypeError} When the title is not valid.
 */
function validateTitle(value) {
  if (typeof value !== 'string') {
    throw new TypeError('Enter a valid title.');
  }

  const title = value.trim();
  // BUG-002 fix: String.prototype.trim() keeps invisible format characters such as
  // U+200B (zero-width space), so a title made only of them looked blank in the app.
  const hasVisibleCharacter = title.replace(/[\p{Cf}\p{Z}\s]/gu, '').length > 0;
  if (!hasVisibleCharacter || title.length > TITLE_MAX_LENGTH) {
    throw new TypeError('Enter a valid title.');
  }

  return title;
}

/**
 * Validates the optional "completed" flag.
 *
 * @param {unknown} value
 * @returns {boolean}
 * @throws {TypeError} When the value is not a boolean.
 */
function validateCompleted(value) {
  if (typeof value !== 'boolean') {
    throw new TypeError('completed must be true or false.');
  }
  return value;
}

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/**
 * @param {unknown} value
 * @returns {boolean} Whether the value is a well-formed UUID.
 */
function isUuid(value) {
  return typeof value === 'string' && UUID_PATTERN.test(value);
}

/**
 * Parses pagination query parameters with safe bounds.
 *
 * @param {Record<string, unknown>} query
 * @returns {{ limit: number, offset: number }}
 * @throws {TypeError} When the values are not valid integers in range.
 */
function parsePagination(query) {
  const limit = query.limit === undefined ? 50 : Number(query.limit);
  const offset = query.offset === undefined ? 0 : Number(query.offset);

  if (!Number.isInteger(limit) || limit < 1 || limit > 100) {
    throw new TypeError('limit must be an integer between 1 and 100.');
  }
  if (!Number.isInteger(offset) || offset < 0 || offset > 100000) {
    throw new TypeError('offset must be an integer between 0 and 100000.');
  }
  return { limit, offset };
}

module.exports = {
  TITLE_MAX_LENGTH,
  validateTitle,
  validateCompleted,
  isUuid,
  parsePagination,
};
