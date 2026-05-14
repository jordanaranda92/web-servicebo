import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/shipping_methods_repository.dart';

class DeleteShippingMethod extends UseCase<Unit, DeleteShippingMethodParams> {
  final ShippingMethodsRepository _repository;

  DeleteShippingMethod(this._repository);

  @override
  Future<Either<Failure, Unit>> call(DeleteShippingMethodParams params) {
    return _repository.deleteShippingMethod(id: params.id);
  }
}

class DeleteShippingMethodParams extends Equatable {
  final String id;

  const DeleteShippingMethodParams({required this.id});

  @override
  List<Object?> get props => [id];
}
