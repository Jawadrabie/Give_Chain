import 'package:flutter/foundation.dart';

/// Notifies GoRouter when authentication changes inside the new API layer.
/// The original Login feature remains untouched; its navigation still causes
/// GoRouter to reevaluate the redirect against SharedPreferences.
class SessionController extends ChangeNotifier {
  SessionController._();

  static final SessionController instance = SessionController._();

  void notifyChanged() => notifyListeners();
}
