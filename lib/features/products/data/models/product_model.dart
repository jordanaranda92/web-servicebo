import '../../domain/entities/product.dart';

class ProductModel {
  final String id;
  final String name;
  final String facturaDirectaUuid;
  final bool isActive;
  final String color;
  final int? order;

  const ProductModel({
    required this.id,
    required this.name,
    required this.facturaDirectaUuid,
    required this.isActive,
    required this.color,
    this.order,
  });

  factory ProductModel.fromFirestore(String id, Map<String, dynamic> data) {
    return ProductModel(
      id: id,
      name: data['name'] as String? ?? '',
      facturaDirectaUuid: data['facturaDirectaUuid'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      color: data['color'] as String? ?? '#FFFFFF',
      order: data['order'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'facturaDirectaUuid': facturaDirectaUuid,
      'isActive': isActive,
      'color': color,
      'order': order,
    };
  }

  Product toEntity() {
    return Product(
      id: id,
      name: name,
      facturaDirectaUuid: facturaDirectaUuid,
      isActive: isActive,
      color: color,
      order: order,
    );
  }
}
