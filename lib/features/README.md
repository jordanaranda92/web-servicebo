# Features

Esta carpeta contiene los módulos de funcionalidad de la aplicación, organizados siguiendo Clean Architecture.

## Estructura de una Feature

```
features/
└── feature_name/
    ├── data/
    │   ├── datasources/
    │   ├── dto/
    │   ├── mappers/
    │   └── repositories/
    ├── domain/
    │   ├── entities/
    │   ├── repositories/
    │   └── usecases/
    └── presentation/
        ├── bloc/
        ├── pages/
        └── widgets/
```
