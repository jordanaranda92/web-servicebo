import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/shipping_methods_repository.dart';

class UpdateShippingMethodPhone
    extends UseCase<Unit, UpdateShippingMethodPhoneParams> {
  final ShippingMethodsRepository _repository;

  UpdateShippingMethodPhone(this._repository);

  @override
  Future<Either<Failure, Unit>> call(UpdateShippingMethodPhoneParams params) {
    return _repository.updateShippingMethodPhone(
      id: params.id,
      phone: params.phone,
    );
  }
}

class UpdateShippingMethodPhoneParams extends Equatable {
  final String id;
  final String phone;

  const UpdateShippingMethodPhoneParams({
    required this.id,
    required this.phone,
  });

  @override
  List<Object?> get props => [id, phone];
}
