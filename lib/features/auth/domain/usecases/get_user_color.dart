import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

class GetUserColor implements UseCase<String?, GetUserColorParams> {
  final AuthRepository repository;

  GetUserColor(this.repository);

  @override
  Future<Either<Failure, String?>> call(GetUserColorParams params) {
    return repository.getUserColor(params.uid);
  }
}

class GetUserColorParams extends Equatable {
  final String uid;

  const GetUserColorParams({required this.uid});

  @override
  List<Object?> get props => [uid];
}
