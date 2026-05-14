import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/products_repository.dart';

class LinkFdProduct extends UseCase<Unit, LinkFdProductParams> {
  final ProductsRepository _repository;

  LinkFdProduct(this._repository);

  @override
  Future<Either<Failure, Unit>> call(LinkFdProductParams params) {
    return _repository.linkFdProduct(
      productId: params.productId,
      fdUuid: params.fdUuid,
    );
  }
}

class LinkFdProductParams extends Equatable {
  final String productId;
  final String fdUuid;

  const LinkFdProductParams({required this.productId, required this.fdUuid});

  @override
  List<Object?> get props => [productId, fdUuid];
}
