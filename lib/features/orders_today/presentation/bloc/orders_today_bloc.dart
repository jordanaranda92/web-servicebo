import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/log/app_logger.dart';
import '../../domain/entities/order_sheet.dart';
import '../../domain/repositories/orders_today_repository.dart';
import '../../domain/usecases/add_order_clients.dart';
import '../../domain/usecases/add_order_products.dart';
import '../../domain/usecases/create_today_file.dart';
import '../../domain/usecases/get_today_orders.dart';
import '../../domain/usecases/remove_order_clients.dart';
import '../../domain/usecases/remove_order_products.dart';
import '../../domain/usecases/replace_order_client.dart';
import '../../domain/usecases/reset_client_orders.dart';
import '../../domain/usecases/update_cell_flag.dart';
import '../../domain/usecases/update_cell_note.dart';
import '../../domain/usecases/update_cell_refund.dart';
import '../../domain/usecases/update_client_note.dart';
import '../../domain/usecases/update_order_cell.dart';
import 'orders_today_event.dart';
import 'orders_today_state.dart';

class OrdersTodayBloc extends Bloc<OrdersTodayEvent, OrdersTodayState> {
  OrdersTodayBloc({
    required GetTodayOrders getTodayOrders,
    required CreateTodayFile createTodayFile,
    required UpdateOrderCell updateOrderCell,
    required UpdateCellFlag updateCellFlag,
    required UpdateCellNote updateCellNote,
    required UpdateCellRefund updateCellRefund,
    required UpdateClientNote updateClientNote,
    required ResetClientOrders resetClientOrders,
    required RemoveOrderClients removeOrderClients,
    required RemoveOrderProducts removeOrderProducts,
    required AddOrderClients addOrderClients,
    required AddOrderProducts addOrderProducts,
    required ReplaceOrderClient replaceOrderClient,
    required OrdersTodayRepository repository,
    required AppLogger logger,
  }) : _getTodayOrders = getTodayOrders,
       _createTodayFile = createTodayFile,
       _updateOrderCell = updateOrderCell,
       _updateCellFlag = updateCellFlag,
       _updateCellNote = updateCellNote,
       _updateCellRefund = updateCellRefund,
       _updateClientNote = updateClientNote,
       _resetClientOrders = resetClientOrders,
       _removeOrderClients = removeOrderClients,
       _removeOrderProducts = removeOrderProducts,
       _addOrderClients = addOrderClients,
       _addOrderProducts = addOrderProducts,
       _replaceOrderClient = replaceOrderClient,
       _repository = repository,
       _logger = logger,
       super(const OrdersTodayInitial()) {
    on<OrdersTodayLoadRequested>(_onLoad);
    on<OrdersTodayCreateFileRequested>(_onCreateFile);
    on<OrdersTodayRefreshRequested>(_onRefresh);
    on<OrdersTodayCellUpdateRequested>(_onCellUpdate);
    on<OrdersTodayRemoteOrderUpdated>(_onRemoteOrderUpdate);
    on<OrdersTodayRemoveClientsRequested>(_onRemoveClients);
    on<OrdersTodayRemoveProductsRequested>(_onRemoveProducts);
    on<OrdersTodayAddClientsRequested>(_onAddClients);
    on<OrdersTodayAddProductsRequested>(_onAddProducts);
    on<OrdersTodayCellFlagUpdateRequested>(_onCellFlagUpdate);
    on<OrdersTodayCellNoteUpdateRequested>(_onCellNoteUpdate);
    on<OrdersTodayCellRefundUpdateRequested>(_onCellRefundUpdate);
    on<OrdersTodayResetOrdersRequested>(_onResetOrders);
    on<OrdersTodaySaveInvoicedByRequested>(_onSaveInvoicedBy);
    on<OrdersTodayClientNoteUpdateRequested>(_onClientNoteUpdate);
    on<OrdersTodayReplaceClientRequested>(_onReplaceClient);
  }

