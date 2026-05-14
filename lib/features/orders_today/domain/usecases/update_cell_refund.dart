import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/orders_today_repository.dart';

class UpdateCellRefund implements UseCase<Unit, UpdateCellRefundParams> {
  final OrdersTodayRepository repository;

  UpdateCellRefund(this.repository);

  @override
  Future<Either<Failure, Unit>> call(UpdateCellRefundParams params) {
    return repository.updateCellRefund(
      productId: params.productId,
      clientId: params.clientId,
      quantity: params.quantity,
      date: params.date,
    );
  }
}

class UpdateCellRefundParams extends Equatable {
  final String productId;
  final String clientId;
  final num? quantity;
  final DateTime date;

  const UpdateCellRefundParams({
    required this.productId,
    required this.clientId,
    required this.quantity,
    required this.date,
  });

  @override
  List<Object?> get props => [productId, clientId, quantity, date];
}
