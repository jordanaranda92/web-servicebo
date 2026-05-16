import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/orders_today_repository.dart';

class UpdateClientNote implements UseCase<Unit, UpdateClientNoteParams> {
  final OrdersTodayRepository repository;

  UpdateClientNote(this.repository);

  @override
  Future<Either<Failure, Unit>> call(UpdateClientNoteParams params) {
    return repository.updateClientNote(
      clientId: params.clientId,
      note: params.note,
      date: params.date,
    );
  }
}

class UpdateClientNoteParams extends Equatable {
  final String clientId;
  final String? note;
  final DateTime date;

  const UpdateClientNoteParams({
    required this.clientId,
    required this.note,
    required this.date,
  });

  @override
  List<Object?> get props => [clientId, note, date];
}
