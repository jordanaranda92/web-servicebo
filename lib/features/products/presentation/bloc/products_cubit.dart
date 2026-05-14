import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/fd_product.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/add_product.dart';
import '../../domain/usecases/delete_product.dart';
import '../../domain/usecases/get_fd_products.dart';
import '../../domain/usecases/link_fd_product.dart';
import '../../domain/usecases/save_products_batch.dart';
import '../../domain/usecases/watch_products.dart';
import 'products_state.dart';

class ProductsCubit extends Cubit<ProductsState> {
  final WatchProducts _watchProducts;
  final SaveProductsBatch _saveProductsBatch;
  final AddProduct _addProduct;
  final DeleteProduct _deleteProduct;
  final GetFdProducts _getFdProducts;
  final LinkFdProduct _linkFdProduct;

  StreamSubscription<Either<Failure, List<Product>>>? _productsSub;
  String _currentFilter = '';

  ProductsCubit(
    this._watchProducts,
    this._saveProductsBatch,
    this._addProduct,
    this._deleteProduct,
    this._getFdProducts,
    this._linkFdProduct,
  ) : super(const ProductsInitial());

  void watchProductsStream() {
    emit(const ProductsLoading());
    _productsSub?.cancel();
    _productsSub = _watchProducts().listen(
      (result) {
        result.fold(
          (failure) => emit(ProductsError(errorType: _mapFailure(failure))),
          (products) {
            final filtered = _applyFilter(products);
            emit(
              ProductsLoaded(
                allProducts: products,
                filteredProducts: filtered,
                nameFilter: _currentFilter,
              ),
            );
          },
        );
      },
      onError: (Object error) {
        emit(const ProductsError(errorType: ProductsErrorType.unknown));
      },
    );
  }

  List<Product> _applyFilter(List<Product> products) {
    final trimmed = _currentFilter.trim().toLowerCase();
    if (trimmed.isEmpty) return products;
    return products
        .where((p) => p.name.toLowerCase().contains(trimmed))
        .toList();
  }

  void filterByName(String query) {
    _currentFilter = query;
    final currentState = state;
    if (currentState is! ProductsLoaded) return;

    final filtered = _applyFilter(currentState.allProducts);
    emit(
      ProductsLoaded(
        allProducts: currentState.allProducts,
        filteredProducts: filtered,
        nameFilter: query,
      ),
    );
  }

  Future<bool> saveBatchChanges({
    Map<String, String> nameChanges = const {},
    Map<String, bool> activeToggles = const {},
    Map<String, int> orderChanges = const {},
  }) async {
    final result = await _saveProductsBatch(
      SaveProductsBatchParams(
        nameChanges: nameChanges,
        activeToggles: activeToggles,
        orderChanges: orderChanges,
      ),
    );
    return result.isRight();
  }

  ProductsErrorType _mapFailure(Failure failure) {
    if (failure is NetworkFailure) return ProductsErrorType.network;
    if (failure is ServerFailure) return ProductsErrorType.server;
    return ProductsErrorType.unknown;
  }

  Future<bool> addProduct(String name) async {
    final result = await _addProduct(AddProductParams(name: name));
    return result.isRight();
  }

  Future<bool> deleteProduct(String id) async {
    final result = await _deleteProduct(DeleteProductParams(id: id));
    return result.isRight();
  }

  Future<List<FdProduct>?> fetchFdProducts() async {
    final result = await _getFdProducts(NoParams());
    return result.fold((_) => null, (products) => products);
  }

  Future<bool> linkFdProduct({
    required String productId,
    required FdProduct fdProduct,
  }) async {
    final result = await _linkFdProduct(
      LinkFdProductParams(productId: productId, fdUuid: fdProduct.uuid),
    );
    return result.isRight();
  }

  Future<bool> unlinkFdProduct({required String productId}) async {
    final result = await _linkFdProduct(
      LinkFdProductParams(productId: productId, fdUuid: ''),
    );
    return result.isRight();
  }

  @override
  Future<void> close() {
    _productsSub?.cancel();
    return super.close();
  }
}