  final GetTodayOrders _getTodayOrders;
  final CreateTodayFile _createTodayFile;
  final UpdateOrderCell _updateOrderCell;
  final UpdateCellFlag _updateCellFlag;
  final UpdateCellNote _updateCellNote;
  final UpdateCellRefund _updateCellRefund;
  final UpdateClientNote _updateClientNote;
  final ResetClientOrders _resetClientOrders;
  final RemoveOrderClients _removeOrderClients;
  final RemoveOrderProducts _removeOrderProducts;
  final AddOrderClients _addOrderClients;
  final AddOrderProducts _addOrderProducts;
  final ReplaceOrderClient _replaceOrderClient;
  final OrdersTodayRepository _repository;
  final AppLogger _logger;

  StreamSubscription<OrderSheet?>? _watchSub;

  /// Debounce timer for batching Firestore writes.
  Timer? _syncTimer;

  /// Pending write — stores the latest params to write.
  UpdateOrderCellParams? _pendingWrite;

  /// Snapshot of the optimistic cell change applied locally while a write is
  /// pending. Used to re-apply the pending change on top of any remote update
  /// that arrives before the write completes.
  OrdersTodayCellUpdateRequested? _pendingOptimisticEvent;

  Future<void> _onLoad(
    OrdersTodayLoadRequested event,
    Emitter<OrdersTodayState> emit,
  ) async {
    emit(const OrdersTodayLoading());
    await _loadOrders(emit, createIfMissing: event.createIfMissing);
  }

  Future<void> _onCreateFile(
    OrdersTodayCreateFileRequested event,
    Emitter<OrdersTodayState> emit,
  ) async {
    emit(const OrdersTodayLoading());
    final result = await _createTodayFile(
      CreateTodayFileParams(date: DateTime.now()),
    );
    result.fold(
      (failure) => emit(OrdersTodayError(errorType: _mapFailure(failure))),
      (sheet) => emit(OrdersTodayLoaded(orderSheet: sheet)),
    );
  }

  Future<void> _onRefresh(
    OrdersTodayRefreshRequested event,
    Emitter<OrdersTodayState> emit,
  ) async {
    emit(const OrdersTodayLoading());
    await _loadOrders(emit);
  }

  Future<void> _loadOrders(
    Emitter<OrdersTodayState> emit, {
    bool createIfMissing = true,
  }) async {
    final result = await _getTodayOrders(
      GetTodayOrdersParams(date: DateTime.now()),
    );
    await result.fold(
      (failure) async =>
          emit(OrdersTodayError(errorType: _mapFailure(failure))),
      (sheet) async {
        if (sheet == null) {
          if (!createIfMissing) {
            emit(const OrdersTodayNoFile());
            return;
          }
          _cancelWatch();
          emit(const OrdersTodayCreating());

          final createFuture = _createTodayFile(
            CreateTodayFileParams(date: DateTime.now()),
          );
          final delayFuture = Future<void>.delayed(const Duration(seconds: 3));

          final createResult = await createFuture;

          // If error, emit immediately without waiting for delay
          if (createResult.isLeft()) {
            createResult.fold(
              (failure) =>
                  emit(OrdersTodayError(errorType: _mapFailure(failure))),
              (_) {},
            );
            return;
          }

          // If success, wait for minimum delay to complete
          await delayFuture;

          createResult.fold((_) {}, (createdSheet) {
            _startWatch();
            emit(OrdersTodayLoaded(orderSheet: createdSheet));
          });
        } else {
          _startWatch();
          emit(OrdersTodayLoaded(orderSheet: sheet));
        }
      },
    );
  }

  void _startWatch() {
    _cancelWatch();
    _watchSub = _repository
        .watchTodayOrders(DateTime.now())
        .listen(
          (sheet) => add(OrdersTodayRemoteOrderUpdated(orderSheet: sheet)),
          onError: (Object e) => _logger.warning('Watch stream error', e),
        );
  }

  void _cancelWatch() {
    _watchSub?.cancel();
    _watchSub = null;
  }

  OrdersTodayErrorType _mapFailure(Failure failure) {
    if (failure is FileSystemFailure) {
      return OrdersTodayErrorType.templateNotFound;
    }
    if (failure is EntityMappingFailure) {
      return OrdersTodayErrorType.invalidFormat;
    }
    if (failure is ConfigNotFoundFailure) {
      return OrdersTodayErrorType.driveNotConfigured;
    }
    if (failure is ServerFailure) {
      return OrdersTodayErrorType.configNotAvailable;
    }
    return OrdersTodayErrorType.unknown;
  }

