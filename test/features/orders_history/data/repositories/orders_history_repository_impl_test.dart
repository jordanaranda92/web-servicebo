import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:servicebo/core/error/exceptions.dart';
import 'package:servicebo/core/error/failure.dart';
import 'package:servicebo/core/log/app_logger.dart';
import 'package:servicebo/features/clients/data/datasources/client_firestore_data_source.dart';
import 'package:servicebo/features/clients/data/models/client_model.dart';
import 'package:servicebo/features/orders_history/data/repositories/orders_history_repository_impl.dart';
import 'package:servicebo/features/orders_today/data/datasources/remote/order_firestore_data_source.dart';
import 'package:servicebo/features/orders_today/data/models/order_document_model.dart';
import 'package:servicebo/features/orders_today/data/models/order_row_model.dart';
import 'package:servicebo/features/products/data/datasources/product_firestore_data_source.dart';
import 'package:servicebo/features/products/data/models/product_model.dart';

class MockOrderFirestoreDataSource extends Mock
    implements OrderFirestoreDataSource {}

class MockClientFirestoreDataSource extends Mock
    implements ClientFirestoreDataSource {}

class MockProductFirestoreDataSource extends Mock
    implements ProductFirestoreDataSource {}

class MockAppLogger extends Mock implements AppLogger {}

