import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/products_repository.dart';

class SaveProductsBatch extends UseCase<Unit, SaveProductsBatchParams> {
  final ProductsRepository _repository;

  SaveProductsBatch(this._repository);

  @override
  Future<Either<Failure, Unit>> call(SaveProductsBatchParams params) {
    return _repository.saveProductsBatch(
      nameChanges: params.nameChanges,
      activeToggles: params.activeToggles,
      orderChanges: params.orderChanges,
    );
  }
}

class SaveProductsBatchParams extends Equatable {
  final Map<String, String> nameChanges;
  final Map<String, bool> activeToggles;
  final Map<String, int> orderChanges;

  const SaveProductsBatchParams({
    this.nameChanges = const {},
    this.activeToggles = const {},
    this.orderChanges = const {},
  });

  @override
  List<Object?> get props => [nameChanges, activeToggles, orderChanges];
}
