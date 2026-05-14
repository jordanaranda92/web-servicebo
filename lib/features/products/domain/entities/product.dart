import 'package:equatable/equatable.dart';

class Product extends Equatable {
  final String id;
  final String name;
  final String facturaDirectaUuid;
  final bool isActive;
  final String color;
  final int? order;

  const Product({
    required this.id,
    required this.name,
    required this.facturaDirectaUuid,
    required this.isActive,
    required this.color,
    this.order,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    facturaDirectaUuid,
    isActive,
    color,
    order,
  ];
}
