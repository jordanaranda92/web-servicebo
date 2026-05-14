import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:servicebo/core/error/failure.dart';
import 'package:servicebo/features/orders_today/domain/entities/order_sheet.dart';
import 'package:servicebo/core/usecase/usecase.dart';
import 'package:servicebo/features/orders_history/domain/entities/order_date_info.dart';
import 'package:servicebo/features/orders_history/domain/usecases/get_available_dates.dart';
import 'package:servicebo/features/orders_history/domain/usecases/get_history_orders.dart';
import 'package:servicebo/features/orders_history/presentation/bloc/orders_history_bloc.dart';
import 'package:servicebo/features/orders_history/presentation/bloc/orders_history_event.dart';
import 'package:servicebo/features/orders_history/presentation/bloc/orders_history_state.dart';

class MockGetAvailableDates extends Mock implements GetAvailableDates {}

class MockGetHistoryOrders extends Mock implements GetHistoryOrders {}

void main() {
  late MockGetAvailableDates mockGetAvailableDates;
  late MockGetHistoryOrders mockGetHistoryOrders;

  setUp(() {
    mockGetAvailableDates = MockGetAvailableDates();
    mockGetHistoryOrders = MockGetHistoryOrders();
    registerFallbackValue(NoParams());
    registerFallbackValue(GetHistoryOrdersParams(date: DateTime(2026)));
  });

  OrdersHistoryBloc buildBloc() => OrdersHistoryBloc(
    getAvailableDates: mockGetAvailableDates,
    getHistoryOrders: mockGetHistoryOrders,
  );

  final testDates = [
    OrderDateInfo(date: DateTime(2026, 5, 4), clientCount: 3, productCount: 5),
    OrderDateInfo(date: DateTime(2026, 5, 3), clientCount: 2, productCount: 4),
    OrderDateInfo(date: DateTime(2026, 5, 1), clientCount: 1, productCount: 3),
  ];

  const testSheet = OrderSheet(
    date: '',
    clients: ['Cliente A'],
    products: ['Pan', 'Leche'],
    quantities: [
      [5],
      [3],
    ],
    pedidos: [5, 3],
    stocks: [0, 0],
    quedan: [0, 0],
    clientOrders: [0],
  );

  group('OrdersHistoryBloc', () {
    test('initial state is OrdersHistoryInitial', () {
      expect(buildBloc().state, const OrdersHistoryInitial());
    });

    group('OrdersHistoryLoadDates', () {
      blocTest<OrdersHistoryBloc, OrdersHistoryState>(
        'emits [Loading, DatesLoaded] when dates are found',
        build: () {
          when(
            () => mockGetAvailableDates(any()),
          ).thenAnswer((_) async => Right(testDates));
          return buildBloc();
        },
        act: (bloc) => bloc.add(const OrdersHistoryLoadDates()),
        expect: () => [
          const OrdersHistoryLoading(),
          OrdersHistoryDatesLoaded(
            allDates: testDates,
            filteredDates: testDates,
          ),
        ],
      );

      blocTest<OrdersHistoryBloc, OrdersHistoryState>(
        'emits [Loading, Empty] when no dates are found',
        build: () {
          when(
            () => mockGetAvailableDates(any()),
          ).thenAnswer((_) async => const Right([]));
          return buildBloc();
        },
        act: (bloc) => bloc.add(const OrdersHistoryLoadDates()),
        expect: () => [
          const OrdersHistoryLoading(),
          const OrdersHistoryEmpty(),
        ],
      );

      blocTest<OrdersHistoryBloc, OrdersHistoryState>(
        'emits [Loading, Error] on failure',
        build: () {
          when(
            () => mockGetAvailableDates(any()),
          ).thenAnswer((_) async => Left(ServerFailure()));
          return buildBloc();
        },
        act: (bloc) => bloc.add(const OrdersHistoryLoadDates()),
        expect: () => [
          const OrdersHistoryLoading(),
          const OrdersHistoryError(
            errorType: OrdersHistoryErrorType.serverError,
          ),
        ],
      );
    });

    group('OrdersHistoryDateSelected', () {
      blocTest<OrdersHistoryBloc, OrdersHistoryState>(
        'emits [DetailLoading, DetailLoaded] when sheet is loaded',
        build: () {
          when(
            () => mockGetAvailableDates(any()),
          ).thenAnswer((_) async => Right(testDates));
          when(
            () => mockGetHistoryOrders(any()),
          ).thenAnswer((_) async => const Right(testSheet));
          return buildBloc();
        },
        act: (bloc) async {
          bloc.add(const OrdersHistoryLoadDates());
          await Future<void>.delayed(Duration.zero);
          bloc.add(OrdersHistoryDateSelected(date: DateTime(2026, 5, 4)));
        },
        skip: 2, // Skip Loading + DatesLoaded
        expect: () => [
          OrdersHistoryDetailLoading(selectedDate: DateTime(2026, 5, 4)),
          OrdersHistoryDetailLoaded(
            selectedDate: DateTime(2026, 5, 4),
            orderSheet: testSheet,
            allDates: testDates,
          ),
        ],
      );

      blocTest<OrdersHistoryBloc, OrdersHistoryState>(
        'emits [DetailLoading, Error] on failure',
        build: () {
          when(
            () => mockGetAvailableDates(any()),
          ).thenAnswer((_) async => Right(testDates));
          when(
            () => mockGetHistoryOrders(any()),
          ).thenAnswer((_) async => Left(ServerFailure()));
          return buildBloc();
        },
        act: (bloc) async {
          bloc.add(const OrdersHistoryLoadDates());
          await Future<void>.delayed(Duration.zero);
          bloc.add(OrdersHistoryDateSelected(date: DateTime(2026, 5, 4)));
        },
        skip: 2,
        expect: () => [
          OrdersHistoryDetailLoading(selectedDate: DateTime(2026, 5, 4)),
          const OrdersHistoryError(
            errorType: OrdersHistoryErrorType.serverError,
          ),
        ],
      );
    });

    group('OrdersHistoryDateRangeChanged', () {
      blocTest<OrdersHistoryBloc, OrdersHistoryState>(
        'filters dates by range',
        build: () {
          when(
            () => mockGetAvailableDates(any()),
          ).thenAnswer((_) async => Right(testDates));
          return buildBloc();
        },
        act: (bloc) async {
          bloc.add(const OrdersHistoryLoadDates());
          await Future<void>.delayed(Duration.zero);
          bloc.add(
            OrdersHistoryDateRangeChanged(
              start: DateTime(2026, 5, 3),
              end: DateTime(2026, 5, 4),
            ),
          );
        },
        skip: 2,
        expect: () => [
          OrdersHistoryDatesLoaded(
            allDates: testDates,
            filteredDates: [testDates[0], testDates[1]],
            startDate: DateTime(2026, 5, 3),
            endDate: DateTime(2026, 5, 4),
          ),
        ],
      );

      blocTest<OrdersHistoryBloc, OrdersHistoryState>(
        'clears filter when start and end are null',
        build: () {
          when(
            () => mockGetAvailableDates(any()),
          ).thenAnswer((_) async => Right(testDates));
          return buildBloc();
        },
        act: (bloc) async {
          bloc.add(const OrdersHistoryLoadDates());
          await Future<void>.delayed(Duration.zero);
          bloc.add(
            OrdersHistoryDateRangeChanged(
              start: DateTime(2026, 5, 3),
              end: DateTime(2026, 5, 4),
            ),
          );
          await Future<void>.delayed(Duration.zero);
          bloc.add(const OrdersHistoryDateRangeChanged());
        },
        skip: 3,
        expect: () => [
          OrdersHistoryDatesLoaded(
            allDates: testDates,
            filteredDates: testDates,
          ),
        ],
      );
    });

    group('OrdersHistoryBackToList', () {
      blocTest<OrdersHistoryBloc, OrdersHistoryState>(
        'returns to dates loaded state from detail',
        build: () {
          when(
            () => mockGetAvailableDates(any()),
          ).thenAnswer((_) async => Right(testDates));
          when(
            () => mockGetHistoryOrders(any()),
          ).thenAnswer((_) async => const Right(testSheet));
          return buildBloc();
        },
        act: (bloc) async {
          bloc.add(const OrdersHistoryLoadDates());
          await Future<void>.delayed(Duration.zero);
          bloc.add(OrdersHistoryDateSelected(date: DateTime(2026, 5, 4)));
          await Future<void>.delayed(Duration.zero);
          bloc.add(const OrdersHistoryBackToList());
        },
        skip: 4,
        expect: () => [
          OrdersHistoryDatesLoaded(
            allDates: testDates,
            filteredDates: testDates,
          ),
        ],
      );
    });

    group('OrdersHistorySearchChanged', () {
      blocTest<OrdersHistoryBloc, OrdersHistoryState>(
        'updates search filter in detail loaded state',
        build: () {
          when(
            () => mockGetAvailableDates(any()),
          ).thenAnswer((_) async => Right(testDates));
          when(
            () => mockGetHistoryOrders(any()),
          ).thenAnswer((_) async => const Right(testSheet));
          return buildBloc();
        },
        act: (bloc) async {
          bloc.add(const OrdersHistoryLoadDates());
          await Future<void>.delayed(Duration.zero);
          bloc.add(OrdersHistoryDateSelected(date: DateTime(2026, 5, 4)));
          await Future<void>.delayed(Duration.zero);
          bloc.add(const OrdersHistorySearchChanged(query: 'Cliente'));
        },
        skip: 4,
        expect: () => [
          OrdersHistoryDetailLoaded(
            selectedDate: DateTime(2026, 5, 4),
            orderSheet: testSheet,
            searchFilter: 'Cliente',
            allDates: testDates,
          ),
        ],
      );
    });
  });
}
