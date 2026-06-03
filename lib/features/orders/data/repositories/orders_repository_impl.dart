import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/log/app_logger.dart';
import '../../../clients/data/datasources/client_firestore_data_source.dart';
import '../../../clients/data/models/client_model.dart';
import '../../../products/data/datasources/product_firestore_data_source.dart';
import '../../../products/data/models/product_model.dart';
import '../../domain/entities/order_sheet.dart';
import '../../domain/repositories/orders_repository.dart';
import '../datasources/remote/order_firestore_data_source.dart';
import '../helpers/order_sheet_builder.dart';
import '../models/order_document_model.dart';
import '../models/order_row_model.dart';

class OrdersRepositoryImpl implements OrdersRepository {
  OrdersRepositoryImpl(
    this._firestoreDataSource,
    this._clientFirestore,
    this._productFirestore,
    this._logger,
  ) {
    _clientsSub = _clientFirestore.watchAll().listen(
      (_) => _cachedClients = null,
      onError: (Object e) => _logger.warning('Client watch error', e),
    );
    _productsSub = _productFirestore.watchAll().listen(
      (_) => _cachedProducts = null,
      onError: (Object e) => _logger.warning('Product watch error', e),
    );
  }

  final OrderFirestoreDataSource _firestoreDataSource;
  final ClientFirestoreDataSource _clientFirestore;
  final ProductFirestoreDataSource _productFirestore;
  final AppLogger _logger;

  // ── Catalogue watch subscriptions ───────────────────────────────
  late final StreamSubscription<List<ClientModel>> _clientsSub;
  late final StreamSubscription<List<ProductModel>> _productsSub;

  // ── In-memory catalogue cache (OPT-1) ───────────────────────────
  List<ClientModel>? _cachedClients;
  List<ProductModel>? _cachedProducts;

  Future<List<ClientModel>> _getClients() async {
    return _cachedClients ??= await _clientFirestore.getAll();
  }

  Future<List<ProductModel>> _getProducts() async {
    return _cachedProducts ??= await _productFirestore.getAll();
  }

  void _invalidateCache() {
    _cachedClients = null;
    _cachedProducts = null;
  }

