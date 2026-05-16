import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/order_sheet.dart';
import '../repositories/orders_today_repository.dart';

class ReplaceOrderClient
    implements UseCase<OrderSheet, ReplaceOrderClientParams> {
  final OrdersTodayRepository repository;

  ReplaceOrderClient(this.repository);

  @override
  Future<Either<Failure, OrderSheet>> call(ReplaceOrderClientParams params) {
    return repository.replaceClient(
      clientIndex: params.clientIndex,
      newClientId: params.newClientId,
      date: params.date,
    );
  }
}

class ReplaceOrderClientParams extends Equatable {
  final int clientIndex;
  final String newClientId;
  final DateTime date;

  const ReplaceOrderClientParams({
    required this.clientIndex,
    required this.newClientId,
    required this.date,
  });

  @override
  List<Object?> get props => [clientIndex, newClientId, date];
}
