import 'dart:convert';

/// Maximum task title length, shared with the API (1 to 120 characters).
const int titleMaxLength = 120;

/// Password limits, shared with the API (bcrypt only uses the first 72 bytes).
const int passwordMinLength = 8;
const int passwordMaxBytes = 72;

// Invisible format characters (such as U+200B) and spaces. String.trim() does not
// remove all of them, which caused BUG-002 (a title that looks blank).
final RegExp _invisible = RegExp(r'[\p{Cf}\p{Z}\s]', unicode: true);
final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Returns an error message for an invalid task title, or `null` when valid.
String? validateTitle(String? value) {
  final title = (value ?? '').trim();
  if (title.replaceAll(_invisible, '').isEmpty) {
    return 'Enter a title.';
  }
  if (title.length > titleMaxLength) {
    return 'Use $titleMaxLength characters or fewer.';
  }
  return null;
}

/// Returns an error message for an invalid email, or `null` when valid.
String? validateEmail(String? value) {
  final email = (value ?? '').trim();
  if (email.isEmpty || email.length > 254 || !_email.hasMatch(email)) {
    return 'Enter a valid email.';
  }
  return null;
}

/// Returns an error message for an invalid password, or `null` when valid.
String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.length < passwordMinLength ||
      utf8.encode(password).length > passwordMaxBytes) {
    return 'Password must be 8 to 72 characters.';
  }
  return null;
}
