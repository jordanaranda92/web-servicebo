import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../orders_today/domain/entities/order_sheet.dart';
import '../entities/order_date_info.dart';

abstract class OrdersHistoryRepository {
  Future<Either<Failure, List<OrderDateInfo>>> getAvailableDates();

  Future<Either<Failure, OrderSheet>> getHistoryOrders(DateTime date);
}
