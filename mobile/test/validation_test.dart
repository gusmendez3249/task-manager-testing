import 'package:flutter_test/flutter_test.dart';
import 'package:task_manager/validation.dart';

void main() {
  // Section 8: equivalence partitions and boundary values for the task title.
  group('validateTitle', () {
    final cases = <String, (String?, bool)>{
      'null': (null, false),
      'empty': ('', false),
      'whitespace only': (' ', false),
      'zero-width space only (BUG-002)': ('​', false),
      'minimum valid length': ('a', true),
      'typical valid title': ('Plan tests', true),
      'maximum valid length (120)': ('a' * 120, true),
      'just over maximum (121)': ('a' * 121, false),
      'emoji and accents': ('🎉 Fiesta ñ', true),
      'markup-like text is just text': ('<script>alert(1)</script>', true),
    };

    cases.forEach((label, data) {
      final (input, valid) = data;
      test('${valid ? 'accepts' : 'rejects'} $label', () {
        expect(validateTitle(input) == null, valid);
      });
    });
  });

  // Section 8 practice exercise: the password field. Synthetic values only.
  group('validatePassword', () {
    final cases = <String, (String, bool)>{
      'empty': ('', false),
      'just below minimum (7)': ('p' * 7, false),
      'minimum (8)': ('p' * 8, true),
      'typical': ('local-test-password', true),
      'maximum (72)': ('p' * 72, true),
      'over maximum (73)': ('p' * 73, false),
      '74 bytes of multi-byte characters': ('ñ' * 37, false),
    };

    cases.forEach((label, data) {
      final (input, valid) = data;
      test('${valid ? 'accepts' : 'rejects'} $label', () {
        expect(validatePassword(input) == null, valid);
      });
    });
  });

  group('validateEmail', () {
    test('accepts a synthetic test email', () {
      expect(validateEmail('tester@example.test'), isNull);
    });

    for (final input in ['', 'no-at-sign', 'a@b', 'a b@example.test']) {
      test('rejects "$input"', () {
        expect(validateEmail(input), 'Enter a valid email.');
      });
    }
  });
}
