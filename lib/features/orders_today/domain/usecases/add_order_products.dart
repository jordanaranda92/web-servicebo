import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/order_sheet.dart';
import '../repositories/orders_today_repository.dart';

class AddOrderProducts implements UseCase<OrderSheet, AddOrderProductsParams> {
  final OrdersTodayRepository repository;

  AddOrderProducts(this.repository);

  @override
  Future<Either<Failure, OrderSheet>> call(AddOrderProductsParams params) {
    return repository.addProducts(
      productIds: params.productIds,
      date: params.date,
    );
  }
}

class AddOrderProductsParams extends Equatable {
  final List<String> productIds;
  final DateTime date;

  const AddOrderProductsParams({required this.productIds, required this.date});

  @override
  List<Object?> get props => [productIds, date];
}
