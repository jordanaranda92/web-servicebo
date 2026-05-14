import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/sign_in.dart';
import 'auth_cubit.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._signIn, this._authRepository, this._authCubit)
    : super(const LoginInitial());

  final SignIn _signIn;
  final AuthRepository _authRepository;
  final AuthCubit _authCubit;

  Future<void> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final trimmedEmail = email.trim();

    if (trimmedEmail.isEmpty) {
      emit(const LoginError('loginErrorEmailEmpty'));
      return;
    }

    if (!_isValidEmail(trimmedEmail)) {
      emit(const LoginError('loginErrorEmailInvalid'));
      return;
    }

    if (password.isEmpty) {
      emit(const LoginError('loginErrorPasswordEmpty'));
      return;
    }

    emit(const LoginLoading());

    final result = await _signIn(
      SignInParams(email: trimmedEmail, password: password),
    );

    await result.fold(
      (failure) async {
        emit(LoginError(_mapFailureToMessageKey(failure)));
      },
      (user) async {
        await _authRepository.setRememberMe(rememberMe);
        _authCubit.setUser(user);
        emit(const LoginSuccess());
      },
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  String _mapFailureToMessageKey(Failure failure) {
    return switch (failure) {
      AuthInvalidCredentialsFailure() => 'loginErrorInvalidCredentials',
      AuthUserDisabledFailure() => 'loginErrorUserDisabled',
      AuthTooManyRequestsFailure() => 'loginErrorTooManyRequests',
      NetworkFailure() => 'loginErrorNetwork',
      _ => 'loginErrorUnknown',
    };
  }
}
