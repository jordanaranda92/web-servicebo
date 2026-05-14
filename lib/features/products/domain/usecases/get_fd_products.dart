import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/fd_product.dart';
import '../repositories/products_repository.dart';

class GetFdProducts extends UseCase<List<FdProduct>, NoParams> {
  final ProductsRepository _repository;

  GetFdProducts(this._repository);

  @override
  Future<Either<Failure, List<FdProduct>>> call(NoParams params) {
    return _repository.getFdProducts();
  }
}
