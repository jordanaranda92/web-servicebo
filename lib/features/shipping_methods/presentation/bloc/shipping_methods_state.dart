import 'package:equatable/equatable.dart';

import '../../domain/entities/shipping_method.dart';

abstract class ShippingMethodsState extends Equatable {
  const ShippingMethodsState();

  @override
  List<Object?> get props => [];
}

class ShippingMethodsInitial extends ShippingMethodsState {
  const ShippingMethodsInitial();
}

class ShippingMethodsLoading extends ShippingMethodsState {
  const ShippingMethodsLoading();
}

class ShippingMethodsLoaded extends ShippingMethodsState {
  final List<ShippingMethod> allMethods;
  final List<ShippingMethod> filteredMethods;
  final String nameFilter;

  const ShippingMethodsLoaded({
    required this.allMethods,
    required this.filteredMethods,
    this.nameFilter = '',
  });

  List<ShippingMethod> get methods => filteredMethods;

  @override
  List<Object?> get props => [allMethods, filteredMethods, nameFilter];
}

class ShippingMethodsError extends ShippingMethodsState {
  final ShippingMethodsErrorType errorType;

  const ShippingMethodsError({required this.errorType});

  @override
  List<Object?> get props => [errorType];
}

enum ShippingMethodsErrorType { network, server, unknown }
