import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/usecases/add_client_category.dart';
import '../../domain/usecases/delete_client_category.dart';
import '../../domain/usecases/update_client_category.dart';
import '../../domain/usecases/watch_client_categories.dart';
import '../../../clients/domain/entities/client_category.dart';
import 'client_categories_state.dart';

class ClientCategoriesCubit extends Cubit<ClientCategoriesState> {
  final WatchClientCategories _watchClientCategories;
  final AddClientCategory _addClientCategory;
  final UpdateClientCategory _updateClientCategory;
  final DeleteClientCategory _deleteClientCategory;

  StreamSubscription<Either<Failure, List<ClientCategory>>>? _categoriesSub;
  String _currentFilter = '';

  ClientCategoriesCubit(
    this._watchClientCategories,
    this._addClientCategory,
    this._updateClientCategory,
    this._deleteClientCategory,
  ) : super(const ClientCategoriesInitial());

  void watchCategoriesStream() {
    emit(const ClientCategoriesLoading());
    _categoriesSub?.cancel();
    _categoriesSub = _watchClientCategories().listen(
      (result) {
        result.fold(
          (failure) =>
              emit(ClientCategoriesError(errorType: _mapFailure(failure))),
          (categories) {
            final filtered = _applyFilter(categories);
            emit(
              ClientCategoriesLoaded(
                allCategories: categories,
                filteredCategories: filtered,
                nameFilter: _currentFilter,
              ),
            );
          },
        );
      },
      onError: (Object error) {
        emit(
          const ClientCategoriesError(
            errorType: ClientCategoriesErrorType.unknown,
          ),
        );
      },
    );
  }

  List<ClientCategory> _applyFilter(List<ClientCategory> categories) {
    final trimmed = _currentFilter.trim().toLowerCase();
    if (trimmed.isEmpty) return categories;
    return categories
        .where((c) => c.name.toLowerCase().contains(trimmed))
        .toList();
  }

  Future<bool> addCategory(String name, {String? color}) async {
    final result = await _addClientCategory(
      AddClientCategoryParams(name: name, color: color),
    );
    return result.isRight();
  }

  ClientCategoriesErrorType _mapFailure(Failure failure) {
    if (failure is ConfigNotFoundFailure) {
      return ClientCategoriesErrorType.configNotFound;
    }
    if (failure is NetworkFailure) return ClientCategoriesErrorType.network;
    if (failure is ServerFailure) return ClientCategoriesErrorType.server;
    return ClientCategoriesErrorType.unknown;
  }

  Future<bool> updateCategory(String id, String name, {String? color}) async {
    final result = await _updateClientCategory(
      UpdateClientCategoryParams(id: id, name: name, color: color),
    );
    return result.isRight();
  }

  Future<bool> deleteCategory(String id) async {
    final result = await _deleteClientCategory(
      DeleteClientCategoryParams(id: id),
    );
    return result.isRight();
  }

  Future<bool> saveBatchChanges({
    required Map<String, String> nameChanges,
  }) async {
    for (final entry in nameChanges.entries) {
      final result = await _updateClientCategory(
        UpdateClientCategoryParams(id: entry.key, name: entry.value),
      );
      if (result.isLeft()) return false;
    }

    return true;
  }

  void filterByName(String query) {
    _currentFilter = query;
    final currentState = state;
    if (currentState is! ClientCategoriesLoaded) return;

    final filtered = _applyFilter(currentState.allCategories);
    emit(
      ClientCategoriesLoaded(
        allCategories: currentState.allCategories,
        filteredCategories: filtered,
        nameFilter: query,
      ),
    );
  }

  @override
  Future<void> close() {
    _categoriesSub?.cancel();
    return super.close();
  }
}
