import 'dart:developer' as dev;

import 'package:fpdart/fpdart.dart';

import '../../domain/repositories/factura_directa_repository.dart';
import '../../error/exceptions.dart';
import '../../error/failure.dart';
import '../datasources/factura_directa_api_data_source.dart';

class FacturaDirectaRepositoryImpl implements FacturaDirectaRepository {
  FacturaDirectaRepositoryImpl(this._dataSource);

  final FacturaDirectaApiDataSource _dataSource;

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getContacts() async {
    try {
      final result = await _dataSource.getContacts();
      return Right(result);
    } on ServerException catch (e) {
      dev.log('[FdRepo] getContacts error: ${e.message}', name: 'FdRepo');
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } on Exception catch (e, st) {
      dev.log('[FdRepo] getContacts unexpected', error: e, stackTrace: st);
      return Left(InternalFailure());
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getContactById(
    String contactId, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final result = await _dataSource.getContactById(
        contactId,
        queryParameters: queryParameters,
      );
      return Right(result);
    } on ServerException catch (e) {
      dev.log('[FdRepo] getContactById error: ${e.message}', name: 'FdRepo');
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } on Exception catch (e, st) {
      dev.log('[FdRepo] getContactById unexpected', error: e, stackTrace: st);
      return Left(InternalFailure());
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getInvoicesByContact({
    required String contactUuid,
    required String minDate,
    required String maxDate,
    String? draft,
  }) async {
    try {
      final result = await _dataSource.getInvoicesByContact(
        contactUuid: contactUuid,
        minDate: minDate,
        maxDate: maxDate,
        draft: draft,
      );
      return Right(result);
    } on ServerException catch (e) {
      dev.log(
        '[FdRepo] getInvoicesByContact error: ${e.message}',
        name: 'FdRepo',
      );
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } on Exception catch (e, st) {
      dev.log(
        '[FdRepo] getInvoicesByContact unexpected',
        error: e,
        stackTrace: st,
      );
      return Left(InternalFailure());
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> createInvoice(
    Map<String, dynamic> body,
  ) async {
    try {
      final result = await _dataSource.createInvoice(body);
      return Right(result);
    } on ServerException catch (e) {
      dev.log('[FdRepo] createInvoice error: ${e.message}', name: 'FdRepo');
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } on Exception catch (e, st) {
      dev.log('[FdRepo] createInvoice unexpected', error: e, stackTrace: st);
      return Left(InternalFailure());
    }
  }
}
