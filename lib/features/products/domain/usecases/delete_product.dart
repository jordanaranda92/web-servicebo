import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/products_repository.dart';

class DeleteProduct extends UseCase<Unit, DeleteProductParams> {
  final ProductsRepository _repository;

  DeleteProduct(this._repository);

  @override
  Future<Either<Failure, Unit>> call(DeleteProductParams params) {
    return _repository.deleteProduct(id: params.id);
  }
}

class DeleteProductParams extends Equatable {
  final String id;

  const DeleteProductParams({required this.id});

  @override
  List<Object?> get props => [id];
}
