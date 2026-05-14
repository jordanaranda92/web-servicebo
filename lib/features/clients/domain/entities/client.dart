import 'package:equatable/equatable.dart';

class Client extends Equatable {
  final String id;
  final String name;
  final String facturaDirectaUuid;
  final String facturaDirectaName;
  final String? clientCategoryId;
  final String? categoryName;
  final String? categoryColor;
  final Map<String, String> shippingMethodsByDay;

  const Client({
    required this.id,
    required this.name,
    required this.facturaDirectaUuid,
    required this.facturaDirectaName,
    this.clientCategoryId,
    this.categoryName,
    this.categoryColor,
    this.shippingMethodsByDay = const {},
  });

  Client copyWith({
    String? clientCategoryId,
    String? categoryName,
    String? categoryColor,
    Map<String, String>? shippingMethodsByDay,
  }) {
    return Client(
      id: id,
      name: name,
      facturaDirectaUuid: facturaDirectaUuid,
      facturaDirectaName: facturaDirectaName,
      clientCategoryId: clientCategoryId ?? this.clientCategoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryColor: categoryColor ?? this.categoryColor,
      shippingMethodsByDay: shippingMethodsByDay ?? this.shippingMethodsByDay,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    facturaDirectaUuid,
    facturaDirectaName,
    clientCategoryId,
    categoryName,
    categoryColor,
    shippingMethodsByDay,
  ];
}
