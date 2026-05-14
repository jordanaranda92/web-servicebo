import 'dart:developer' as dev;

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/shipping_method.dart';
import '../../domain/repositories/shipping_methods_repository.dart';
import '../datasources/shipping_method_firestore_data_source.dart';

class ShippingMethodsRepositoryImpl implements ShippingMethodsRepository {
  final ShippingMethodFirestoreDataSource _dataSource;

  ShippingMethodsRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, List<ShippingMethod>>> getShippingMethods() async {
    dev.log('[ShippingMethodsRepo] getShippingMethods()', name: 'Shipping');
    try {
      final methods = await _dataSource.getAll();
      methods.sort((a, b) => a.name.compareTo(b.name));
      return Right(methods);
    } on ServerException catch (e) {
      dev.log(
        '[ShippingMethodsRepo] ServerException: ${e.message}',
        name: 'Shipping',
      );
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } on Exception catch (e, st) {
      dev.log(
        '[ShippingMethodsRepo] unexpected: $e',
        name: 'Shipping',
        error: e,
        stackTrace: st,
      );
      return Left(InternalFailure());
    }
  }

  @override
  Stream<Either<Failure, List<ShippingMethod>>> watchShippingMethods() {
    return _dataSource
        .watchAll()
        .map<Either<Failure, List<ShippingMethod>>>((methods) {
          final sorted = List<ShippingMethod>.from(methods)
            ..sort((a, b) => a.name.compareTo(b.name));
          return Right(sorted);
        })
        .handleError((Object error, StackTrace st) {
          dev.log(
            '[ShippingMethodsRepo] watchShippingMethods error: $error',
            name: 'Shipping',
            error: error,
            stackTrace: st,
          );
          return Left<Failure, List<ShippingMethod>>(ServerFailure());
        });
  }

  @override
  Future<Either<Failure, Unit>> addShippingMethod({
    required String name,
    required String phone,
  }) async {
    try {
      await _dataSource.add(name: name, phone: phone);
      return const Right(unit);
    } on ServerException catch (e) {
      dev.log(
        '[ShippingMethodsRepo] add error: ${e.message}',
        name: 'Shipping',
      );
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      dev.log(
        '[ShippingMethodsRepo] add unexpected: $e',
        name: 'Shipping',
        error: e,
        stackTrace: st,
      );
      return Left(InternalFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> updateShippingMethod({
    required String id,
    required String name,
  }) async {
    try {
      await _dataSource.update(id: id, name: name);
      return const Right(unit);
    } on ServerException catch (e) {
      dev.log(
        '[ShippingMethodsRepo] update error: ${e.message}',
        name: 'Shipping',
      );
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      dev.log(
        '[ShippingMethodsRepo] update unexpected: $e',
        name: 'Shipping',
        error: e,
        stackTrace: st,
      );
      return Left(InternalFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> updateShippingMethodPhone({
    required String id,
    required String phone,
  }) async {
    try {
      await _dataSource.updatePhone(id: id, phone: phone);
      return const Right(unit);
    } on ServerException catch (e) {
      dev.log(
        '[ShippingMethodsRepo] updatePhone error: ${e.message}',
        name: 'Shipping',
      );
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      dev.log(
        '[ShippingMethodsRepo] updatePhone unexpected: $e',
        name: 'Shipping',
        error: e,
        stackTrace: st,
      );
      return Left(InternalFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteShippingMethod({
    required String id,
  }) async {
    try {
      // First clean up references in clients, then delete
      await _dataSource.cleanupClientReferences(shippingMethodId: id);
      await _dataSource.delete(id: id);
      return const Right(unit);
    } on ServerException catch (e) {
      dev.log(
        '[ShippingMethodsRepo] delete error: ${e.message}',
        name: 'Shipping',
      );
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      dev.log(
        '[ShippingMethodsRepo] delete unexpected: $e',
        name: 'Shipping',
        error: e,
        stackTrace: st,
      );
      return Left(InternalFailure());
    }
  }
}
