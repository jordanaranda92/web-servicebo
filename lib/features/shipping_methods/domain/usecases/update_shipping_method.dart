import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/shipping_methods_repository.dart';

class UpdateShippingMethod extends UseCase<Unit, UpdateShippingMethodParams> {
  final ShippingMethodsRepository _repository;

  UpdateShippingMethod(this._repository);

  @override
  Future<Either<Failure, Unit>> call(UpdateShippingMethodParams params) {
    return _repository.updateShippingMethod(id: params.id, name: params.name);
  }
}

class UpdateShippingMethodParams extends Equatable {
  final String id;
  final String name;

  const UpdateShippingMethodParams({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}
