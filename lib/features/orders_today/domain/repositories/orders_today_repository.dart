import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/order_sheet.dart';

abstract class OrdersTodayRepository {
  Future<Either<Failure, OrderSheet?>> getTodayOrders(DateTime date);

  Future<Either<Failure, OrderSheet>> createTodaySheet(DateTime date);

  /// Updates a single cell (quantity or stock) in today's sheet.
  /// Pass [clientId] for quantity updates, or `null` for stock updates.
  Future<Either<Failure, Unit>> updateCell({
    required String productId,
    required String? clientId,
    required num value,
    required DateTime date,
  });

  /// Removes clients at the given indices from today's order and returns
  /// the refreshed [OrderSheet].
  Future<Either<Failure, OrderSheet>> removeClients({
    required List<int> clientIndices,
    required DateTime date,
  });

  /// Removes products at the given indices from today's order and returns
  /// the refreshed [OrderSheet].
  Future<Either<Failure, OrderSheet>> removeProducts({
    required List<int> productIndices,
    required DateTime date,
  });

  /// Returns active clients NOT already in today's order as (id, name) pairs.
  Future<Either<Failure, List<({String id, String name})>>> getAvailableClients(
    DateTime date,
  );

  /// Returns active products NOT already in today's order as (id, name) pairs.
  Future<Either<Failure, List<({String id, String name})>>>
  getAvailableProducts(DateTime date);

  /// Adds clients by their IDs to today's order and returns the refreshed
  /// [OrderSheet].
  Future<Either<Failure, OrderSheet>> addClients({
    required List<String> clientIds,
    required DateTime date,
  });

  /// Adds products by their IDs to today's order and returns the refreshed
  /// [OrderSheet].
  Future<Either<Failure, OrderSheet>> addProducts({
    required List<String> productIds,
    required DateTime date,
  });

  /// Stream that emits a new [OrderSheet] whenever the order data changes
  /// (structure or cell values) via Firestore listeners.
  Stream<OrderSheet?> watchTodayOrders(DateTime date);

  /// Updates a cell flag (compensation/reservation) or strict-stock flag.
  /// For quantity cell flags: pass [clientId] and [flagType]
  /// (`"compensation"`, `"reservation"`, or `null` to remove).
  /// For strict stock: pass [clientId] as `null` and [flagType] as
  /// `"strictStock"` to toggle on, or `null` to toggle off.
  Future<Either<Failure, Unit>> updateCellFlag({
    required String productId,
    required String? clientId,
    required String? flagType,
    required DateTime date,
  });

  /// Updates a note for a specific client–product cell.
  /// If [note] is `null` or empty, the note is removed.
  Future<Either<Failure, Unit>> updateCellNote({
    required String productId,
    required String clientId,
    required String? note,
    required DateTime date,
  });

  /// Updates a refund for a specific client–product cell.
  /// If [quantity] is `null` or <= 0, the refund is removed.
  Future<Either<Failure, Unit>> updateCellRefund({
    required String productId,
    required String clientId,
    required num? quantity,
    required DateTime date,
  });

  /// Resets all quantities for the given client indices to zero.
  Future<Either<Failure, OrderSheet>> resetClientOrders({
    required List<int> clientIndices,
    required DateTime date,
  });

  /// Marks a client as invoiced by the given user.
  Future<Either<Failure, Unit>> saveInvoicedBy({
    required String date,
    required String clientId,
    required String userId,
    required String userName,
    required String color,
  });

  /// Releases resources (e.g. catalogue cache subscriptions).
  void dispose();
}
