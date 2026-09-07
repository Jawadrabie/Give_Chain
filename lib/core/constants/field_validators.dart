/// Validators shared by the forms that capture the same field twice — sign-up
/// and profile editing — so the two cannot drift apart.
abstract final class FieldValidators {
  /// Digits, optionally with a leading `+`, and the separators people
  /// habitually type. Kept permissive on purpose: the field is optional and
  /// the backend stores it as free text, so this only catches obvious typos.
  static final _phone = RegExp(r'^\+?[\d\s()-]{7,20}$');

  /// Validates an optional phone number. Blank is always accepted — the field
  /// is optional on the API and older accounts have none.
  static String? phoneNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!_phone.hasMatch(text)) return 'أدخل رقم هاتف صحيح';
    // A separators-only string matches the pattern above but holds no number.
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return 'أدخل رقم هاتف صحيح';
    return null;
  }
}
