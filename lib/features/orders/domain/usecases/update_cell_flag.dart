import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/orders_repository.dart';

class UpdateCellFlag implements UseCase<Unit, UpdateCellFlagParams> {
  final OrdersRepository repository;

  UpdateCellFlag(this.repository);

  @override
  Future<Either<Failure, Unit>> call(UpdateCellFlagParams params) {
    return repository.updateCellFlag(
      productId: params.productId,
      clientId: params.clientId,
      flagType: params.flagType,
      date: params.date,
    );
  }
}

class UpdateCellFlagParams extends Equatable {
  final String productId;
  final String? clientId;
  final String? flagType;
  final DateTime date;

  const UpdateCellFlagParams({
    required this.productId,
    required this.clientId,
    required this.flagType,
    required this.date,
  });

  @override
  List<Object?> get props => [productId, clientId, flagType, date];
}
