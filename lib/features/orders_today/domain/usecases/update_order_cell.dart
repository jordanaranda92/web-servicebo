import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/orders_today_repository.dart';

class UpdateOrderCell implements UseCase<Unit, UpdateOrderCellParams> {
  final OrdersTodayRepository repository;

  UpdateOrderCell(this.repository);

  @override
  Future<Either<Failure, Unit>> call(UpdateOrderCellParams params) {
    return repository.updateCell(
      productId: params.productId,
      clientId: params.clientId,
      value: params.value,
      date: params.date,
    );
  }
}

class UpdateOrderCellParams extends Equatable {
  final String productId;
  final String? clientId;
  final num value;
  final DateTime date;

  const UpdateOrderCellParams({
    required this.productId,
    required this.clientId,
    required this.value,
    required this.date,
  });

  @override
  List<Object?> get props => [productId, clientId, value, date];
}
