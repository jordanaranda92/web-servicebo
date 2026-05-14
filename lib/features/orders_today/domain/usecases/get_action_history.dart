import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/order_action_entry.dart';
import '../repositories/orders_today_repository.dart';

class GetActionHistory
    implements UseCase<List<OrderActionEntry>, GetActionHistoryParams> {
  final OrdersTodayRepository repository;

  GetActionHistory(this.repository);

  @override
  Future<Either<Failure, List<OrderActionEntry>>> call(
    GetActionHistoryParams params,
  ) {
    return repository.getActionHistory(params.date);
  }
}

class GetActionHistoryParams extends Equatable {
  final DateTime date;

  const GetActionHistoryParams({required this.date});

  @override
  List<Object?> get props => [date];
}
