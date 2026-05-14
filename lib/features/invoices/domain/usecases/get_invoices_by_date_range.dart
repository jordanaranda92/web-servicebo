import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/invoice.dart';
import '../repositories/invoices_repository.dart';

class DateRangeParams extends Equatable {
  final String minDate;
  final String maxDate;

  const DateRangeParams({required this.minDate, required this.maxDate});

  @override
  List<Object?> get props => [minDate, maxDate];
}

class GetInvoicesByDateRange extends UseCase<List<Invoice>, DateRangeParams> {
  final InvoicesRepository _repository;

  GetInvoicesByDateRange(this._repository);

  @override
  Future<Either<Failure, List<Invoice>>> call(DateRangeParams params) {
    return _repository.getInvoicesByDateRange(
      minDate: params.minDate,
      maxDate: params.maxDate,
    );
  }
}
