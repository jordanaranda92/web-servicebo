import 'dart:developer' as dev;

import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/domain/repositories/factura_directa_repository.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';

class CheckDuplicateInvoiceParams extends Equatable {
  final String contactUuid;
  final String date;

  const CheckDuplicateInvoiceParams({
    required this.contactUuid,
    required this.date,
  });

  @override
  List<Object?> get props => [contactUuid, date];
}

class CheckDuplicateInvoice extends UseCase<bool, CheckDuplicateInvoiceParams> {
  final FacturaDirectaRepository _fdRepo;

  CheckDuplicateInvoice(this._fdRepo);

  @override
  Future<Either<Failure, bool>> call(CheckDuplicateInvoiceParams params) async {
    dev.log(
      '[CheckDuplicateInvoice] checking for contact=${params.contactUuid}, '
      'date=${params.date}',
      name: 'Invoices',
    );

    final result = await _fdRepo.getInvoicesByContact(
      contactUuid: params.contactUuid,
      minDate: params.date,
      maxDate: params.date,
      draft: 'only',
    );

    return result.fold(
      (failure) => Left(failure),
      (items) => Right(items.isNotEmpty),
    );
  }
}
