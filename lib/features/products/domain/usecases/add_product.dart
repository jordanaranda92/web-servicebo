import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/products_repository.dart';

class AddProduct extends UseCase<Unit, AddProductParams> {
  final ProductsRepository _repository;

  AddProduct(this._repository);

  @override
  Future<Either<Failure, Unit>> call(AddProductParams params) {
    return _repository.addProduct(name: params.name);
  }
}

class AddProductParams extends Equatable {
  final String name;

  const AddProductParams({required this.name});

  @override
  List<Object?> get props => [name];
}