void main() {
  late OrdersHistoryRepositoryImpl repository;
  late MockOrderFirestoreDataSource mockFirestoreDataSource;
  late MockClientFirestoreDataSource mockClientDataSource;
  late MockProductFirestoreDataSource mockProductDataSource;
  late MockAppLogger mockLogger;

  setUp(() {
    mockFirestoreDataSource = MockOrderFirestoreDataSource();
    mockClientDataSource = MockClientFirestoreDataSource();
    mockProductDataSource = MockProductFirestoreDataSource();
    mockLogger = MockAppLogger();
    repository = OrdersHistoryRepositoryImpl(
      mockFirestoreDataSource,
      mockClientDataSource,
      mockProductDataSource,
      mockLogger,
    );
  });

  final now = DateTime.now();
  final todayStr =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  final testDoc1 = OrderDocumentModel(
    date: '2026-05-10',
    createdAt: DateTime(2026, 5, 10),
    lastModifiedAt: DateTime(2026, 5, 10),
    clientIds: ['c1', 'c2'],
    productIds: ['p1'],
  );

  final testDoc2 = OrderDocumentModel(
    date: '2026-05-11',
    createdAt: DateTime(2026, 5, 11),
    lastModifiedAt: DateTime(2026, 5, 11),
    clientIds: ['c1'],
    productIds: ['p1', 'p2'],
  );

  final todayDoc = OrderDocumentModel(
    date: todayStr,
    createdAt: now,
    lastModifiedAt: now,
    clientIds: ['c1'],
    productIds: ['p1'],
  );

  const testClients = [
    ClientModel(
      id: 'c1',
      name: 'Cliente A',
      facturaDirectaUuid: '',
      facturaDirectaName: '',
    ),
    ClientModel(
      id: 'c2',
      name: 'Cliente B',
      facturaDirectaUuid: '',
      facturaDirectaName: '',
    ),
  ];

  const testProducts = [
    ProductModel(
      id: 'p1',
      name: 'Pan',
      facturaDirectaUuid: '',
      isActive: true,
      color: '#FF0000',
      order: 1,
    ),
    ProductModel(
      id: 'p2',
      name: 'Leche',
      facturaDirectaUuid: '',
      isActive: true,
      color: '#00FF00',
      order: 2,
    ),
  ];

  group('OrdersHistoryRepositoryImpl', () {
    group('getAvailableDates', () {
      test('returns dates excluding today, sorted descending', () async {
        when(
          () => mockFirestoreDataSource.getAllOrderDocuments(),
        ).thenAnswer((_) async => [testDoc1, todayDoc, testDoc2]);

        final result = await repository.getAvailableDates();

        result.fold((failure) => fail('Expected Right, got $failure'), (dates) {
          expect(dates.length, 2);
          expect(dates[0].date, DateTime(2026, 5, 11));
          expect(dates[0].clientCount, 1);
          expect(dates[0].productCount, 2);
          expect(dates[1].date, DateTime(2026, 5, 10));
          expect(dates[1].clientCount, 2);
          expect(dates[1].productCount, 1);
        });
      });

      test('returns empty list when only today exists', () async {
        when(
          () => mockFirestoreDataSource.getAllOrderDocuments(),
        ).thenAnswer((_) async => [todayDoc]);

        final result = await repository.getAvailableDates();

        result.fold(
          (failure) => fail('Expected Right'),
          (dates) => expect(dates, isEmpty),
        );
      });

      test('skips documents with invalid date IDs', () async {
        final invalidDoc = OrderDocumentModel(
          date: 'not-a-date',
          createdAt: now,
          lastModifiedAt: now,
          clientIds: [],
          productIds: [],
        );
        when(
          () => mockFirestoreDataSource.getAllOrderDocuments(),
        ).thenAnswer((_) async => [testDoc1, invalidDoc]);

        final result = await repository.getAvailableDates();

        result.fold(
          (failure) => fail('Expected Right'),
          (dates) => expect(dates.length, 1),
        );
      });

      test('returns ServerFailure on ServerException', () async {
        when(
          () => mockFirestoreDataSource.getAllOrderDocuments(),
        ).thenThrow(const ServerException(message: 'Error'));

        final result = await repository.getAvailableDates();

        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<ServerFailure>()),
          (_) => fail('Expected Left'),
        );
      });

      test('returns InternalFailure on unexpected error', () async {
        when(
          () => mockFirestoreDataSource.getAllOrderDocuments(),
        ).thenThrow(Exception('unexpected'));

        final result = await repository.getAvailableDates();

        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<InternalFailure>()),
          (_) => fail('Expected Left'),
        );
      });
    });

    group('getHistoryOrders', () {
      test('builds OrderSheet with resolved names', () async {
        when(
          () => mockFirestoreDataSource.getOrderDocument('2026-05-10'),
        ).thenAnswer((_) async => testDoc1);
        when(
          () => mockFirestoreDataSource.getOrderRows('2026-05-10'),
        ).thenAnswer(
          (_) async => [
            const OrderRowModel(
              productId: 'p1',
              quantities: {'c1': 5, 'c2': 3},
              stock: 10,
            ),
          ],
        );
        when(
          () => mockClientDataSource.getAll(),
        ).thenAnswer((_) async => testClients);
        when(
          () => mockProductDataSource.getAll(),
        ).thenAnswer((_) async => testProducts);

        final result = await repository.getHistoryOrders(DateTime(2026, 5, 10));

        result.fold((failure) => fail('Expected Right, got $failure'), (sheet) {
          expect(sheet.date, '2026-05-10');
          expect(sheet.clients, ['Cliente A', 'Cliente B']);
          expect(sheet.products, ['Pan']);
          expect(sheet.quantities, [
            [5, 3],
          ]);
          expect(sheet.pedidos, [8]);
          expect(sheet.stocks, [10]);
          expect(sheet.quedan, [2]);
        });
      });

      test('uses ID as fallback for deleted clients/products', () async {
        final docWithDeletedEntities = OrderDocumentModel(
          date: '2026-05-10',
          createdAt: DateTime(2026, 5, 10),
          lastModifiedAt: DateTime(2026, 5, 10),
          clientIds: ['c1', 'c_deleted'],
          productIds: ['p_deleted'],
        );
        when(
          () => mockFirestoreDataSource.getOrderDocument('2026-05-10'),
        ).thenAnswer((_) async => docWithDeletedEntities);
        when(
          () => mockFirestoreDataSource.getOrderRows('2026-05-10'),
        ).thenAnswer(
          (_) async => [
            const OrderRowModel(
              productId: 'p_deleted',
              quantities: {'c1': 2, 'c_deleted': 1},
              stock: 0,
            ),
          ],
        );
        when(
          () => mockClientDataSource.getAll(),
        ).thenAnswer((_) async => testClients);
        when(
          () => mockProductDataSource.getAll(),
        ).thenAnswer((_) async => testProducts);

        final result = await repository.getHistoryOrders(DateTime(2026, 5, 10));

        result.fold((failure) => fail('Expected Right'), (sheet) {
          expect(sheet.clients, ['Cliente A', 'c_deleted']);
          expect(sheet.products, ['p_deleted']);
        });
      });

      test('returns ServerFailure when document not found', () async {
        when(
          () => mockFirestoreDataSource.getOrderDocument('2026-05-10'),
        ).thenAnswer((_) async => null);

        final result = await repository.getHistoryOrders(DateTime(2026, 5, 10));

        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<ServerFailure>()),
          (_) => fail('Expected Left'),
        );
      });

      test('returns ServerFailure on ServerException', () async {
        when(
          () => mockFirestoreDataSource.getOrderDocument('2026-05-10'),
        ).thenThrow(const ServerException(message: 'Error'));

        final result = await repository.getHistoryOrders(DateTime(2026, 5, 10));

        expect(result.isLeft(), true);
        result.fold(
          (failure) => expect(failure, isA<ServerFailure>()),
          (_) => fail('Expected Left'),
        );
      });
    });
  });
}
