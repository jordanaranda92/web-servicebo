import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/order_date_info.dart';
import '../repositories/orders_history_repository.dart';

class GetAvailableDates implements UseCase<List<OrderDateInfo>, NoParams> {
  final OrdersHistoryRepository repository;

  GetAvailableDates(this.repository);

  @override
  Future<Either<Failure, List<OrderDateInfo>>> call(NoParams params) {
    return repository.getAvailableDates();
  }
}
