import 'package:flutter_test/flutter_test.dart';
import 'package:servicebo/features/orders/domain/entities/order_sheet.dart';
import 'package:servicebo/features/orders/presentation/models/orders_sticky_totals.dart';

void main() {
  OrderSheet makeSheet({
    required List<List<num>> quantities,
    List<Map<String, num>> refunds = const [],
  }) {
    final productsCount = quantities.length;
    final clientsCount = quantities.isEmpty ? 0 : quantities.first.length;

    return OrderSheet(
      date: '2026-06-02',
      clients: List.generate(clientsCount, (i) => 'C$i'),
      products: List.generate(productsCount, (i) => 'P$i'),
      clientIds: List.generate(clientsCount, (i) => 'c$i'),
      productIds: List.generate(productsCount, (i) => 'p$i'),
      quantities: quantities,
      pedidos: List.filled(productsCount, 0),
      stocks: List.filled(productsCount, 0),
      quedan: List.filled(productsCount, 0),
      clientOrders: List.generate(clientsCount, (i) => i + 1),
      cellRefunds: refunds,
    );
  }

  group('computeOrdersStickyTotals', () {
    test('sums quantities by visible client and product', () {
      final sheet = makeSheet(
        quantities: [
          [2, 1, 0],
          [3, 0, 4],
        ],
      );

      final result = computeOrdersStickyTotals(
        orderSheet: sheet,
        filteredProductIndices: const [0, 1],
        filteredClientIndices: const [0, 2],
      );

      expect(result.clientTotals, const [5, 4]);
      expect(result.totalPedidos, 9);
      expect(result.shouldRender, isTrue);
    });

    test('does not include refunds/credits in totals', () {
      final sheet = makeSheet(
        quantities: [
          [1, 2],
        ],
        refunds: [
          {'c0': 5, 'c1': 7},
        ],
      );

      final result = computeOrdersStickyTotals(
        orderSheet: sheet,
        filteredProductIndices: const [0],
        filteredClientIndices: const [0, 1],
      );

      expect(result.clientTotals, const [1, 2]);
      expect(result.totalPedidos, 3);
    });

    test('returns shouldRender false when all totals are zero', () {
      final sheet = makeSheet(
        quantities: [
          [0, 0],
          [0, 0],
        ],
      );

      final result = computeOrdersStickyTotals(
        orderSheet: sheet,
        filteredProductIndices: const [0, 1],
        filteredClientIndices: const [0, 1],
      );

      expect(result.clientTotals, const [0, 0]);
      expect(result.shouldRender, isFalse);
    });

    test('returns non-renderable result when no filtered clients', () {
      final sheet = makeSheet(
        quantities: [
          [2, 3],
        ],
      );

      final result = computeOrdersStickyTotals(
        orderSheet: sheet,
        filteredProductIndices: const [0],
        filteredClientIndices: const [],
      );

      expect(result.clientTotals, isEmpty);
      expect(result.totalPedidos, 0);
      expect(result.shouldRender, isFalse);
    });
  });
}
