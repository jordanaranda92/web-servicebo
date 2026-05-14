import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/locale_repository.dart';

/// Implementation of [LocaleRepository] using SharedPreferences.
class LocaleRepositoryImpl implements LocaleRepository {
  LocaleRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;
  static const String _localeKey = 'app_locale';

  @override
  Future<Locale?> getLocale() async {
    final localeCode = _prefs.getString(_localeKey);
    if (localeCode == null) return null;

    final parts = localeCode.split('_');
    return Locale(parts[0], parts.length > 1 ? parts[1] : null);
  }

  @override
  Future<void> saveLocale(Locale locale) async {
    final localeCode = locale.countryCode != null
        ? '${locale.languageCode}_${locale.countryCode}'
        : locale.languageCode;
    await _prefs.setString(_localeKey, localeCode);
  }

  @override
  Future<void> clearLocale() async {
    await _prefs.remove(_localeKey);
  }
}
