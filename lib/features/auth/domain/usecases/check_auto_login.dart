import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

class CheckAutoLogin implements UseCase<AppUser?, NoParams> {
  final AuthRepository repository;

  CheckAutoLogin(this.repository);

  @override
  Future<Either<Failure, AppUser?>> call(NoParams params) async {
    if (!repository.isRememberMeEnabled()) {
      // No remember-me → sign out any residual session
      await repository.signOut();
      return const Right(null);
    }
    return repository.getCurrentUserWithProfile();
  }
}
