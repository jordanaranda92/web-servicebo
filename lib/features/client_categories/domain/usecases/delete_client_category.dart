import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/client_categories_repository.dart';

class DeleteClientCategory extends UseCase<Unit, DeleteClientCategoryParams> {
  final ClientCategoriesRepository _repository;

  DeleteClientCategory(this._repository);

  @override
  Future<Either<Failure, Unit>> call(DeleteClientCategoryParams params) {
    return _repository.deleteCategory(id: params.id);
  }
}

class DeleteClientCategoryParams extends Equatable {
  final String id;

  const DeleteClientCategoryParams({required this.id});

  @override
  List<Object?> get props => [id];
}
