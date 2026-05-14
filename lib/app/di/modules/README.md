# Módulos de Inyección de Dependencias

Esta carpeta contiene los módulos de registro para el contenedor de inyección de dependencias (GetIt).

## Estructura

Cada feature debe tener su propio módulo de registro:

```
modules/
├── core_module.dart        # Dependencias transversales (SharedPreferences, etc.)
├── feature_a_module.dart   # Dependencias de Feature A
├── feature_b_module.dart   # Dependencias de Feature B
└── ...
```

## Patrón de Registro

```dart
import 'package:get_it/get_it.dart';

void registerFeatureModule(GetIt sl) {
  // DataSources
  sl.registerLazySingleton<FeatureRemoteDataSource>(
    () => FeatureRemoteDataSourceImpl(),
  );

  // Repositories
  sl.registerLazySingleton<FeatureRepository>(
    () => FeatureRepositoryImpl(sl()),
  );

  // UseCases
  sl.registerLazySingleton(() => GetFeatureUseCase(sl()));

  // BLoCs (siempre Factory, nunca Singleton)
  sl.registerFactory(() => FeatureBloc(sl()));
}
```

## Reglas

- **BLoCs**: Siempre `registerFactory` (nueva instancia por pantalla)
- **UseCases, Repositories, DataSources**: `registerLazySingleton`
- **Dependencias externas**: `registerLazySingleton` o async si requieren inicialización
