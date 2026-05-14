abstract class SettingsLocalDataSource {
  // Page size
  int getPageSize();
  Future<void> savePageSize(int size);
}
