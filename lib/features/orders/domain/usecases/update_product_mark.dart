import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/orders_repository.dart';

class UpdateProductMark implements UseCase<Unit, UpdateProductMarkParams> {
  final OrdersRepository repository;

  UpdateProductMark(this.repository);

  @override
  Future<Either<Failure, Unit>> call(UpdateProductMarkParams params) {
    return repository.updateProductMark(
      productId: params.productId,
      productMark: params.productMark,
      date: params.date,
    );
  }
}

class UpdateProductMarkParams extends Equatable {
  final String productId;
  final String? productMark;
  final DateTime date;

  const UpdateProductMarkParams({
    required this.productId,
    required this.productMark,
    required this.date,
  });

  @override
  List<Object?> get props => [productId, productMark, date];
}
