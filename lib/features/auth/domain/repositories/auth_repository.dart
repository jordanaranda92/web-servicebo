import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/app_user.dart';

abstract class AuthRepository {
  Future<Either<Failure, AppUser>> signIn({
    required String email,
    required String password,
  });

  Future<Either<Failure, Unit>> signOut();

  Future<Either<Failure, AppUser?>> getCurrentUser();

  Future<Either<Failure, AppUser?>> getCurrentUserWithProfile();

  Future<Either<Failure, String?>> getUserName(String uid);

  Future<Either<Failure, Unit>> saveUserName(String uid, String name);

  Future<Either<Failure, String?>> getUserColor(String uid);

  bool isRememberMeEnabled();

  Future<void> setRememberMe(bool value);
}
