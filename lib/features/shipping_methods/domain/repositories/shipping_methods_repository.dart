import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/shipping_method.dart';

abstract class ShippingMethodsRepository {
  Future<Either<Failure, List<ShippingMethod>>> getShippingMethods();
  Stream<Either<Failure, List<ShippingMethod>>> watchShippingMethods();
  Future<Either<Failure, Unit>> addShippingMethod({
    required String name,
    required String phone,
  });
  Future<Either<Failure, Unit>> updateShippingMethod({
    required String id,
    required String name,
  });
  Future<Either<Failure, Unit>> updateShippingMethodPhone({
    required String id,
    required String phone,
  });
  Future<Either<Failure, Unit>> deleteShippingMethod({required String id});
}
