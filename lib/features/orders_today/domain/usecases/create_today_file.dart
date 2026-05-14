import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/order_sheet.dart';
import '../repositories/orders_today_repository.dart';

class CreateTodayFile implements UseCase<OrderSheet, CreateTodayFileParams> {
  final OrdersTodayRepository repository;

  CreateTodayFile(this.repository);

  @override
  Future<Either<Failure, OrderSheet>> call(CreateTodayFileParams params) {
    return repository.createTodaySheet(params.date);
  }
}

class CreateTodayFileParams extends Equatable {
  final DateTime date;

  const CreateTodayFileParams({required this.date});

  @override
  List<Object?> get props => [date];
}
