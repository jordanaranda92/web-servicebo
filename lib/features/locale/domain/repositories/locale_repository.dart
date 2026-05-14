import 'dart:ui';

/// Repository contract for locale/language preferences.
abstract class LocaleRepository {
  /// Retrieves the saved locale preference.
  /// Returns `null` if no preference has been saved.
  Future<Locale?> getLocale();

  /// Saves the user's locale preference.
  Future<void> saveLocale(Locale locale);

  /// Clears the saved locale preference.
  Future<void> clearLocale();
}
