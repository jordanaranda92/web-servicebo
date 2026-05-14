import 'dart:developer' as dev;

import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/data/datasources/factura_directa_api_data_source.dart';
import '../../../../core/error/exceptions.dart';
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
  final FacturaDirectaApiDataSource _fdApi;

  CheckDuplicateInvoice(this._fdApi);

  @override
  Future<Either<Failure, bool>> call(CheckDuplicateInvoiceParams params) async {
    dev.log(
      '[CheckDuplicateInvoice] checking for contact=${params.contactUuid}, '
      'date=${params.date}',
      name: 'Invoices',
    );

    try {
      final items = await _fdApi.getInvoicesByContact(
        contactUuid: params.contactUuid,
        minDate: params.date,
        maxDate: params.date,
        draft: 'only',
      );

      return Right(items.isNotEmpty);
    } on ServerException {
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } catch (e, st) {
      dev.log(
        '[CheckDuplicateInvoice] unexpected error: $e',
        name: 'Invoices',
        error: e,
        stackTrace: st,
      );
      return Left(InternalFailure());
    }
  }
}
