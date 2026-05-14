abstract class FacturaDirectaApiDataSource {
  Future<List<Map<String, dynamic>>> getContacts();
  Future<List<Map<String, dynamic>>> getProducts();
  Future<List<Map<String, dynamic>>> getInvoices();
  Future<Map<String, dynamic>> getInvoiceById(String id);
  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> body);
  Future<List<Map<String, dynamic>>> getInvoicesByContact({
    required String contactUuid,
    required String minDate,
    required String maxDate,
    String? draft,
  });
  Future<List<Map<String, dynamic>>> getInvoicesByDateRange({
    required String minDate,
    required String maxDate,
  });
  Future<Map<String, dynamic>> getContactById(
    String contactId, {
    Map<String, dynamic>? queryParameters,
  });
}
