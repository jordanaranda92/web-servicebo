import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/log/app_logger.dart';
import '../../../clients/data/datasources/client_firestore_data_source.dart';
import '../../../orders_today/data/datasources/remote/order_firestore_data_source.dart';
import '../../../orders_today/data/helpers/order_sheet_builder.dart';
import '../../../orders_today/domain/entities/order_sheet.dart';
import '../../../products/data/datasources/product_firestore_data_source.dart';
import '../../domain/entities/order_date_info.dart';
import '../../domain/repositories/orders_history_repository.dart';

class OrdersHistoryRepositoryImpl implements OrdersHistoryRepository {
  OrdersHistoryRepositoryImpl(
    this._firestoreDataSource,
    this._clientFirestore,
    this._productFirestore,
    this._logger,
  );

  final OrderFirestoreDataSource _firestoreDataSource;
  final ClientFirestoreDataSource _clientFirestore;
  final ProductFirestoreDataSource _productFirestore;
  final AppLogger _logger;

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<Either<Failure, List<OrderDateInfo>>> getAvailableDates() async {
    try {
      final docs = await _firestoreDataSource.getAllOrderDocuments();

      final today = _formatDate(DateTime.now());

      final dates = <OrderDateInfo>[];
      for (final doc in docs) {
        if (doc.date == today) continue;

        // Only include documents with valid date IDs
        final parsed = DateTime.tryParse(doc.date);
        if (parsed == null) continue;

        dates.add(
          OrderDateInfo(
            date: parsed,
            clientCount: doc.clientIds.length,
            productCount: doc.productIds.length,
          ),
        );
      }

      // Sort from most recent to oldest
      dates.sort((a, b) => b.date.compareTo(a.date));

      return Right(dates);
    } on ServerException catch (e) {
      _logger.error('Error loading available dates', e);
      return Left(ServerFailure());
    } catch (e, st) {
      _logger.error('Unexpected error loading available dates', e, st);
      return Left(InternalFailure());
    }
  }

  @override
  Future<Either<Failure, OrderSheet>> getHistoryOrders(DateTime date) async {
    try {
      final dateStr = _formatDate(date);
      final doc = await _firestoreDataSource.getOrderDocument(dateStr);
      if (doc == null) return Left(ServerFailure());

      final rows = await _firestoreDataSource.getOrderRows(dateStr);

      final allClients = await _clientFirestore.getAll();
      final allProducts = await _productFirestore.getAll();

      final clientNameMap = {for (final c in allClients) c.id: c.name};
      final productNameMap = {for (final p in allProducts) p.id: p.name};
      final productOrderMap = {for (final p in allProducts) p.id: p.order};

      return Right(
        buildOrderSheet(
          doc,
          rows,
          clientNameMap,
          productNameMap,
          productOrderMap,
        ),
      );
    } on ServerException catch (e) {
      _logger.error('Error loading history orders', e);
      return Left(ServerFailure());
    } catch (e, st) {
      _logger.error('Unexpected error loading history orders', e, st);
      return Left(InternalFailure());
    }
  }
}
