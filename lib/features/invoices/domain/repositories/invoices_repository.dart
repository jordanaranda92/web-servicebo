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
}
