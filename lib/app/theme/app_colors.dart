import 'package:flutter/material.dart';

import '../../features/orders_today/domain/entities/order_action_entry.dart';

/// Palette for assigning unique colors to concurrent users (presence cursors).
class PresenceColors {
  static const palette = [
    Color(0xFFFF5722),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF673AB7),
    Color(0xFF3F51B5),
    Color(0xFF2196F3),
    Color(0xFF009688),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF795548),
    Color(0xFF607D8B),
    Color(0xFFF44336),
  ];
}

/// Semantic colors for order action history types.
class OrderActionColors {
  static Color forType(OrderActionType type) {
    return switch (type) {
      OrderActionType.quantityChanged => const Color(0xFF1976D2),
      OrderActionType.stockChanged => const Color(0xFF00838F),
      OrderActionType.compensationMarked ||
      OrderActionType.compensationUnmarked => const Color(0xFF7B1FA2),
      OrderActionType.reservationMarked ||
      OrderActionType.reservationUnmarked => const Color(0xFF0277BD),
      OrderActionType.strictStockMarked ||
      OrderActionType.strictStockUnmarked => const Color(0xFF4E342E),
      OrderActionType.refundAdded ||
      OrderActionType.refundEdited ||
      OrderActionType.refundRemoved => const Color(0xFFC62828),
      OrderActionType.ordersReset => const Color(0xFFE65100),
      OrderActionType.clientsAdded => const Color(0xFF2E7D32),
      OrderActionType.clientsRemoved => const Color(0xFFAD1457),
      OrderActionType.productsAdded => const Color(0xFF558B2F),
      OrderActionType.productsRemoved => const Color(0xFF6A1B9A),
      OrderActionType.orderSheetCreated => const Color(0xFF00695C),
      OrderActionType.orderSheetGenerated => const Color(0xFF283593),
      OrderActionType.provisionalInvoiceGenerated => const Color(0xFFF57F17),
    };
  }
}
