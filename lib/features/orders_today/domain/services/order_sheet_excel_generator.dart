import 'dart:typed_data';

import '../entities/order_sheet.dart';

/// Contract for generating Excel files from an order sheet.
abstract class OrderSheetExcelGenerator {
  Future<Uint8List> generate({required OrderSheet orderSheet});
}
