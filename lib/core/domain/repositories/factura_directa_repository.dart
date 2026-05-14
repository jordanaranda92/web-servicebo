import 'package:fpdart/fpdart.dart';

import '../../error/failure.dart';

abstract class FacturaDirectaRepository {
  Future<Either<Failure, List<Map<String, dynamic>>>> getContacts();

  Future<Either<Failure, Map<String, dynamic>>> getContactById(
    String contactId, {
    Map<String, dynamic>? queryParameters,
  });

  Future<Either<Failure, List<Map<String, dynamic>>>> getInvoicesByContact({
    required String contactUuid,
    required String minDate,
    required String maxDate,
    String? draft,
  });

  Future<Either<Failure, Map<String, dynamic>>> createInvoice(
    Map<String, dynamic> body,
  );
}