  @override
  void dispose() {
    _clientsSub.cancel();
    _productsSub.cancel();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Sorts [ids] by the `order` field from [orderMap], falling back to
  /// [defaultSortOrder].
  List<String> _sortIdsByOrder(List<String> ids, Map<String, int?> orderMap) {
    return List<String>.from(ids)..sort(
      (a, b) => (orderMap[a] ?? defaultSortOrder).compareTo(
        orderMap[b] ?? defaultSortOrder,
      ),
    );
  }

  // ── getTodayOrders ──────────────────────────────────────────────

  @override
  Future<Either<Failure, OrderSheet?>> getTodayOrders(DateTime date) async {
    try {
      final dateStr = _formatDate(date);
      final doc = await _firestoreDataSource.getOrderDocument(dateStr);

      if (doc == null) return const Right(null);

      final rows = await _firestoreDataSource.getOrderRows(dateStr);

      // Read all clients/products for name resolution and ordering (cached)
      final allClients = await _getClients();
      final allProducts = await _getProducts();
      final clientNameMap = {for (final c in allClients) c.id: c.name};
      final productNameMap = {for (final p in allProducts) p.id: p.name};
      final productOrderMap = {for (final p in allProducts) p.id: p.order};

      return Right(
        _buildOrderSheet(
          doc,
          rows,
          clientNameMap,
          productNameMap,
          productOrderMap,
        ),
      );
    } on ServerException {
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      _logger.error('Error inesperado al obtener pedidos del día', e, st);
      return Left(InternalFailure());
    }
  }

  // ── createTodaySheet ────────────────────────────────────────────

  @override
  Future<Either<Failure, OrderSheet>> createTodaySheet(DateTime date) async {
    try {
      final dateStr = _formatDate(date);

      // Check if already exists (FA-01: duplicate creation)
      final existing = await _firestoreDataSource.getOrderDocument(dateStr);
      if (existing != null) {
        _logger.info(
          'createTodaySheet: document already exists for $dateStr, loading it',
        );
        final result = await getTodayOrders(date);
        return result.fold(
          (failure) => Left(failure),
          (sheet) => sheet != null ? Right(sheet) : Left(ServerFailure()),
        );
      }

      // Read active products (cached) — clients are NOT pre-loaded;
      // they will be added incrementally via addClients().
      final allClients = await _getClients();
      final allProducts = await _getProducts();

      final activeProducts = allProducts.where((p) => p.isActive).toList()
        ..sort(
          (a, b) => (a.order ?? defaultSortOrder).compareTo(
            b.order ?? defaultSortOrder,
          ),
        );

      final productIds = activeProducts.map((p) => p.id).toList();

      _logger.info(
        'createTodaySheet: 0 clients (added on demand), '
        '${activeProducts.length} products',
      );

      await _firestoreDataSource.createOrder(
        date: dateStr,
        clientIds: <String>[],
        productIds: productIds,
      );

      // Read back the created order
      final doc = await _firestoreDataSource.getOrderDocument(dateStr);
      if (doc == null) return Left(ServerFailure());

      final rows = await _firestoreDataSource.getOrderRows(dateStr);

      final clientNameMap = {for (final c in allClients) c.id: c.name};
      final productNameMap = {for (final p in allProducts) p.id: p.name};
      final productOrderMap = {for (final p in allProducts) p.id: p.order};

      return Right(
        _buildOrderSheet(
          doc,
          rows,
          clientNameMap,
          productNameMap,
          productOrderMap,
        ),
      );
    } on ServerException {
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      _logger.error('Error inesperado al crear pedido del día', e, st);
      return Left(InternalFailure());
    }
  }

  // ── updateCell ──────────────────────────────────────────────────

  @override
  Future<Either<Failure, Unit>> updateCell({
    required String productId,
    required String? clientId,
    required num value,
    required DateTime date,
  }) async {
    try {
      final dateStr = _formatDate(date);
      if (clientId != null) {
        await _firestoreDataSource.updateQuantity(
          date: dateStr,
          productId: productId,
          clientId: clientId,
          value: value,
        );
      } else {
        await _firestoreDataSource.updateStock(
          date: dateStr,
          productId: productId,
          value: value,
        );
      }
      return const Right(unit);
    } on ServerException {
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      _logger.error('Error updating cell', e, st);
      return Left(ServerFailure());
    }
  }

  // ── updateCellFlag ──────────────────────────────────────────────

  @override
  Future<Either<Failure, Unit>> updateCellFlag({
    required String productId,
    required String? clientId,
    required String? flagType,
    required DateTime date,
  }) async {
    try {
      final dateStr = _formatDate(date);
      if (clientId != null) {
        // Quantity cell flag (compensation / reservation)
        await _firestoreDataSource.updateFlag(
          date: dateStr,
          productId: productId,
          clientId: clientId,
          flagType: flagType,
        );
      } else {
        // Strict stock flag
        await _firestoreDataSource.updateStrictStock(
          date: dateStr,
          productId: productId,
          strictStock: flagType == 'strictStock',
        );
      }
      return const Right(unit);
    } on ServerException {
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      _logger.error('Error updating cell flag', e, st);
      return Left(ServerFailure());
    }
  }

  // ── updateProductMark ───────────────────────────────────────────

  @override
  Future<Either<Failure, Unit>> updateProductMark({
    required String productId,
    required String? productMark,
    required DateTime date,
  }) async {
    try {
      final dateStr = _formatDate(date);
      await _firestoreDataSource.updateProductMark(
        date: dateStr,
        productId: productId,
        productMark: productMark,
      );
      return const Right(unit);
    } on ServerException {
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      _logger.error('Error updating product mark', e, st);
      return Left(ServerFailure());
    }
  }

  // ── updateCellNote ──────────────────────────────────────────────

  @override
  Future<Either<Failure, Unit>> updateCellNote({
    required String productId,
    required String clientId,
    required String? note,
    required DateTime date,
  }) async {
    try {
      final dateStr = _formatDate(date);
      await _firestoreDataSource.updateNote(
        date: dateStr,
        productId: productId,
        clientId: clientId,
        note: note,
      );
      return const Right(unit);
    } on ServerException {
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      _logger.error('Error updating cell note', e, st);
      return Left(ServerFailure());
    }
  }

  // ── updateCellRefund ────────────────────────────────────────────

  @override
  Future<Either<Failure, Unit>> updateCellRefund({
    required String productId,
    required String clientId,
    required num? quantity,
    required DateTime date,
  }) async {
    try {
      final dateStr = _formatDate(date);
      await _firestoreDataSource.updateRefund(
        date: dateStr,
        productId: productId,
        clientId: clientId,
        quantity: quantity,
      );
      return const Right(unit);
    } on ServerException {
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      _logger.error('Error updating cell refund', e, st);
      return Left(ServerFailure());
    }
  }

  // ── resetClientOrders ───────────────────────────────────────────

  @override
  Future<Either<Failure, OrderSheet>> resetClientOrders({
    required List<int> clientIndices,
    required DateTime date,
  }) async {
    try {
      final dateStr = _formatDate(date);
      final doc = await _firestoreDataSource.getOrderDocument(dateStr);
      if (doc == null) return Left(ServerFailure());

      final orderedClientIds = List<String>.from(doc.clientIds);

      final clientIdsToReset = <String>[];
      for (final idx in clientIndices) {
        if (idx < orderedClientIds.length) {
          clientIdsToReset.add(orderedClientIds[idx]);
        }
      }

      if (clientIdsToReset.isEmpty) return Left(ServerFailure());

      await _firestoreDataSource.resetClientOrders(
        date: dateStr,
        clientIds: clientIdsToReset,
      );

      return _readOrderSheetWithoutSync(dateStr);
    } on ServerException {
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      _logger.error('Error resetting client orders', e, st);
      return Left(InternalFailure());
    }
  }

  // ── saveInvoicedBy ──────────────────────────────────────────────

  @override
  Future<Either<Failure, Unit>> saveInvoicedBy({
    required String date,
    required String clientId,
    required String userId,
    required String userName,
    required String color,
  }) async {
    try {
      await _firestoreDataSource.updateInvoicedBy(
        date: date,
        clientId: clientId,
        userId: userId,
        userName: userName,
        color: color,
      );
      return const Right(unit);
    } on ServerException {
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      _logger.error('Error saving invoicedBy', e, st);
      return Left(InternalFailure());
    }
  }
  // ── updateClientNote ─────────────────────────────────────────────

  @override
  Future<Either<Failure, Unit>> updateClientNote({
    required String clientId,
    required String? note,
    required DateTime date,
  }) async {
    try {
      final dateStr = _formatDate(date);
      await _firestoreDataSource.updateClientNote(
        date: dateStr,
        clientId: clientId,
        note: note,
      );
      return const Right(unit);
    } on ServerException {
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      _logger.error('Error updating client note', e, st);
      return Left(ServerFailure());
    }
  }
  // ── Private helpers ─────────────────────────────────────────────

  OrderSheet _buildOrderSheet(
    OrderDocumentModel doc,
    List<OrderRowModel> rows,
    Map<String, String> clientNameMap,
    Map<String, String> productNameMap,
    Map<String, int?> productOrderMap,
  ) {
    return buildOrderSheet(
      doc,
      rows,
      clientNameMap,
      productNameMap,
      productOrderMap,
    );
  }

  // ── removeClients ───────────────────────────────────────────────

  @override
  Future<Either<Failure, OrderSheet>> removeClients({
    required List<int> clientIndices,
    required DateTime date,
  }) async {
    try {
      final dateStr = _formatDate(date);
      final doc = await _firestoreDataSource.getOrderDocument(dateStr);
      if (doc == null) return Left(ServerFailure());

      // Use insertion order (same as UI display order)
      final orderedClientIds = List<String>.from(doc.clientIds);

      // Translate indices to IDs
      final clientIdsToRemove = <String>[];
      for (final idx in clientIndices) {
        if (idx < orderedClientIds.length) {
          clientIdsToRemove.add(orderedClientIds[idx]);
        }
      }

      if (clientIdsToRemove.isEmpty) return Left(ServerFailure());

      await _firestoreDataSource.removeClients(
        date: dateStr,
        clientIds: clientIdsToRemove,
      );

      // Re-read WITHOUT syncing to avoid re-adding removed entities
      return _readOrderSheetWithoutSync(dateStr);
    } on ServerException {
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      _logger.error('Error removing clients', e, st);
      return Left(InternalFailure());
    }
  }

  // ── removeProducts ──────────────────────────────────────────────

  @override
  Future<Either<Failure, OrderSheet>> removeProducts({
    required List<int> productIndices,
    required DateTime date,
  }) async {
    try {
      final dateStr = _formatDate(date);
      final doc = await _firestoreDataSource.getOrderDocument(dateStr);
      if (doc == null) return Left(ServerFailure());

      // Sort IDs by order field to match UI display order
      final allProducts = await _getProducts();
      final productOrderMap = {for (final p in allProducts) p.id: p.order};
      final sortedProductIds = _sortIdsByOrder(doc.productIds, productOrderMap);

      // Translate indices to IDs
      final productIdsToRemove = <String>[];
      for (final idx in productIndices) {
        if (idx < sortedProductIds.length) {
          productIdsToRemove.add(sortedProductIds[idx]);
        }
      }

      if (productIdsToRemove.isEmpty) return Left(ServerFailure());

      await _firestoreDataSource.removeProducts(
        date: dateStr,
        productIds: productIdsToRemove,
      );

      // Re-read WITHOUT syncing to avoid re-adding removed entities
      return _readOrderSheetWithoutSync(dateStr);
    } on ServerException {
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      _logger.error('Error removing products', e, st);
      return Left(InternalFailure());
    }
  }

  /// Reads the order sheet for [dateStr] without running [syncActiveEntities].
  /// Used after intentional removals to prevent re-adding deleted entities.
  Future<Either<Failure, OrderSheet>> _readOrderSheetWithoutSync(
    String dateStr,
  ) async {
    final updatedDoc = await _firestoreDataSource.getOrderDocument(dateStr);
    if (updatedDoc == null) return Left(ServerFailure());

    final rows = await _firestoreDataSource.getOrderRows(dateStr);
    final allClients = await _getClients();
    final allProducts = await _getProducts();
    final clientNameMap = {for (final c in allClients) c.id: c.name};
    final productNameMap = {for (final p in allProducts) p.id: p.name};
    final productOrderMap = {for (final p in allProducts) p.id: p.order};

    return Right(
      _buildOrderSheet(
        updatedDoc,
        rows,
        clientNameMap,
        productNameMap,
        productOrderMap,
      ),
    );
  }

  // ── getAvailableClients ─────────────────────────────────────────

  @override
  Future<Either<Failure, List<({String id, String name})>>> getAvailableClients(
    DateTime date,
  ) async {
    try {
      final dateStr = _formatDate(date);
      final doc = await _firestoreDataSource.getOrderDocument(dateStr);
      final currentIds = doc?.clientIds.toSet() ?? <String>{};

      final allClients = await _getClients();
      final available =
          allClients.where((c) => !currentIds.contains(c.id)).toList()..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

      return Right(available.map((c) => (id: c.id, name: c.name)).toList());
    } on Exception catch (e, st) {
      _logger.error('Error getting available clients', e, st);
      return Left(InternalFailure());
    }
  }

  // ── getAvailableProducts ────────────────────────────────────────

  @override
  Future<Either<Failure, List<({String id, String name})>>>
  getAvailableProducts(DateTime date) async {
    try {
      final dateStr = _formatDate(date);
      final doc = await _firestoreDataSource.getOrderDocument(dateStr);
      final currentIds = doc?.productIds.toSet() ?? <String>{};

      final allProducts = await _getProducts();
      final available =
          allProducts
              .where((p) => p.isActive && !currentIds.contains(p.id))
              .toList()
            ..sort(
              (a, b) => (a.order ?? defaultSortOrder).compareTo(
                b.order ?? defaultSortOrder,
              ),
            );

      return Right(available.map((p) => (id: p.id, name: p.name)).toList());
    } on Exception catch (e, st) {
      _logger.error('Error getting available products', e, st);
      return Left(InternalFailure());
    }
  }

  // ── addClients ──────────────────────────────────────────────────

  @override
  Future<Either<Failure, OrderSheet>> addClients({
    required List<String> clientIds,
    required DateTime date,
  }) async {
    try {
      final dateStr = _formatDate(date);
      await _firestoreDataSource.addClients(
        date: dateStr,
        clientIds: clientIds,
      );
      return _readOrderSheetWithoutSync(dateStr);
    } on Exception catch (e, st) {
      _logger.error('Error adding clients', e, st);
      return Left(InternalFailure());
    }
  }

  // ── addProducts ─────────────────────────────────────────────────

  @override
  Future<Either<Failure, OrderSheet>> addProducts({
    required List<String> productIds,
    required DateTime date,
  }) async {
    try {
      final dateStr = _formatDate(date);
      await _firestoreDataSource.addProducts(
        date: dateStr,
        productIds: productIds,
      );
      return _readOrderSheetWithoutSync(dateStr);
    } on Exception catch (e, st) {
      _logger.error('Error adding products', e, st);
      return Left(InternalFailure());
    }
  }

  // ── replaceClient ───────────────────────────────────────────────

  @override
  Future<Either<Failure, OrderSheet>> replaceClient({
    required int clientIndex,
    required String newClientId,
    required DateTime date,
  }) async {
    try {
      final dateStr = _formatDate(date);
      final doc = await _firestoreDataSource.getOrderDocument(dateStr);
      if (doc == null) return Left(ServerFailure());

      final orderedClientIds = List<String>.from(doc.clientIds);
      if (clientIndex >= orderedClientIds.length) {
        return Left(ServerFailure());
      }

      final oldClientId = orderedClientIds[clientIndex];

      await _firestoreDataSource.replaceClient(
        date: dateStr,
        oldClientId: oldClientId,
        newClientId: newClientId,
      );

      return _readOrderSheetWithoutSync(dateStr);
    } on ServerException {
      return Left(ServerFailure());
    } on Exception catch (e, st) {
      _logger.error('Error replacing client', e, st);
      return Left(InternalFailure());
    }
  }

  // ── watchTodayOrders ──────────────────────────────────────────

  @override
  Stream<OrderSheet?> watchTodayOrders(DateTime date) {
    final dateStr = _formatDate(date);

    // Cache for name/order maps — refreshed when IDs change
    Map<String, String> clientNameMap = {};
    Map<String, String> productNameMap = {};
    Map<String, int?> productOrderMap = {};
    List<String>? prevClientIds;
    List<String>? prevProductIds;

    Future<void> refreshMaps() async {
      _invalidateCache();
      final allClients = await _getClients();
      final allProducts = await _getProducts();
      clientNameMap = {for (final c in allClients) c.id: c.name};
      productNameMap = {for (final p in allProducts) p.id: p.name};
      productOrderMap = {for (final p in allProducts) p.id: p.order};
    }

    final docStream = _firestoreDataSource.watchOrderDocument(dateStr);
    final rowsStream = _firestoreDataSource.watchOrderRows(dateStr);

    return Rx.combineLatest2<
          OrderDocumentModel?,
          List<OrderRowModel>,
          (OrderDocumentModel?, List<OrderRowModel>)
        >(docStream, rowsStream, (doc, rows) => (doc, rows))
        .debounceTime(const Duration(milliseconds: 200))
        .asyncMap((pair) async {
          final (doc, rows) = pair;
          if (doc == null) return null;

          // Refresh name/order maps when structure changes
          final idsChanged =
              prevClientIds == null ||
              prevProductIds == null ||
              !_listEquals(doc.clientIds, prevClientIds!) ||
              !_listEquals(doc.productIds, prevProductIds!);

          if (idsChanged) {
            await refreshMaps();
            prevClientIds = List<String>.from(doc.clientIds);
            prevProductIds = List<String>.from(doc.productIds);
          }

          return _buildOrderSheet(
            doc,
            rows,
            clientNameMap,
            productNameMap,
            productOrderMap,
          );
        })
        .handleError((Object e, StackTrace st) {
          _logger.error('Error in watchTodayOrders stream', e, st);
        });
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
