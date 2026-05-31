import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/order_sheet.dart';
import '../repositories/orders_repository.dart';

class ResetClientOrders
    implements UseCase<OrderSheet, ResetClientOrdersParams> {
  final OrdersRepository repository;

  ResetClientOrders(this.repository);

  @override
  Future<Either<Failure, OrderSheet>> call(ResetClientOrdersParams params) {
    return repository.resetClientOrders(
      clientIndices: params.clientIndices,
      date: params.date,
    );
  }
}

class ResetClientOrdersParams extends Equatable {
  final List<int> clientIndices;
  final DateTime date;

  const ResetClientOrdersParams({
    required this.clientIndices,
    required this.date,
  });

  @override
  List<Object?> get props => [clientIndices, date];
}
