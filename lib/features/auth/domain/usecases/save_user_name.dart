import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

class SaveUserName implements UseCase<Unit, SaveUserNameParams> {
  final AuthRepository repository;

  SaveUserName(this.repository);

  @override
  Future<Either<Failure, Unit>> call(SaveUserNameParams params) {
    return repository.saveUserName(params.uid, params.name);
  }
}

class SaveUserNameParams extends Equatable {
  final String uid;
  final String name;

  const SaveUserNameParams({required this.uid, required this.name});

  @override
  List<Object?> get props => [uid, name];
}
