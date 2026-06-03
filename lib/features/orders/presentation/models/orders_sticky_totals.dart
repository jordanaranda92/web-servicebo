import '../../domain/entities/order_sheet.dart';

class OrdersStickyTotals {
  const OrdersStickyTotals({
    required this.clientTotals,
    required this.totalPedidos,
    required this.shouldRender,
  });

  final List<num> clientTotals;
  final num totalPedidos;
  final bool shouldRender;
}

OrdersStickyTotals computeOrdersStickyTotals({
  required OrderSheet orderSheet,
  required List<int> filteredProductIndices,
  required List<int> filteredClientIndices,
}) {
  if (filteredProductIndices.isEmpty || filteredClientIndices.isEmpty) {
    return const OrdersStickyTotals(
      clientTotals: <num>[],
      totalPedidos: 0,
      shouldRender: false,
    );
  }

  final totals = List<num>.filled(filteredClientIndices.length, 0);

  for (
    var productPos = 0;
    productPos < filteredProductIndices.length;
    productPos++
  ) {
    final productIdx = filteredProductIndices[productPos];
    if (productIdx < 0 || productIdx >= orderSheet.quantities.length) {
      continue;
    }

    final row = orderSheet.quantities[productIdx];
    for (
      var clientPos = 0;
      clientPos < filteredClientIndices.length;
      clientPos++
    ) {
      final clientIdx = filteredClientIndices[clientPos];
      if (clientIdx < 0 || clientIdx >= row.length) {
        continue;
      }

      // Functional rule: sticky totals must not include refunds/credits.
      totals[clientPos] += row[clientIdx];
    }
  }

  final totalPedidos = totals.fold<num>(0, (sum, value) => sum + value);
  final hasComputableOrders = totals.any((value) => value > 0);

  return OrdersStickyTotals(
    clientTotals: totals,
    totalPedidos: totalPedidos,
    shouldRender: hasComputableOrders,
  );
}
