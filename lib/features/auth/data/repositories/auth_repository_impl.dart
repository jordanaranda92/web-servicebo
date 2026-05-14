import 'dart:developer' as dev;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remoteDataSource, this._localDataSource);

  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  @override
  Future<Either<Failure, AppUser>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _remoteDataSource.signInWithEmailPassword(
        email,
        password,
      );
      return Right(user);
    } on FirebaseAuthException catch (e) {
      return Left(_mapAuthException(e));
    } on ServerException {
      return Left(AuthUnknownFailure());
    } on Exception catch (e, st) {
      dev.log('[Auth] signIn unexpected error', error: e, stackTrace: st);
      return Left(AuthUnknownFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      await _remoteDataSource.signOut();
      await _localDataSource.setRememberMe(false);
      return const Right(unit);
    } on Exception catch (e, st) {
      dev.log('[Auth] signOut unexpected error', error: e, stackTrace: st);
      return Left(AuthUnknownFailure());
    }
  }

  @override
  Future<Either<Failure, AppUser?>> getCurrentUser() async {
    try {
      final user = _remoteDataSource.getCurrentUser();
      return Right(user);
    } on Exception catch (e, st) {
      dev.log(
        '[Auth] getCurrentUser unexpected error',
        error: e,
        stackTrace: st,
      );
      return Left(AuthUnknownFailure());
    }
  }

  @override
  Future<Either<Failure, AppUser?>> getCurrentUserWithProfile() async {
    try {
      final user = await _remoteDataSource.getCurrentUserWithProfile();
      return Right(user);
    } on ServerException {
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      dev.log(
        '[Auth] getCurrentUserWithProfile unexpected error',
        error: e,
        stackTrace: st,
      );
      return Left(AuthUnknownFailure());
    }
  }

  @override
  Future<Either<Failure, String?>> getUserName(String uid) async {
    try {
      final name = await _remoteDataSource.getUserName(uid);
      return Right(name);
    } on ServerException {
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      dev.log('[Auth] getUserName unexpected error', error: e, stackTrace: st);
      return Left(InternalFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> saveUserName(String uid, String name) async {
    try {
      await _remoteDataSource.saveUserName(uid, name);
      return const Right(unit);
    } on ServerException {
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      dev.log('[Auth] saveUserName unexpected error', error: e, stackTrace: st);
      return Left(InternalFailure());
    }
  }

  @override
  bool isRememberMeEnabled() => _localDataSource.getRememberMe();

  @override
  Future<void> setRememberMe(bool value) =>
      _localDataSource.setRememberMe(value);

  Failure _mapAuthException(FirebaseAuthException e) {
    return switch (e.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' ||
      'invalid-email' => AuthInvalidCredentialsFailure(),
      'user-disabled' => AuthUserDisabledFailure(),
      'too-many-requests' => AuthTooManyRequestsFailure(),
      'network-request-failed' => NetworkFailure(),
      _ => AuthUnknownFailure(),
    };
  }
}