  Future<void> _onCellUpdate(
    OrdersTodayCellUpdateRequested event,
    Emitter<OrdersTodayState> emit,
  ) async {
    final current = state;
    if (current is! OrdersTodayLoaded) return;

    final sheet = current.orderSheet;
    final numClients = sheet.clients.length;

    // No-op: skip if value hasn't changed (avoids unnecessary Firestore write)
    final isStocksColCheck = event.clientCol == numClients + 1;
    if (isStocksColCheck) {
      if (event.productRow < sheet.stocks.length &&
          sheet.stocks[event.productRow] == event.value) {
        return;
      }
    } else {
      if (event.productRow < sheet.quantities.length &&
          event.clientCol < sheet.quantities[event.productRow].length &&
          sheet.quantities[event.productRow][event.clientCol] == event.value) {
        return;
      }
    }

    // Optimistic update: apply changes locally and emit immediately
    final optimistic = _applyOptimisticUpdate(sheet, event);
    emit(OrdersTodayLoaded(orderSheet: optimistic));

    // Translate UI indices to Firestore IDs
    if (event.productRow >= sheet.productIds.length) return;
    final productId = sheet.productIds[event.productRow];

    final isStocksCol = event.clientCol == numClients + 1;
    final String? clientId;
    if (isStocksCol) {
      clientId = null;
    } else {
      if (event.clientCol >= sheet.clientIds.length) return;
      clientId = sheet.clientIds[event.clientCol];
    }

    // Sync immediately with Firestore
    _pendingWrite = UpdateOrderCellParams(
      productId: productId,
      clientId: clientId,
      value: event.value,
      date: DateTime.now(),
    );
    _pendingOptimisticEvent = event;
    _syncTimer?.cancel();
    _flushPendingWrite();
  }

  void _flushPendingWrite() {
    final params = _pendingWrite;
    if (params == null) return;
    _pendingWrite = null;
    _pendingOptimisticEvent = null;

    _updateOrderCell(params).then((result) {
      if (isClosed) return;
      result.fold(
        (failure) => _logger.warning('Firestore sync failed', failure),
        (_) {
          // Do NOT overwrite local state with server response —
          // Firestore listener will handle propagation to other users.
        },
      );
    });
  }

  OrderSheet _applyOptimisticUpdate(
    OrderSheet sheet,
    OrdersTodayCellUpdateRequested event,
  ) {
    final numClients = sheet.clients.length;
    final isStocksCol = event.clientCol == numClients + 1;
    final row = event.productRow;

    // Shallow-copy only the affected row instead of the entire matrix (P1)
    final newQuantities = List<List<num>>.from(sheet.quantities);
    final newStocks = List<num>.from(sheet.stocks);

    if (isStocksCol) {
      if (row < newStocks.length) {
        newStocks[row] = event.value;
      }
    } else if (row < newQuantities.length &&
        event.clientCol < newQuantities[row].length) {
      newQuantities[row] = List<num>.from(newQuantities[row]);
      newQuantities[row][event.clientCol] = event.value;
    }

    // Recalculate pedidos and quedan for the affected row only
    final newPedidos = List<num>.from(sheet.pedidos);
    final newQuedan = List<num>.from(sheet.quedan);

    if (row < newQuantities.length) {
      final totalQty = newQuantities[row].fold<num>(0, (a, b) => a + b);
      final totalRefunds = row < sheet.cellRefunds.length
          ? sheet.cellRefunds[row].values.fold<num>(0, (a, b) => a + b)
          : 0;
      newPedidos[row] = totalQty + totalRefunds;
      newQuedan[row] = newStocks[row] - newPedidos[row];
    }

    return sheet.copyWith(
      quantities: newQuantities,
      pedidos: newPedidos,
      stocks: newStocks,
      quedan: newQuedan,
    );
  }

  Future<void> _onRemoteOrderUpdate(
    OrdersTodayRemoteOrderUpdated event,
    Emitter<OrdersTodayState> emit,
  ) async {
    if (event.orderSheet == null) {
      // Document was deleted
      _cancelWatch();
      emit(const OrdersTodayNoFile());
      return;
    }

    var orderSheet = event.orderSheet;
    if (orderSheet == null) return;

    // If there is a pending write, re-apply the optimistic change on top of
    // the remote data so the local edit is not visually lost.
    final pendingEvent = _pendingOptimisticEvent;
    if (pendingEvent != null) {
      orderSheet = _applyOptimisticUpdate(orderSheet, pendingEvent);
    }

    final current = state;
    if (current is OrdersTodayLoaded && current.orderSheet == orderSheet) {
      // Deduplicate: same data (e.g. own optimistic update confirmed)
      return;
    }

    emit(OrdersTodayLoaded(orderSheet: orderSheet));
  }

