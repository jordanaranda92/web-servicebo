import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/product.dart';
import '../repositories/products_repository.dart';

class GetProducts extends UseCase<List<Product>, NoParams> {
  final ProductsRepository _repository;

  GetProducts(this._repository);

  @override
  Future<Either<Failure, List<Product>>> call(NoParams params) {
    return _repository.getProducts();
  }
}
