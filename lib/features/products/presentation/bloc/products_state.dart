import 'package:equatable/equatable.dart';

import '../../domain/entities/product.dart';

abstract class ProductsState extends Equatable {
  const ProductsState();

  @override
  List<Object?> get props => [];
}

class ProductsInitial extends ProductsState {
  const ProductsInitial();
}

class ProductsLoading extends ProductsState {
  const ProductsLoading();
}

class ProductsLoaded extends ProductsState {
  final List<Product> allProducts;
  final List<Product> filteredProducts;
  final String nameFilter;
  final bool isSaving;

  const ProductsLoaded({
    required this.allProducts,
    required this.filteredProducts,
    this.nameFilter = '',
    this.isSaving = false,
  });

  @override
  List<Object?> get props => [
    allProducts,
    filteredProducts,
    nameFilter,
    isSaving,
  ];
}

class ProductsError extends ProductsState {
  final ProductsErrorType errorType;

  const ProductsError({required this.errorType});

  @override
  List<Object?> get props => [errorType];
}

enum ProductsErrorType { network, server, unknown }
