import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/shipping_method.dart';
import '../repositories/shipping_methods_repository.dart';

class WatchShippingMethods {
  final ShippingMethodsRepository _repository;

  WatchShippingMethods(this._repository);

  Stream<Either<Failure, List<ShippingMethod>>> call() {
    return _repository.watchShippingMethods();
  }
}
