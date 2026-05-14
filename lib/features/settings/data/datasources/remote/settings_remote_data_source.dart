abstract class SettingsRemoteDataSource {
  Future<String?> getInvoiceSeries();
  Future<void> saveInvoiceSeries(String series);
}
