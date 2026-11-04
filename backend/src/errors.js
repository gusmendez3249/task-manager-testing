'use strict';

/** An error whose message is safe to show to API clients. */
class HttpError extends Error {
  /**
   * @param {number} status
   * @param {string} message
   */
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

/**
 * Runs a validator and converts its TypeError into a 400 response error.
 *
 * @template T
 * @param {() => T} fn
 * @returns {T}
 */
function badRequestOnTypeError(fn) {
  try {
    return fn();
  } catch (error) {
    if (error instanceof TypeError) {
      throw new HttpError(400, error.message);
    }
    throw error;
  }
}

module.exports = { HttpError, badRequestOnTypeError };
