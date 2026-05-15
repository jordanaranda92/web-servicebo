import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:get_it/get_it.dart';
import 'package:servicebo/app/config/app_config.dart';
import 'package:servicebo/core/data/datasources/factura_directa_api_data_source.dart';
import 'package:servicebo/core/data/datasources/factura_directa_api_data_source_impl.dart';
import 'package:servicebo/core/data/repositories/factura_directa_repository_impl.dart';
import 'package:servicebo/core/domain/repositories/factura_directa_repository.dart';
import 'package:servicebo/core/log/log.dart';
import 'package:servicebo/core/services/navigation_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Registers core / cross-cutting dependencies.
Future<void> registerCoreModule(
  GetIt sl, {
  bool firebaseAvailable = false,
}) async {
  final prefs = await SharedPreferences.getInstance();
  sl.registerLazySingleton<SharedPreferences>(() => prefs);

  final config = sl<AppConfig>();
  sl.registerLazySingleton<AppLogger>(
    () =>
        AppLogger(enabled: config.enableLogging, minLevel: config.logMinLevel),
  );

  sl.registerLazySingleton<FirebaseOperationsLogger>(
    () => FirebaseOperationsLogger(sl()),
  );

  // FacturaDirecta API DataSource
  sl.registerLazySingleton<FacturaDirectaApiDataSource>(
    () => FacturaDirectaApiDataSourceImpl(sl(), sl()),
  );

  // FacturaDirecta Repository
  sl.registerLazySingleton<FacturaDirectaRepository>(
    () => FacturaDirectaRepositoryImpl(sl()),
  );

  // Navigation guard (unsaved changes)
  sl.registerLazySingleton<NavigationGuard>(() => NavigationGuard());

  // Firebase services
  if (firebaseAvailable) {
    sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);

    sl.registerLazySingleton<FirebaseFirestore>(
      () => FirebaseFirestore.instance,
    );

    sl.registerLazySingleton<FirebaseDatabase>(
      () => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://application-servicebo-default-rtdb.europe-west1.firebasedatabase.app',
      ),
    );
  }
}
