import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/fd_product.dart';
import '../entities/product.dart';

abstract class ProductsRepository {
  Future<Either<Failure, List<Product>>> getProducts();

  Stream<Either<Failure, List<Product>>> watchProducts();

  Future<Either<Failure, Unit>> saveProductsBatch({
    Map<String, String> nameChanges,
    Map<String, bool> activeToggles,
    Map<String, int> orderChanges,
  });

  Future<Either<Failure, Unit>> addProduct({required String name});

  Future<Either<Failure, Unit>> deleteProduct({required String id});

  Future<Either<Failure, List<FdProduct>>> getFdProducts();

  Future<Either<Failure, Unit>> linkFdProduct({
    required String productId,
    required String fdUuid,
  });
}
