'use strict';

const { validateEmail, validatePassword } = require('../../src/auth/validation');

// Section 8 practice exercise: boundary values for the password field.
// All values are synthetic; never test with a real password.
describe('validatePassword boundaries (8 to 72 characters)', () => {
  test.each([
    ['empty', ''],
    ['just below minimum (7)', 'p'.repeat(7)],
    ['just over maximum (73)', 'p'.repeat(73)],
    ['74 bytes using multi-byte characters', 'ñ'.repeat(37)],
  ])('rejects %s', (_label, input) => {
    expect(() => validatePassword(input)).toThrow('Password must be 8 to 72 characters.');
  });

  test.each([
    ['minimum length (8)', 'p'.repeat(8)],
    ['typical value', 'local-test-password'],
    ['maximum length (72)', 'p'.repeat(72)],
  ])('accepts %s', (_label, input) => {
    expect(validatePassword(input)).toBe(input);
  });

  test.each([12345678, null, undefined, {}])('rejects wrong type %p', (input) => {
    expect(() => validatePassword(input)).toThrow(TypeError);
  });

  test('does not trim passwords', () => {
    expect(validatePassword('  spaced pw  ')).toBe('  spaced pw  ');
  });
});

describe('validateEmail', () => {
  test('normalizes case and whitespace', () => {
    expect(validateEmail('  Tester@Example.TEST ')).toBe('tester@example.test');
  });

  test.each(['', 'no-at-sign', 'a@b', 'a b@example.test', `${'a'.repeat(250)}@example.test`, 42])(
    'rejects %p',
    (input) => {
      expect(() => validateEmail(input)).toThrow('Enter a valid email.');
    },
  );
});
