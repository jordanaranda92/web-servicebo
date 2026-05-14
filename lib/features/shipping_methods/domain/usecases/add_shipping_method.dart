import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/shipping_methods_repository.dart';

class AddShippingMethod extends UseCase<Unit, AddShippingMethodParams> {
  final ShippingMethodsRepository _repository;

  AddShippingMethod(this._repository);

  @override
  Future<Either<Failure, Unit>> call(AddShippingMethodParams params) {
    return _repository.addShippingMethod(
      name: params.name,
      phone: params.phone,
    );
  }
}

class AddShippingMethodParams extends Equatable {
  final String name;
  final String phone;

  const AddShippingMethodParams({required this.name, this.phone = ''});

  @override
  List<Object?> get props => [name, phone];
}
