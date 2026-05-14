import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/order_sheet.dart';
import '../repositories/orders_today_repository.dart';

class RemoveOrderClients
    implements UseCase<OrderSheet, RemoveOrderClientsParams> {
  final OrdersTodayRepository repository;

  RemoveOrderClients(this.repository);

  @override
  Future<Either<Failure, OrderSheet>> call(RemoveOrderClientsParams params) {
    return repository.removeClients(
      clientIndices: params.clientIndices,
      date: params.date,
    );
  }
}

class RemoveOrderClientsParams extends Equatable {
  final List<int> clientIndices;
  final DateTime date;

  const RemoveOrderClientsParams({
    required this.clientIndices,
    required this.date,
  });

  @override
  List<Object?> get props => [clientIndices, date];
}