  Future<void> _onResetOrders(
    OrdersTodayResetOrdersRequested event,
    Emitter<OrdersTodayState> emit,
  ) async {
    final current = state;
    if (current is! OrdersTodayLoaded) return;

    final result = await _resetClientOrders(
      ResetClientOrdersParams(
        clientIndices: event.clientIndices,
        date: DateTime.now(),
      ),
    );

    result.fold(
      (failure) => _logger.warning('Failed to reset client orders', failure),
      (sheet) => emit(OrdersTodayLoaded(orderSheet: sheet)),
    );
  }

  Future<void> _onRemoveClients(
    OrdersTodayRemoveClientsRequested event,
    Emitter<OrdersTodayState> emit,
  ) async {
    final current = state;
    if (current is! OrdersTodayLoaded) return;

    final result = await _removeOrderClients(
      RemoveOrderClientsParams(
        clientIndices: event.clientIndices,
        date: DateTime.now(),
      ),
    );

    result.fold(
      (failure) => _logger.warning('Failed to remove clients', failure),
      (sheet) => emit(OrdersTodayLoaded(orderSheet: sheet)),
    );
  }

  Future<void> _onRemoveProducts(
    OrdersTodayRemoveProductsRequested event,
    Emitter<OrdersTodayState> emit,
  ) async {
    final current = state;
    if (current is! OrdersTodayLoaded) return;

    final result = await _removeOrderProducts(
      RemoveOrderProductsParams(
        productIndices: event.productIndices,
        date: DateTime.now(),
      ),
    );

    result.fold(
      (failure) => _logger.warning('Failed to remove products', failure),
      (sheet) => emit(OrdersTodayLoaded(orderSheet: sheet)),
    );
  }

  Future<void> _onAddClients(
    OrdersTodayAddClientsRequested event,
    Emitter<OrdersTodayState> emit,
  ) async {
    final current = state;
    if (current is! OrdersTodayLoaded) return;

    final result = await _addOrderClients(
      AddOrderClientsParams(clientIds: event.clientIds, date: DateTime.now()),
    );

    result.fold(
      (failure) => _logger.warning('Failed to add clients', failure),
      (sheet) => emit(OrdersTodayLoaded(orderSheet: sheet)),
    );
  }

  Future<void> _onAddProducts(
    OrdersTodayAddProductsRequested event,
    Emitter<OrdersTodayState> emit,
  ) async {
    final current = state;
    if (current is! OrdersTodayLoaded) return;

    final result = await _addOrderProducts(
      AddOrderProductsParams(
        productIds: event.productIds,
        date: DateTime.now(),
      ),
    );

    result.fold(
      (failure) => _logger.warning('Failed to add products', failure),
      (sheet) => emit(OrdersTodayLoaded(orderSheet: sheet)),
    );
  }

  // ── Optimistic write helper ──────────────────────────────────────

  /// Applies an optimistic update to the UI, then writes to Firestore.
  /// Reverts to the original [sheet] if the write fails.
  Future<void> _optimisticWrite({
    required Emitter<OrdersTodayState> emit,
    required OrderSheet sheet,
    required OrderSheet optimistic,
    required Future<Either<Failure, Unit>> Function() write,
    required String failureMessage,
  }) async {
    emit(OrdersTodayLoaded(orderSheet: optimistic));
    final result = await write();
    result.fold((failure) {
      _logger.warning(failureMessage, failure);
      emit(OrdersTodayLoaded(orderSheet: sheet));
    }, (_) {});
  }

