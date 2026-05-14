import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/client_categories_repository.dart';

class UpdateClientCategory extends UseCase<Unit, UpdateClientCategoryParams> {
  final ClientCategoriesRepository _repository;

  UpdateClientCategory(this._repository);

  @override
  Future<Either<Failure, Unit>> call(UpdateClientCategoryParams params) {
    return _repository.updateCategory(
      id: params.id,
      name: params.name,
      color: params.color,
    );
  }
}

class UpdateClientCategoryParams extends Equatable {
  final String id;
  final String name;
  final String? color;

  const UpdateClientCategoryParams({
    required this.id,
    required this.name,
    this.color,
  });

  @override
  List<Object?> get props => [id, name, color];
}
