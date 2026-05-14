import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

class GetUserName implements UseCase<String?, GetUserNameParams> {
  final AuthRepository repository;

  GetUserName(this.repository);

  @override
  Future<Either<Failure, String?>> call(GetUserNameParams params) {
    return repository.getUserName(params.uid);
  }
}

class GetUserNameParams extends Equatable {
  final String uid;

  const GetUserNameParams({required this.uid});

  @override
  List<Object?> get props => [uid];
}
