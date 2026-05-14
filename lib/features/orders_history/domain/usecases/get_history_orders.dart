import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../orders_today/domain/entities/order_sheet.dart';
import '../repositories/orders_history_repository.dart';

class GetHistoryOrders implements UseCase<OrderSheet, GetHistoryOrdersParams> {
  final OrdersHistoryRepository repository;

  GetHistoryOrders(this.repository);

  @override
  Future<Either<Failure, OrderSheet>> call(GetHistoryOrdersParams params) {
    return repository.getHistoryOrders(params.date);
  }
}

class GetHistoryOrdersParams extends Equatable {
  final DateTime date;

  const GetHistoryOrdersParams({required this.date});

  @override
  List<Object?> get props => [date];
}
