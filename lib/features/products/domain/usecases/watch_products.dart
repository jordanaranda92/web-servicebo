import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/product.dart';
import '../repositories/products_repository.dart';

class WatchProducts {
  final ProductsRepository _repository;

  WatchProducts(this._repository);

  Stream<Either<Failure, List<Product>>> call() {
    return _repository.watchProducts();
  }
}
