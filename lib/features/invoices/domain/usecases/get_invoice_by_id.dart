import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/invoice.dart';
import '../repositories/invoices_repository.dart';

class GetInvoiceById extends UseCase<Invoice, String> {
  final InvoicesRepository _repository;

  GetInvoiceById(this._repository);

  @override
  Future<Either<Failure, Invoice>> call(String params) {
    return _repository.getInvoiceById(params);
  }
}
