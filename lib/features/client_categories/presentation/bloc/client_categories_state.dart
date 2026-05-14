import 'package:equatable/equatable.dart';

import '../../../clients/domain/entities/client_category.dart';

abstract class ClientCategoriesState extends Equatable {
  const ClientCategoriesState();

  @override
  List<Object?> get props => [];
}

class ClientCategoriesInitial extends ClientCategoriesState {
  const ClientCategoriesInitial();
}

class ClientCategoriesLoading extends ClientCategoriesState {
  const ClientCategoriesLoading();
}

class ClientCategoriesLoaded extends ClientCategoriesState {
  final List<ClientCategory> allCategories;
  final List<ClientCategory> filteredCategories;
  final String nameFilter;
  final bool isSaving;

  const ClientCategoriesLoaded({
    required this.allCategories,
    required this.filteredCategories,
    this.nameFilter = '',
    this.isSaving = false,
  });

  List<ClientCategory> get categories => filteredCategories;

  @override
  List<Object?> get props => [
    allCategories,
    filteredCategories,
    nameFilter,
    isSaving,
  ];
}

class ClientCategoriesError extends ClientCategoriesState {
  final ClientCategoriesErrorType errorType;

  const ClientCategoriesError({required this.errorType});

  @override
  List<Object?> get props => [errorType];
}

enum ClientCategoriesErrorType { configNotFound, network, server, unknown }
