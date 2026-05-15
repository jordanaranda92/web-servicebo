import 'package:get_it/get_it.dart';

import '../../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../../features/auth/data/datasources/auth_local_data_source_impl.dart';
import '../../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../../features/auth/data/datasources/auth_remote_data_source_impl.dart';
import '../../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../../features/auth/domain/repositories/auth_repository.dart';
import '../../../features/auth/domain/usecases/check_auto_login.dart';
import '../../../features/auth/domain/usecases/get_current_user.dart';
import '../../../features/auth/domain/usecases/get_user_name.dart';
import '../../../features/auth/domain/usecases/save_user_name.dart';
import '../../../features/auth/domain/usecases/sign_in.dart';
import '../../../features/auth/domain/usecases/sign_out.dart';
import '../../../features/auth/presentation/bloc/auth_cubit.dart';
import '../../../features/auth/presentation/bloc/login_cubit.dart';

void registerAuthModule(GetIt sl) {
  // Data — DataSources
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl(), sl(), sl(), sl()),
  );

  // Data — Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl(), sl()),
  );

  // Domain — UseCases
  sl.registerLazySingleton(() => SignIn(sl()));
  sl.registerLazySingleton(() => SignOut(sl()));
  sl.registerLazySingleton(() => GetCurrentUser(sl()));
  sl.registerLazySingleton(() => GetUserName(sl()));
  sl.registerLazySingleton(() => SaveUserName(sl()));
  sl.registerLazySingleton(() => CheckAutoLogin(sl()));

  // Presentation — Cubits
  sl.registerLazySingleton(() => AuthCubit());
  sl.registerFactory(() => LoginCubit(sl(), sl(), sl(), sl()));
}
