import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/order_sheet.dart';
import '../repositories/orders_repository.dart';

class RemoveOrderProducts
    implements UseCase<OrderSheet, RemoveOrderProductsParams> {
  final OrdersRepository repository;

  RemoveOrderProducts(this.repository);

  @override
  Future<Either<Failure, OrderSheet>> call(RemoveOrderProductsParams params) {
    return repository.removeProducts(
      productIndices: params.productIndices,
      date: params.date,
    );
  }
}

class RemoveOrderProductsParams extends Equatable {
  final List<int> productIndices;
  final DateTime date;

  const RemoveOrderProductsParams({
    required this.productIndices,
    required this.date,
  });

  @override
  List<Object?> get props => [productIndices, date];
}
