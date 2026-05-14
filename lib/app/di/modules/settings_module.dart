import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';

import '../../../features/settings/data/datasources/local/settings_local_data_source.dart';
import '../../../features/settings/data/datasources/local/settings_local_data_source_impl.dart';
import '../../../features/settings/data/datasources/remote/settings_remote_data_source.dart';
import '../../../features/settings/data/datasources/remote/settings_remote_data_source_impl.dart';
import '../../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../../features/settings/domain/repositories/settings_repository.dart';

/// Registers settings feature dependencies.
void registerSettingsModule(GetIt sl) {
  // Data — DataSources
  sl.registerLazySingleton<SettingsLocalDataSource>(
    () => SettingsLocalDataSourceImpl(sl()),
  );

  sl.registerLazySingleton<SettingsRemoteDataSource>(
    () => SettingsRemoteDataSourceImpl(sl<FirebaseFirestore>()),
  );

  // Data — Repository
  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(sl(), sl<SettingsRemoteDataSource>()),
  );
}
