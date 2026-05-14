import 'package:get_it/get_it.dart';

import '../../../features/client_categories/data/datasources/client_category_firestore_data_source.dart';
import '../../../features/client_categories/data/datasources/client_category_firestore_data_source_impl.dart';
import '../../../features/client_categories/data/repositories/client_categories_repository_impl.dart';
import '../../../features/client_categories/domain/repositories/client_categories_repository.dart';
import '../../../features/client_categories/domain/usecases/add_client_category.dart';
import '../../../features/client_categories/domain/usecases/delete_client_category.dart';
import '../../../features/client_categories/domain/usecases/get_client_categories.dart';
import '../../../features/client_categories/domain/usecases/update_client_category.dart';
import '../../../features/client_categories/domain/usecases/watch_client_categories.dart';
import '../../../features/client_categories/presentation/bloc/client_categories_cubit.dart';

void registerClientCategoriesModule(GetIt sl) {
  // Data — DataSource
  sl.registerLazySingleton<ClientCategoryFirestoreDataSource>(
    () => ClientCategoryFirestoreDataSourceImpl(sl()),
  );

  // Data — Repository
  sl.registerLazySingleton<ClientCategoriesRepository>(
    () => ClientCategoriesRepositoryImpl(sl()),
  );

  // Domain — UseCases
  sl.registerLazySingleton(() => GetClientCategories(sl()));
  sl.registerLazySingleton(() => WatchClientCategories(sl()));
  sl.registerLazySingleton(() => AddClientCategory(sl()));
  sl.registerLazySingleton(() => UpdateClientCategory(sl()));
  sl.registerLazySingleton(() => DeleteClientCategory(sl()));

  // Presentation — Cubits
  sl.registerFactory(() => ClientCategoriesCubit(sl(), sl(), sl(), sl()));
}
