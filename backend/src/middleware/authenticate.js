'use strict';

const { verifyAccessToken } = require('../auth/tokens');
const { HttpError } = require('../errors');

/**
 * Requires a valid "Authorization: Bearer <access token>" header and sets req.userId.
 * The user id always comes from the verified token, never from the request body.
 */
function authenticate(req, _res, next) {
  const header = req.get('authorization') || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return next(new HttpError(401, 'Authentication required.'));
  }

  try {
    req.userId = verifyAccessToken(token);
    return next();
  } catch {
    return next(new HttpError(401, 'Invalid or expired token.'));
  }
}

module.exports = { authenticate };
