import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/shipping_method.dart';
import '../../domain/usecases/add_shipping_method.dart';
import '../../domain/usecases/delete_shipping_method.dart';
import '../../domain/usecases/update_shipping_method.dart';
import '../../domain/usecases/update_shipping_method_phone.dart';
import '../../domain/usecases/watch_shipping_methods.dart';
import 'shipping_methods_state.dart';

class ShippingMethodsCubit extends Cubit<ShippingMethodsState> {
  final WatchShippingMethods _watchShippingMethods;
  final AddShippingMethod _addShippingMethod;
  final UpdateShippingMethod _updateShippingMethod;
  final UpdateShippingMethodPhone _updateShippingMethodPhone;
  final DeleteShippingMethod _deleteShippingMethod;

  StreamSubscription<Either<Failure, List<ShippingMethod>>>? _methodsSub;
  String _currentFilter = '';

  ShippingMethodsCubit(
    this._watchShippingMethods,
    this._addShippingMethod,
    this._updateShippingMethod,
    this._updateShippingMethodPhone,
    this._deleteShippingMethod,
  ) : super(const ShippingMethodsInitial());

  void watchMethodsStream() {
    emit(const ShippingMethodsLoading());
    _methodsSub?.cancel();
    _methodsSub = _watchShippingMethods().listen(
      (result) {
        result.fold(
          (failure) =>
              emit(ShippingMethodsError(errorType: _mapFailure(failure))),
          (methods) {
            final filtered = _applyFilter(methods);
            emit(
              ShippingMethodsLoaded(
                allMethods: methods,
                filteredMethods: filtered,
                nameFilter: _currentFilter,
              ),
            );
          },
        );
      },
      onError: (Object error) {
        emit(
          const ShippingMethodsError(
            errorType: ShippingMethodsErrorType.unknown,
          ),
        );
      },
    );
  }

  List<ShippingMethod> _applyFilter(List<ShippingMethod> methods) {
    final trimmed = _currentFilter.trim().toLowerCase();
    if (trimmed.isEmpty) return methods;
    return methods
        .where((m) => m.name.toLowerCase().contains(trimmed))
        .toList();
  }

  void filterByName(String query) {
    _currentFilter = query;
    final currentState = state;
    if (currentState is! ShippingMethodsLoaded) return;
    final filtered = _applyFilter(currentState.allMethods);
    emit(
      ShippingMethodsLoaded(
        allMethods: currentState.allMethods,
        filteredMethods: filtered,
        nameFilter: query,
      ),
    );
  }

  Future<bool> addMethod(String name) async {
    final result = await _addShippingMethod(
      AddShippingMethodParams(name: name),
    );
    return result.isRight();
  }

  Future<bool> updateName(String id, String name) async {
    final result = await _updateShippingMethod(
      UpdateShippingMethodParams(id: id, name: name),
    );
    return result.isRight();
  }

  Future<bool> updatePhone(String id, String phone) async {
    final result = await _updateShippingMethodPhone(
      UpdateShippingMethodPhoneParams(id: id, phone: phone),
    );
    return result.isRight();
  }

  Future<bool> deleteMethod(String id) async {
    final result = await _deleteShippingMethod(
      DeleteShippingMethodParams(id: id),
    );
    return result.isRight();
  }

  ShippingMethodsErrorType _mapFailure(Failure failure) {
    if (failure is NetworkFailure) return ShippingMethodsErrorType.network;
    if (failure is ServerFailure) return ShippingMethodsErrorType.server;
    return ShippingMethodsErrorType.unknown;
  }

  @override
  Future<void> close() {
    _methodsSub?.cancel();
    return super.close();
  }
}
