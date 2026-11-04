'use strict';

const {
  validateTitle,
  validateCompleted,
  isUuid,
  parsePagination,
} = require('../../src/tasks/validation');

describe('validateTitle', () => {
  test('trims a valid title', () => {
    expect(validateTitle('  Plan tests  ')).toBe('Plan tests');
  });

  test('rejects a blank title', () => {
    expect(() => validateTitle('   ')).toThrow('Enter a valid title.');
  });

  test('rejects a title longer than the limit', () => {
    expect(() => validateTitle('a'.repeat(121))).toThrow();
  });

  // Practice exercise (section 4): a valid title at the maximum allowed length.
  test('accepts a title at the maximum length of 120', () => {
    expect(validateTitle('a'.repeat(120))).toHaveLength(120);
  });

  // Section 8: boundary values and equivalence partitions.
  describe('boundary values and partitions', () => {
    test.each([
      ['empty', ''],
      ['whitespace only', ' '],
      ['just over maximum (121)', 'a'.repeat(121)],
    ])('rejects %s', (_label, input) => {
      expect(() => validateTitle(input)).toThrow(TypeError);
    });

    test.each([
      ['minimum valid length', 'a', 'a'],
      ['typical valid title', 'Plan tests', 'Plan tests'],
      ['maximum valid length (120)', 'b'.repeat(120), 'b'.repeat(120)],
    ])('accepts %s', (_label, input, expected) => {
      expect(validateTitle(input)).toBe(expected);
    });

    test('120 characters after trimming surrounding spaces is accepted', () => {
      expect(validateTitle(`  ${'c'.repeat(120)}  `)).toHaveLength(120);
    });

    test.each([
      ['number', 42],
      ['null', null],
      ['undefined', undefined],
      ['object', { title: 'x' }],
      ['array', ['x']],
      ['boolean', true],
    ])('rejects wrong type: %s', (_label, input) => {
      expect(() => validateTitle(input)).toThrow('Enter a valid title.');
    });
  });

  // Regression test for BUG-002 (found in the exploratory session, docs/04-sesion-exploratoria.md).
  test.each([
    ['zero-width space', '​'],
    ['zero-width joiner + spaces', ' ‍ ​ '],
    ['non-breaking spaces', '  '],
    ['byte order mark', '﻿'],
  ])('rejects a title with only invisible characters (%s)', (_label, input) => {
    expect(() => validateTitle(input)).toThrow('Enter a valid title.');
  });

  test('accepts emoji and accented characters', () => {
    expect(validateTitle('🎉 Fiesta ñ')).toBe('🎉 Fiesta ñ');
  });

  test('keeps injection-looking text as ordinary text', () => {
    expect(validateTitle("' OR '1'='1")).toBe("' OR '1'='1");
    expect(validateTitle('<script>alert(1)</script>')).toBe('<script>alert(1)</script>');
  });
});

describe('validateCompleted', () => {
  test('accepts booleans', () => {
    expect(validateCompleted(true)).toBe(true);
    expect(validateCompleted(false)).toBe(false);
  });

  test.each(['true', 1, 0, null])('rejects %p', (value) => {
    expect(() => validateCompleted(value)).toThrow(TypeError);
  });
});

describe('isUuid', () => {
  test('accepts a v4 uuid', () => {
    expect(isUuid('3f2b8c1e-9d4a-4b7e-8f21-0a1b2c3d4e5f')).toBe(true);
  });

  test.each(['123', 'not-a-uuid', '', "1' OR '1'='1", null])('rejects %p', (value) => {
    expect(isUuid(value)).toBe(false);
  });
});

describe('parsePagination', () => {
  test('uses defaults', () => {
    expect(parsePagination({})).toEqual({ limit: 50, offset: 0 });
  });

  test.each([
    [{ limit: '1' }, { limit: 1, offset: 0 }],
    [{ limit: '100', offset: '5' }, { limit: 100, offset: 5 }],
  ])('accepts boundary %p', (query, expected) => {
    expect(parsePagination(query)).toEqual(expected);
  });

  test.each([{ limit: '0' }, { limit: '101' }, { limit: 'abc' }, { offset: '-1' }, { limit: '2.5' }])(
    'rejects %p',
    (query) => {
      expect(() => parsePagination(query)).toThrow(TypeError);
    },
  );
});
