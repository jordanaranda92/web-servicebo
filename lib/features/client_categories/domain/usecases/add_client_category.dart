import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/client_categories_repository.dart';

class AddClientCategory extends UseCase<Unit, AddClientCategoryParams> {
  final ClientCategoriesRepository _repository;

  AddClientCategory(this._repository);

  @override
  Future<Either<Failure, Unit>> call(AddClientCategoryParams params) {
    return _repository.addCategory(name: params.name, color: params.color);
  }
}

class AddClientCategoryParams extends Equatable {
  final String name;
  final String? color;

  const AddClientCategoryParams({required this.name, this.color});

  @override
  List<Object?> get props => [name, color];
}
