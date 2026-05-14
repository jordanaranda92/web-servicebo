import 'package:get_it/get_it.dart';

import '../../../features/products/data/datasources/product_firestore_data_source.dart';
import '../../../features/products/data/datasources/product_firestore_data_source_impl.dart';
import '../../../features/products/data/repositories/products_repository_impl.dart';
import '../../../features/products/domain/repositories/products_repository.dart';
import '../../../features/products/domain/usecases/add_product.dart';
import '../../../features/products/domain/usecases/delete_product.dart';
import '../../../features/products/domain/usecases/get_fd_products.dart';
import '../../../features/products/domain/usecases/link_fd_product.dart';
import '../../../features/products/domain/usecases/save_products_batch.dart';
import '../../../features/products/domain/usecases/watch_products.dart';
import '../../../features/products/presentation/bloc/products_cubit.dart';

void registerProductsModule(GetIt sl) {
  // Data — DataSources
  sl.registerLazySingleton<ProductFirestoreDataSource>(
    () => ProductFirestoreDataSourceImpl(sl()),
  );

  // Data — Repository
  sl.registerLazySingleton<ProductsRepository>(
    () => ProductsRepositoryImpl(sl(), sl(), sl()),
  );

  // Domain — UseCases
  sl.registerLazySingleton(() => WatchProducts(sl()));
  sl.registerLazySingleton(() => SaveProductsBatch(sl()));
  sl.registerLazySingleton(() => AddProduct(sl()));
  sl.registerLazySingleton(() => DeleteProduct(sl()));
  sl.registerLazySingleton(() => GetFdProducts(sl()));
  sl.registerLazySingleton(() => LinkFdProduct(sl()));

  // Presentation — Cubits
  sl.registerFactory(() => ProductsCubit(sl(), sl(), sl(), sl(), sl(), sl()));
}
