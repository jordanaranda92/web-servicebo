import 'dart:developer' as dev;

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../clients/domain/entities/client_category.dart';
import '../../domain/repositories/client_categories_repository.dart';
import '../datasources/client_category_firestore_data_source.dart';

class ClientCategoriesRepositoryImpl implements ClientCategoriesRepository {
  final ClientCategoryFirestoreDataSource _dataSource;

  ClientCategoriesRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, List<ClientCategory>>> getCategories() async {
    dev.log('[ClientCategoriesRepo] getCategories() called', name: 'ClientCat');

    try {
      final categories = await _dataSource.getAll();
      categories.sort((a, b) => a.name.compareTo(b.name));

      dev.log(
        '[ClientCategoriesRepo] fetched ${categories.length} categories',
        name: 'ClientCat',
      );
      return Right(categories);
    } on ServerException catch (e) {
      dev.log(
        '[ClientCategoriesRepo] ServerException: ${e.message}',
        name: 'ClientCat',
      );
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } on Exception catch (e, st) {
      dev.log(
        '[ClientCategoriesRepo] unexpected error: $e',
        name: 'ClientCat',
        error: e,
        stackTrace: st,
      );
      return Left(InternalFailure());
    }
  }

  @override
  Stream<Either<Failure, List<ClientCategory>>> watchCategories() {
    return _dataSource
        .watchAll()
        .map<Either<Failure, List<ClientCategory>>>((categories) {
          final sorted = List<ClientCategory>.from(categories)
            ..sort((a, b) => a.name.compareTo(b.name));
          dev.log(
            '[ClientCategoriesRepo] watchCategories: ${sorted.length} categories',
            name: 'ClientCat',
          );
          return Right(sorted);
        })
        .handleError((Object error, StackTrace st) {
          dev.log(
            '[ClientCategoriesRepo] watchCategories error: $error',
            name: 'ClientCat',
            error: error,
            stackTrace: st,
          );
          return Left<Failure, List<ClientCategory>>(ServerFailure());
        });
  }

  @override
  Future<Either<Failure, Unit>> addCategory({
    required String name,
    String? color,
  }) async {
    dev.log(
      '[ClientCategoriesRepo] addCategory(name: $name, color: $color)',
      name: 'ClientCat',
    );

    try {
      await _dataSource.add(name: name, color: color);

      dev.log(
        '[ClientCategoriesRepo] added category "$name"',
        name: 'ClientCat',
      );
      return const Right(unit);
    } on ServerException catch (e) {
      dev.log(
        '[ClientCategoriesRepo] ServerException: ${e.message}',
        name: 'ClientCat',
      );
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } on Exception catch (e, st) {
      dev.log(
        '[ClientCategoriesRepo] unexpected error: $e',
        name: 'ClientCat',
        error: e,
        stackTrace: st,
      );
      return Left(InternalFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> updateCategory({
    required String id,
    required String name,
    String? color,
  }) async {
    dev.log(
      '[ClientCategoriesRepo] updateCategory(id: $id, name: $name, color: $color)',
      name: 'ClientCat',
    );

    try {
      await _dataSource.update(id: id, name: name, color: color);
      return const Right(unit);
    } on ServerException catch (e) {
      dev.log(
        '[ClientCategoriesRepo] ServerException: ${e.message}',
        name: 'ClientCat',
      );
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } on Exception catch (e, st) {
      dev.log(
        '[ClientCategoriesRepo] unexpected error: $e',
        name: 'ClientCat',
        error: e,
        stackTrace: st,
      );
      return Left(InternalFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteCategory({required String id}) async {
    dev.log(
      '[ClientCategoriesRepo] deleteCategory(id: $id)',
      name: 'ClientCat',
    );

    try {
      await _dataSource.delete(id: id);
      return const Right(unit);
    } on ServerException catch (e) {
      dev.log(
        '[ClientCategoriesRepo] ServerException: ${e.message}',
        name: 'ClientCat',
      );
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } on Exception catch (e, st) {
      dev.log(
        '[ClientCategoriesRepo] unexpected error: $e',
        name: 'ClientCat',
        error: e,
        stackTrace: st,
      );
      return Left(InternalFailure());
    }
  }
}
