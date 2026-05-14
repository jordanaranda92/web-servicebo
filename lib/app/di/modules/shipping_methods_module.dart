import 'package:get_it/get_it.dart';

import '../../../features/shipping_methods/data/datasources/shipping_method_firestore_data_source.dart';
import '../../../features/shipping_methods/data/datasources/shipping_method_firestore_data_source_impl.dart';
import '../../../features/shipping_methods/data/repositories/shipping_methods_repository_impl.dart';
import '../../../features/shipping_methods/domain/repositories/shipping_methods_repository.dart';
import '../../../features/shipping_methods/domain/usecases/add_shipping_method.dart';
import '../../../features/shipping_methods/domain/usecases/delete_shipping_method.dart';
import '../../../features/shipping_methods/domain/usecases/get_shipping_methods.dart';
import '../../../features/shipping_methods/domain/usecases/update_shipping_method.dart';
import '../../../features/shipping_methods/domain/usecases/update_shipping_method_phone.dart';
import '../../../features/shipping_methods/domain/usecases/watch_shipping_methods.dart';
import '../../../features/shipping_methods/presentation/bloc/shipping_methods_cubit.dart';

void registerShippingMethodsModule(GetIt sl) {
  // Data — DataSource
  sl.registerLazySingleton<ShippingMethodFirestoreDataSource>(
    () => ShippingMethodFirestoreDataSourceImpl(sl()),
  );

  // Data — Repository
  sl.registerLazySingleton<ShippingMethodsRepository>(
    () => ShippingMethodsRepositoryImpl(sl()),
  );

  // Domain — UseCases
  sl.registerLazySingleton(() => GetShippingMethods(sl()));
  sl.registerLazySingleton(() => WatchShippingMethods(sl()));
  sl.registerLazySingleton(() => AddShippingMethod(sl()));
  sl.registerLazySingleton(() => UpdateShippingMethod(sl()));
  sl.registerLazySingleton(() => UpdateShippingMethodPhone(sl()));
  sl.registerLazySingleton(() => DeleteShippingMethod(sl()));

  // Presentation — Cubits
  sl.registerFactory(() => ShippingMethodsCubit(sl(), sl(), sl(), sl(), sl()));
}
