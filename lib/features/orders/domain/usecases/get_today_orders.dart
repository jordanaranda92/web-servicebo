import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/order_sheet.dart';
import '../repositories/orders_repository.dart';

class GetTodayOrders implements UseCase<OrderSheet?, GetTodayOrdersParams> {
  final OrdersRepository repository;

  GetTodayOrders(this.repository);

  @override
  Future<Either<Failure, OrderSheet?>> call(GetTodayOrdersParams params) {
    return repository.getTodayOrders(params.date);
  }
}

class GetTodayOrdersParams extends Equatable {
  final DateTime date;

  const GetTodayOrdersParams({required this.date});

  @override
  List<Object?> get props => [date];
}
