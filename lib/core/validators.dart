import 'package:flutter/services.dart';

/// Shared input-trapping rules for the app: phone number, password, and
/// email fields all use the same shape everywhere they're entered
/// (Register, Profile Settings, Suppliers, Add Item's inline supplier
/// dialog) so a fix in one place doesn't drift from the others.

final RegExp _phoneRegExp = RegExp(r'^09\d{9}$');
final RegExp _emailRegExp = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

/// Digits-only, capped at 11 characters -- attach to any PH mobile number
/// [TextField]/[TextFormField] so invalid characters can't be typed at all.
final List<TextInputFormatter> phoneInputFormatters = [
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(11),
];

/// PH mobile format: exactly 11 digits starting with 09 (09XXXXXXXXX).
/// [required] controls whether an empty value fails validation -- some
/// contact-number fields are optional.
String? validatePhoneNumber(String? value, {bool required = false}) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return required ? 'Contact number is required' : null;
  }
  if (!_phoneRegExp.hasMatch(trimmed)) {
    return 'Enter a valid 11-digit number starting with 09';
  }
  return null;
}

/// xxx@xxxx.xxx shape.
String? validateEmail(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return 'Email is required';
  if (!_emailRegExp.hasMatch(trimmed)) return 'Enter a valid email address';
  return null;
}

/// At least 8 characters, with an uppercase letter, a lowercase letter, a
/// number, and a symbol.
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Password is required';
  }
  if (value.length < 8) {
    return 'Password must be at least 8 characters';
  }
  if (!RegExp(r'[A-Z]').hasMatch(value)) {
    return 'Password must contain at least 1 uppercase letter';
  }
  if (!RegExp(r'[a-z]').hasMatch(value)) {
    return 'Password must contain at least 1 lowercase letter';
  }
  if (!RegExp(r'[0-9]').hasMatch(value)) {
    return 'Password must contain at least 1 number';
  }
  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
    return 'Password must contain at least 1 symbol (!@#\$%^&* etc.)';
  }
  return null;
}
