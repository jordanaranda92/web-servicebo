import 'package:flutter_test/flutter_test.dart';

import 'package:servicebo/features/orders_today/domain/entities/order_sheet.dart';
import 'package:servicebo/features/orders_today/presentation/models/client_order_summary.dart';

void main() {
  group('buildClientSummaries', () {
    OrderSheet makeSheet({
      List<String> clients = const [],
      List<String> clientIds = const [],
      List<String> products = const [],
      List<String> productIds = const [],
      List<List<num>> quantities = const [],
      List<int> clientOrders = const [],
      List<Map<String, String>> cellFlags = const [],
      List<Map<String, String>> cellNotes = const [],
      List<Map<String, num>> cellRefunds = const [],
    }) {
      final numProducts = products.length;
      return OrderSheet(
        date: '2026-05-15',
        clients: clients,
        clientIds: clientIds,
        products: products,
        productIds: productIds,
        quantities: quantities,
        pedidos: List.filled(numProducts, 0),
        stocks: List.filled(numProducts, 0),
        quedan: List.filled(numProducts, 0),
        clientOrders: clientOrders,
        cellFlags: cellFlags,
        cellNotes: cellNotes,
        cellRefunds: cellRefunds,
      );
    }

    test('returns empty list when sheet has no clients', () {
      final sheet = makeSheet(
        products: ['Pan'],
        quantities: [[]],
      );
      expect(buildClientSummaries(sheet), isEmpty);
    });

    test('excludes clients with no relevant data', () {
      final sheet = makeSheet(
        clients: ['Cliente A', 'Cliente B'],
        clientIds: ['a', 'b'],
        products: ['Pan'],
        quantities: [
          [0, 5]
        ],
        clientOrders: [1, 2],
      );

      final result = buildClientSummaries(sheet);
      expect(result, hasLength(1));
      expect(result.first.clientName, 'Cliente B');
    });

    test('includes client with only flag (qty 0)', () {
      final sheet = makeSheet(
        clients: ['Cliente A'],
        clientIds: ['a'],
        products: ['Pan'],
        quantities: [
          [0]
        ],
        clientOrders: [1],
        cellFlags: [
          {'a': 'reservation'}
        ],
      );

      final result = buildClientSummaries(sheet);
      expect(result, hasLength(1));
      expect(result.first.products.first.flag, 'reservation');
      expect(result.first.products.first.quantity, 0);
    });

    test('includes client with only refund (qty 0)', () {
      final sheet = makeSheet(
        clients: ['Cliente A'],
        clientIds: ['a'],
        products: ['Pan'],
        quantities: [
          [0]
        ],
        clientOrders: [1],
        cellRefunds: [
          {'a': 3}
        ],
      );

      final result = buildClientSummaries(sheet);
      expect(result, hasLength(1));
      expect(result.first.products.first.refund, 3);
      expect(result.first.totalProducts, 3);
    });

    test('includes client with only note (qty 0)', () {
      final sheet = makeSheet(
        clients: ['Cliente A'],
        clientIds: ['a'],
        products: ['Pan'],
        quantities: [
          [0]
        ],
        clientOrders: [1],
        cellNotes: [
          {'a': 'Urgente'}
        ],
      );

      final result = buildClientSummaries(sheet);
      expect(result, hasLength(1));
      expect(result.first.products.first.note, 'Urgente');
    });

    test('excludes empty string notes', () {
      final sheet = makeSheet(
        clients: ['Cliente A'],
        clientIds: ['a'],
        products: ['Pan'],
        quantities: [
          [0]
        ],
        clientOrders: [1],
        cellNotes: [
          {'a': ''}
        ],
      );

      final result = buildClientSummaries(sheet);
      expect(result, isEmpty);
    });

    test('sorts by orderNumber ascending', () {
      final sheet = makeSheet(
        clients: ['Zeta', 'Alfa'],
        clientIds: ['z', 'a'],
        products: ['Pan'],
        quantities: [
          [5, 3]
        ],
        clientOrders: [2, 1],
      );

      final result = buildClientSummaries(sheet);
      expect(result, hasLength(2));
      expect(result[0].clientName, 'Alfa');
      expect(result[0].orderNumber, 1);
      expect(result[1].clientName, 'Zeta');
      expect(result[1].orderNumber, 2);
    });

    test('calculates totalProducts as quantities + refunds', () {
      final sheet = makeSheet(
        clients: ['Cliente A'],
        clientIds: ['a'],
        products: ['Pan', 'Leche'],
        quantities: [
          [5],
          [3],
        ],
        clientOrders: [1],
        cellRefunds: [
          {'a': 2},
          {},
        ],
      );

      final result = buildClientSummaries(sheet);
      expect(result.first.totalProducts, 10); // 5+3 + 2
    });

    test('handles multiple flags, refunds and notes on same product', () {
      final sheet = makeSheet(
        clients: ['Cliente A'],
        clientIds: ['a'],
        products: ['Pan'],
        quantities: [
          [7]
        ],
        clientOrders: [1],
        cellFlags: [
          {'a': 'compensation'}
        ],
        cellRefunds: [
          {'a': 2}
        ],
        cellNotes: [
          {'a': 'Especial'}
        ],
      );

      final result = buildClientSummaries(sheet);
      final product = result.first.products.first;
      expect(product.quantity, 7);
      expect(product.flag, 'compensation');
      expect(product.refund, 2);
      expect(product.note, 'Especial');
    });

    test('filters out products without relevant data for a client', () {
      final sheet = makeSheet(
        clients: ['Cliente A'],
        clientIds: ['a'],
        products: ['Pan', 'Leche', 'Huevos'],
        quantities: [
          [5],
          [0],
          [3],
        ],
        clientOrders: [1],
      );

      final result = buildClientSummaries(sheet);
      expect(result.first.products, hasLength(2));
      expect(result.first.products[0].productName, 'Pan');
      expect(result.first.products[1].productName, 'Huevos');
    });

    test('handles out-of-range cellFlags/cellNotes/cellRefunds gracefully', () {
      // cellFlags shorter than products list
      final sheet = makeSheet(
        clients: ['Cliente A'],
        clientIds: ['a'],
        products: ['Pan', 'Leche'],
        quantities: [
          [5],
          [3],
        ],
        clientOrders: [1],
        cellFlags: [], // empty — shorter than products
        cellNotes: [], // empty
        cellRefunds: [], // empty
      );

      final result = buildClientSummaries(sheet);
      expect(result, hasLength(1));
      expect(result.first.products, hasLength(2));
      // No crashes, no flags/notes/refunds
      expect(result.first.products[0].flag, isNull);
      expect(result.first.products[0].note, isNull);
      expect(result.first.products[0].refund, isNull);
    });

    test('ignores refund of 0', () {
      final sheet = makeSheet(
        clients: ['Cliente A'],
        clientIds: ['a'],
        products: ['Pan'],
        quantities: [
          [0]
        ],
        clientOrders: [1],
        cellRefunds: [
          {'a': 0}
        ],
      );

      final result = buildClientSummaries(sheet);
      expect(result, isEmpty);
    });
  });
}
