import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/clients_repository.dart';

class SaveClientsBatch extends UseCase<Unit, SaveClientsBatchParams> {
  final ClientsRepository _repository;

  SaveClientsBatch(this._repository);

  @override
  Future<Either<Failure, Unit>> call(SaveClientsBatchParams params) {
    return _repository.saveClientsBatch(
      nameChanges: params.nameChanges,
      categoryChanges: params.categoryChanges,
      shippingMethodsByDayChanges: params.shippingMethodsByDayChanges,
    );
  }
}

class SaveClientsBatchParams extends Equatable {
  final Map<String, String> nameChanges;
  final Map<String, String?> categoryChanges;
  final Map<String, Map<String, String?>> shippingMethodsByDayChanges;

  const SaveClientsBatchParams({
    this.nameChanges = const {},
    this.categoryChanges = const {},
    this.shippingMethodsByDayChanges = const {},
  });

  @override
  List<Object?> get props => [
    nameChanges,
    categoryChanges,
    shippingMethodsByDayChanges,
  ];
}
