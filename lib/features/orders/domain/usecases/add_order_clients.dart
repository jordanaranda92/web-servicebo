import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/order_sheet.dart';
import '../repositories/orders_repository.dart';

class AddOrderClients implements UseCase<OrderSheet, AddOrderClientsParams> {
  final OrdersRepository repository;

  AddOrderClients(this.repository);

  @override
  Future<Either<Failure, OrderSheet>> call(AddOrderClientsParams params) {
    return repository.addClients(
      clientIds: params.clientIds,
      date: params.date,
    );
  }
}

class AddOrderClientsParams extends Equatable {
  final List<String> clientIds;
  final DateTime date;

  const AddOrderClientsParams({required this.clientIds, required this.date});

  @override
  List<Object?> get props => [clientIds, date];
}
