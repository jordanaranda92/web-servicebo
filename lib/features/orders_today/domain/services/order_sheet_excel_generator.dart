import 'dart:typed_data';

import '../entities/order_action_entry.dart';
import '../entities/order_sheet.dart';

/// Contract for generating Excel files from an order sheet.
abstract class OrderSheetExcelGenerator {
  Future<Uint8List> generate({
    required OrderSheet orderSheet,
    List<OrderActionEntry> history = const [],
  });
}
