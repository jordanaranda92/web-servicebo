import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:servicebo/core/error/failure.dart';
import 'package:servicebo/features/statistics/presentation/bloc/fd_counters_cubit.dart';
import 'package:servicebo/features/statistics/presentation/bloc/fd_counters_state.dart';
import 'package:servicebo/features/invoices/domain/entities/invoice.dart';
import 'package:servicebo/features/invoices/domain/usecases/get_invoices_by_date_range.dart';

class MockGetInvoicesByDateRange extends Mock
    implements GetInvoicesByDateRange {}

Invoice _inv(String date, double total) =>
    Invoice(id: 'id-$date-$total', docNumber: 'F001', date: date, total: total);

void main() {
  late MockGetInvoicesByDateRange mockGetInvoicesByDateRange;

  setUpAll(() {
    registerFallbackValue(
      const DateRangeParams(minDate: '2026-01-01', maxDate: '2026-01-31'),
    );
  });

  setUp(() {
    mockGetInvoicesByDateRange = MockGetInvoicesByDateRange();
  });

  FdCountersCubit buildCubit() =>
      FdCountersCubit(getInvoicesByDateRange: mockGetInvoicesByDateRange);

  group('FdCountersCubit', () {
    test('initial state is FdCountersInitial', () {
      final cubit = buildCubit();
      expect(cubit.state, const FdCountersInitial());
      cubit.close();
    });

    blocTest<FdCountersCubit, FdCountersState>(
      'emits [Loading, Loaded] with correct counters on success',
      build: () {
        when(() => mockGetInvoicesByDateRange(any())).thenAnswer((
          invocation,
        ) async {
          final params = invocation.positionalArguments[0] as DateRangeParams;
          final now = DateTime.now();
          final todayStr =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          final yesterdayDate = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 1));
          final yesterdayStr =
              '${yesterdayDate.year}-${yesterdayDate.month.toString().padLeft(2, '0')}-${yesterdayDate.day.toString().padLeft(2, '0')}';

          // This week range: return invoices for today and yesterday.
          if (params.maxDate == todayStr) {
            return Right([
              _inv(todayStr, 100.0),
              _inv(todayStr, 50.0),
              _inv(yesterdayStr, 200.0),
            ]);
          }
          // Last week range: return empty.
          return const Right([]);
        });
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const FdCountersLoading(),
        isA<FdCountersLoaded>()
            .having((s) => s.invoicesCount, 'invoicesCount', 2)
            .having((s) => s.invoicesTotal, 'invoicesTotal', 150.0)
            .having(
              (s) => s.vsYesterday?.invoicesDiff,
              'vsYesterday.invoicesDiff',
              1, // 2 today - 1 yesterday
            ),
      ],
    );

    blocTest<FdCountersCubit, FdCountersState>(
      'emits [Loading, Error] when first call fails',
      build: () {
        when(
          () => mockGetInvoicesByDateRange(any()),
        ).thenAnswer((_) async => Left(ServerFailure()));
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [const FdCountersLoading(), const FdCountersError()],
    );

    blocTest<FdCountersCubit, FdCountersState>(
      'emits [Loading, Error] when second call fails',
      build: () {
        var callCount = 0;
        when(() => mockGetInvoicesByDateRange(any())).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) return const Right([]);
          return Left(NetworkFailure());
        });
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [const FdCountersLoading(), const FdCountersError()],
    );

    blocTest<FdCountersCubit, FdCountersState>(
      'emits [Loading, Loaded] with zero counters when no invoices',
      build: () {
        when(
          () => mockGetInvoicesByDateRange(any()),
        ).thenAnswer((_) async => const Right([]));
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        const FdCountersLoading(),
        isA<FdCountersLoaded>()
            .having((s) => s.invoicesCount, 'invoicesCount', 0)
            .having((s) => s.invoicesTotal, 'invoicesTotal', 0.0),
      ],
    );

    blocTest<FdCountersCubit, FdCountersState>(
      'makes exactly 2 calls to GetInvoicesByDateRange',
      build: () {
        when(
          () => mockGetInvoicesByDateRange(any()),
        ).thenAnswer((_) async => const Right([]));
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      verify: (_) {
        verify(() => mockGetInvoicesByDateRange(any())).called(2);
      },
    );
  });
}
