import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/invoice.dart';

abstract class InvoicesRepository {
  Future<Either<Failure, List<Invoice>>> getInvoices();
  Future<Either<Failure, List<Invoice>>> getInvoicesByDateRange({
    required String minDate,
    required String maxDate,
  });
  Future<Either<Failure, Invoice>> getInvoiceById(String id);

  /// Returns a map of FD contact UUID → display name (title or name).
  Future<Either<Failure, Map<String, String>>> getContactNames();

  /// Creates a provisional (draft) invoice via Factura Directa API.
  Future<Either<Failure, Invoice>> createInvoice(Map<String, dynamic> body);
}
