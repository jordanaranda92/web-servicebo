import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/shipping_method.dart';
import '../repositories/shipping_methods_repository.dart';

class GetShippingMethods extends UseCase<List<ShippingMethod>, NoParams> {
  final ShippingMethodsRepository _repository;

  GetShippingMethods(this._repository);

  @override
  Future<Either<Failure, List<ShippingMethod>>> call(NoParams params) {
    return _repository.getShippingMethods();
  }
}
