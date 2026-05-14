import 'package:shared_preferences/shared_preferences.dart';

import 'settings_local_data_source.dart';

class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {
  SettingsLocalDataSourceImpl(this._prefs);

  final SharedPreferences _prefs;

  static const _pageSizeKey = 'settings_page_size';
  static const _defaultPageSize = 20;

  // Page size

  @override
  int getPageSize() => _prefs.getInt(_pageSizeKey) ?? _defaultPageSize;

  @override
  Future<void> savePageSize(int size) async {
    await _prefs.setInt(_pageSizeKey, size);
  }
}
