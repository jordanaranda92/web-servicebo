import 'package:flutter_test/flutter_test.dart';

import 'package:servicebo/app/router/router.dart';

void main() {
  group('AppRoutes.ordersViewPathForDate', () {
    test('should build readonly path with normalized date query', () {
      // arrange
      final date = DateTime(2026, 6, 2, 18, 45);

      // act
      final result = AppRoutes.ordersViewPathForDate(date);

      // assert
      expect(result, '/orders/view?date=2026-06-02');
    });
  });

  group('AppRoutes.parseOrdersViewDateParam', () {
    test('should parse a valid yyyy-mm-dd date', () {
      // arrange
      const raw = '2026-06-02';

      // act
      final result = AppRoutes.parseOrdersViewDateParam(raw);

      // assert
      expect(result, DateTime(2026, 6, 2));
    });

    test('should return null when format is invalid', () {
      // arrange
      const raw = '02/06/2026';

      // act
      final result = AppRoutes.parseOrdersViewDateParam(raw);

      // assert
      expect(result, isNull);
    });

    test('should return null when date does not exist', () {
      // arrange
      const raw = '2026-02-31';

      // act
      final result = AppRoutes.parseOrdersViewDateParam(raw);

      // assert
      expect(result, isNull);
    });
  });
}
