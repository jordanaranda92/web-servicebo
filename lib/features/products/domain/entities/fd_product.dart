import 'package:equatable/equatable.dart';

class FdProduct extends Equatable {
  final String uuid;
  final String name;
  final double? salesPrice;
  final String? currency;
  final List<String> salesTax;
  final String? salesDescription;

  const FdProduct({
    required this.uuid,
    required this.name,
    this.salesPrice,
    this.currency,
    this.salesTax = const [],
    this.salesDescription,
  });

  @override
  List<Object?> get props => [
    uuid,
    name,
    salesPrice,
    currency,
    salesTax,
    salesDescription,
  ];
}