  Future<void> _onCellFlagUpdate(
    OrdersTodayCellFlagUpdateRequested event,
    Emitter<OrdersTodayState> emit,
  ) async {
    final current = state;
    if (current is! OrdersTodayLoaded) return;

    final sheet = current.orderSheet;
    if (event.productRow >= sheet.productIds.length) return;

    final productId = sheet.productIds[event.productRow];

    // Determine clientId and effective flag
    final String? clientId;
    final String? effectiveFlag;
    if (event.clientCol != null) {
      // Quantity cell flag
      final col = event.clientCol!;
      if (col >= sheet.clientIds.length) return;
      clientId = sheet.clientIds[col];
      effectiveFlag = event.flagType;
    } else {
      // Strict stock flag
      clientId = null;
      effectiveFlag = event.flagType;
    }

    // Optimistic update + write
    await _optimisticWrite(
      emit: emit,
      sheet: sheet,
      optimistic: _applyOptimisticFlagUpdate(sheet, event),
      write: () => _updateCellFlag(
        UpdateCellFlagParams(
          productId: productId,
          clientId: clientId,
          flagType: effectiveFlag,
          date: DateTime.now(),
        ),
      ),
      failureMessage: 'Failed to update cell flag',
    );
  }

  OrderSheet _applyOptimisticFlagUpdate(
    OrderSheet sheet,
    OrdersTodayCellFlagUpdateRequested event,
  ) {
    if (event.clientCol != null) {
      // Quantity cell flag
      final newCellFlags = List<Map<String, String>>.generate(
        sheet.cellFlags.length,
        (i) => Map<String, String>.from(sheet.cellFlags[i]),
      );
      if (event.productRow < newCellFlags.length) {
        final clientId = sheet.clientIds[event.clientCol!];
        if (event.flagType == null) {
          newCellFlags[event.productRow].remove(clientId);
        } else {
          newCellFlags[event.productRow][clientId] = event.flagType!;
        }
      }
      return sheet.copyWith(cellFlags: newCellFlags);
    } else {
      // Strict stock flag
      final newStrictStocks = List<bool>.from(sheet.strictStocks);
      if (event.productRow < newStrictStocks.length) {
        newStrictStocks[event.productRow] = event.flagType == 'strictStock';
      }
      return sheet.copyWith(strictStocks: newStrictStocks);
    }
  }

  // ── Cell Note Update ───────────────────────────────────────────

  Future<void> _onCellNoteUpdate(
    OrdersTodayCellNoteUpdateRequested event,
    Emitter<OrdersTodayState> emit,
  ) async {
    final current = state;
    if (current is! OrdersTodayLoaded) return;

    final sheet = current.orderSheet;
    if (event.productRow >= sheet.productIds.length) return;
    if (event.clientCol >= sheet.clientIds.length) return;

    final productId = sheet.productIds[event.productRow];
    final clientId = sheet.clientIds[event.clientCol];

    // Optimistic update
    final newCellNotes = List<Map<String, String>>.generate(
      sheet.cellNotes.length,
      (i) => Map<String, String>.from(sheet.cellNotes[i]),
    );
    if (event.productRow < newCellNotes.length) {
      final note = event.note;
      if (note == null || note.isEmpty) {
        newCellNotes[event.productRow].remove(clientId);
      } else {
        newCellNotes[event.productRow][clientId] = note;
      }
    }

    await _optimisticWrite(
      emit: emit,
      sheet: sheet,
      optimistic: sheet.copyWith(cellNotes: newCellNotes),
      write: () => _updateCellNote(
        UpdateCellNoteParams(
          productId: productId,
          clientId: clientId,
          note: event.note,
          date: DateTime.now(),
        ),
      ),
      failureMessage: 'Failed to update cell note',
    );
  }

  // ── Cell Refund Update ─────────────────────────────────────────

