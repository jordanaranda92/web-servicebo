import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/orders_repository.dart';

class UpdateCellNote implements UseCase<Unit, UpdateCellNoteParams> {
  final OrdersRepository repository;

  UpdateCellNote(this.repository);

  @override
  Future<Either<Failure, Unit>> call(UpdateCellNoteParams params) {
    return repository.updateCellNote(
      productId: params.productId,
      clientId: params.clientId,
      note: params.note,
      date: params.date,
    );
  }
}

class UpdateCellNoteParams extends Equatable {
  final String productId;
  final String clientId;
  final String? note;
  final DateTime date;

  const UpdateCellNoteParams({
    required this.productId,
    required this.clientId,
    required this.note,
    required this.date,
  });

  @override
  List<Object?> get props => [productId, clientId, note, date];
}
