import 'dart:async';

import 'package:fpdart/fpdart.dart';

import '../../../../core/data/datasources/factura_directa_api_data_source.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/log/app_logger.dart';
import '../../domain/entities/fd_product.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/products_repository.dart';
import '../datasources/product_firestore_data_source.dart';

class ProductsRepositoryImpl implements ProductsRepository {
  final ProductFirestoreDataSource _dataSource;
  final FacturaDirectaApiDataSource _fdApi;
  final AppLogger _logger;

  ProductsRepositoryImpl(this._dataSource, this._fdApi, this._logger);

  @override
  Future<Either<Failure, List<Product>>> getProducts() async {
    _logger.debug('[ProductsRepo] getProducts() called');

    try {
      final models = await _dataSource.getAll();

      final products = models.map((model) => model.toEntity()).toList();

      // Sort by order (nulls at the end), then alphabetically by name
      products.sort((a, b) {
        final aOrder = a.order;
        final bOrder = b.order;
        if (aOrder == null && bOrder == null) {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
        if (aOrder == null) return 1;
        if (bOrder == null) return -1;
        final cmp = aOrder.compareTo(bOrder);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      _logger.debug('[ProductsRepo] loaded ${products.length} products');
      return Right(products);
    } on ServerException catch (e) {
      _logger.error('[ProductsRepo] ServerException: ${e.message}');
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } on Exception catch (e, st) {
      _logger.error('[ProductsRepo] unexpected error: $e', e, st);
      return Left(InternalFailure());
    }
  }

  @override
  Stream<Either<Failure, List<Product>>> watchProducts() {
    return _dataSource
        .watchAll()
        .map<Either<Failure, List<Product>>>((models) {
          final products = models.map((model) => model.toEntity()).toList();
          products.sort((a, b) {
            final aOrder = a.order;
            final bOrder = b.order;
            if (aOrder == null && bOrder == null) {
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            }
            if (aOrder == null) return 1;
            if (bOrder == null) return -1;
            final cmp = aOrder.compareTo(bOrder);
            if (cmp != 0) return cmp;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
          _logger.debug(
            '[ProductsRepo] watchProducts: ${products.length} products',
          );
          return Right(products);
        })
        .handleError((Object error, StackTrace st) {
          _logger.error(
            '[ProductsRepo] watchProducts error: $error',
            error,
            st,
          );
          return Left<Failure, List<Product>>(ServerFailure());
        });
  }

  @override
  Future<Either<Failure, Unit>> saveProductsBatch({
    Map<String, String> nameChanges = const {},
    Map<String, bool> activeToggles = const {},
    Map<String, int> orderChanges = const {},
  }) async {
    _logger.debug(
      '[ProductsRepo] saveProductsBatch('
      'name: ${nameChanges.length}, '
      'active: ${activeToggles.length}, '
      'order: ${orderChanges.length})',
    );

    try {
      final allIds = <String>{
        ...nameChanges.keys,
        ...activeToggles.keys,
        ...orderChanges.keys,
      };

      if (allIds.isEmpty) return const Right(unit);

      final updates = <String, Map<String, dynamic>>{};

      for (final id in allIds) {
        final fields = <String, dynamic>{};
        if (nameChanges.containsKey(id)) {
          fields['name'] = nameChanges[id];
        }
        if (activeToggles.containsKey(id)) {
          fields['isActive'] = activeToggles[id];
        }
        if (orderChanges.containsKey(id)) {
          fields['order'] = orderChanges[id];
        }
        updates[id] = fields;
      }

      await _dataSource.batchUpdate(updates);

      _logger.debug(
        '[ProductsRepo] saveProductsBatch: updated ${updates.length} docs',
      );
      return const Right(unit);
    } on ServerException catch (e) {
      _logger.error('[ProductsRepo] ServerException: ${e.message}');
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } on Exception catch (e, st) {
      _logger.error('[ProductsRepo] unexpected error: $e', e, st);
      return Left(InternalFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> addProduct({required String name}) async {
    _logger.debug('[ProductsRepo] addProduct(name=$name)');
    try {
      await _dataSource.add({
        'name': name,
        'facturaDirectaUuid': '',
        'isActive': true,
        'color': '#FFFFFF',
      });
      return const Right(unit);
    } on ServerException catch (e) {
      _logger.error('[ProductsRepo] ServerException: ${e.message}');
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } on Exception catch (e, st) {
      _logger.error('[ProductsRepo] unexpected error: $e', e, st);
      return Left(InternalFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteProduct({required String id}) async {
    _logger.debug('[ProductsRepo] deleteProduct(id=$id)');
    try {
      await _dataSource.delete(id);
      return const Right(unit);
    } on ServerException catch (e) {
      _logger.error('[ProductsRepo] ServerException: ${e.message}');
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } on Exception catch (e, st) {
      _logger.error('[ProductsRepo] unexpected error: $e', e, st);
      return Left(InternalFailure());
    }
  }

  @override
  Future<Either<Failure, List<FdProduct>>> getFdProducts() async {
    _logger.debug('[ProductsRepo] getFdProducts() called');

    try {
      final rawProducts = await _fdApi.getProducts();
      _logger.debug(
        '[ProductsRepo] fetched ${rawProducts.length} products from FD',
      );

      final products = <FdProduct>[];
      for (final json in rawProducts) {
        final content = json['content'] as Map<String, dynamic>?;
        final main = content?['main'] as Map<String, dynamic>? ?? {};
        final uuid = content?['uuid'] as String? ?? '';
        if (uuid.isEmpty) continue;

        final name = (main['name'] as String?) ?? '';
        final sales = main['sales'] as Map<String, dynamic>? ?? {};
        final salesPrice = _parseDouble(sales['price']);
        final currency = main['currency'] as String?;
        final salesTax =
            (sales['tax'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final salesDescription = sales['description'] as String?;

        products.add(
          FdProduct(
            uuid: uuid,
            name: name,
            salesPrice: salesPrice,
            currency: currency,
            salesTax: salesTax,
            salesDescription: salesDescription,
          ),
        );
      }

      products.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      return Right(products);
    } on ServerException catch (e) {
      _logger.error(
        '[ProductsRepo] getFdProducts ServerException: ${e.message}',
      );
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } on Exception catch (e, st) {
      _logger.error('[ProductsRepo] getFdProducts unexpected error: $e', e, st);
      return Left(InternalFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> linkFdProduct({
    required String productId,
    required String fdUuid,
  }) async {
    _logger.debug(
      '[ProductsRepo] linkFdProduct(productId=$productId, fdUuid=$fdUuid)',
    );

    try {
      await _dataSource.updateFields(
        id: productId,
        fields: {'facturaDirectaUuid': fdUuid},
      );
      return const Right(unit);
    } on ServerException catch (e) {
      _logger.error(
        '[ProductsRepo] linkFdProduct ServerException: ${e.message}',
      );
      return Left(ServerFailure());
    } on NetworkException {
      return Left(NetworkFailure());
    } on Exception catch (e, st) {
      _logger.error('[ProductsRepo] linkFdProduct unexpected error: $e', e, st);
      return Left(InternalFailure());
    }
  }

  double? _parseDouble(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
