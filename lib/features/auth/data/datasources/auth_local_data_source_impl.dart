import 'package:shared_preferences/shared_preferences.dart';

import 'auth_local_data_source.dart';

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl(this._prefs);

  final SharedPreferences _prefs;

  static const _rememberMeKey = 'auth_remember_me';

  @override
  bool getRememberMe() => _prefs.getBool(_rememberMeKey) ?? false;

  @override
  Future<void> setRememberMe(bool value) async {
    await _prefs.setBool(_rememberMeKey, value);
  }
}