  Future<void> _onCellRefundUpdate(
    OrdersTodayCellRefundUpdateRequested event,
    Emitter<OrdersTodayState> emit,
  ) async {
    final current = state;
    if (current is! OrdersTodayLoaded) return;

    final sheet = current.orderSheet;
    if (event.productRow >= sheet.productIds.length) return;
    if (event.clientCol >= sheet.clientIds.length) return;

    final productId = sheet.productIds[event.productRow];
    final clientId = sheet.clientIds[event.clientCol];

    // Optimistic update
    final newCellRefunds = List<Map<String, num>>.generate(
      sheet.cellRefunds.length,
      (i) => Map<String, num>.from(sheet.cellRefunds[i]),
    );
    if (event.productRow < newCellRefunds.length) {
      if (event.quantity == null || event.quantity! <= 0) {
        newCellRefunds[event.productRow].remove(clientId);
      } else {
        newCellRefunds[event.productRow][clientId] = event.quantity!;
      }
    }

    // Recalculate pedidos and quedan for affected row
    final row = event.productRow;
    final newPedidos = List<num>.from(sheet.pedidos);
    final newQuedan = List<num>.from(sheet.quedan);
    if (row < sheet.quantities.length) {
      final totalQty = sheet.quantities[row].fold<num>(0, (a, b) => a + b);
      final totalRefunds = newCellRefunds[row].values.fold<num>(
        0,
        (a, b) => a + b,
      );
      newPedidos[row] = totalQty + totalRefunds;
      newQuedan[row] = sheet.stocks[row] - newPedidos[row];
    }

    await _optimisticWrite(
      emit: emit,
      sheet: sheet,
      optimistic: sheet.copyWith(
        cellRefunds: newCellRefunds,
        pedidos: newPedidos,
        quedan: newQuedan,
      ),
      write: () => _updateCellRefund(
        UpdateCellRefundParams(
          productId: productId,
          clientId: clientId,
          quantity: event.quantity,
          date: DateTime.now(),
        ),
      ),
      failureMessage: 'Failed to update cell refund',
    );
  }

  Future<void> _onSaveInvoicedBy(
    OrdersTodaySaveInvoicedByRequested event,
    Emitter<OrdersTodayState> emit,
  ) async {
    final currentState = state;
    if (currentState is! OrdersTodayLoaded) return;
    await _repository.saveInvoicedBy(
      date: currentState.orderSheet.date,
      clientId: event.clientId,
      userId: event.userId,
      userName: event.userName,
      color: event.color,
    );
  }
  // ── Client Note Update ─────────────────────────────────────────

  Future<void> _onClientNoteUpdate(
    OrdersTodayClientNoteUpdateRequested event,
    Emitter<OrdersTodayState> emit,
  ) async {
    final current = state;
    if (current is! OrdersTodayLoaded) return;

    final sheet = current.orderSheet;
    if (event.clientCol >= sheet.clientIds.length) return;

    final clientId = sheet.clientIds[event.clientCol];

    // Optimistic update
    final newClientNotes = Map<String, String>.from(sheet.clientNotes);
    final note = event.note;
    if (note == null || note.isEmpty) {
      newClientNotes.remove(clientId);
    } else {
      newClientNotes[clientId] = note;
    }

    await _optimisticWrite(
      emit: emit,
      sheet: sheet,
      optimistic: sheet.copyWith(clientNotes: newClientNotes),
      write: () => _updateClientNote(
        UpdateClientNoteParams(
          clientId: clientId,
          note: event.note,
          date: DateTime.now(),
        ),
      ),
      failureMessage: 'Failed to update client note',
    );
  }

  Future<void> _onReplaceClient(
    OrdersTodayReplaceClientRequested event,
    Emitter<OrdersTodayState> emit,
  ) async {
    final current = state;
    if (current is! OrdersTodayLoaded) return;

    final result = await _replaceOrderClient(
      ReplaceOrderClientParams(
        clientIndex: event.clientCol,
        newClientId: event.newClientId,
        date: DateTime.now(),
      ),
    );

    result.fold(
      (failure) => _logger.warning('Failed to replace client', failure),
      (sheet) => emit(OrdersTodayLoaded(orderSheet: sheet)),
    );
  }

  @override
  Future<void> close() async {
    _syncTimer?.cancel();
    // Flush any pending write before closing
    final params = _pendingWrite;
    if (params != null) {
      _pendingWrite = null;
      await _updateOrderCell(params);
    }
    _cancelWatch();
    return super.close();
  }

  // ── Public helpers for UI queries ───────────────────────────────

  /// Returns active clients NOT already in today's order.
  Future<List<({String id, String name})>> getAvailableClients() async {
    final result = await _repository.getAvailableClients(DateTime.now());
    return result.getOrElse((_) => []);
  }

  /// Returns active products NOT already in today's order.
  Future<List<({String id, String name})>> getAvailableProducts() async {
    final result = await _repository.getAvailableProducts(DateTime.now());
    return result.getOrElse((_) => []);
  }
}
