import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/app_user.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(const AuthUnauthenticated());

  void setUser(AppUser user) {
    emit(AuthAuthenticated(user));
  }

  void clear() {
    emit(const AuthUnauthenticated());
  }
}
