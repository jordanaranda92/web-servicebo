import '../../domain/entities/client.dart';

class ClientModel {
  final String id;
  final String name;
  final String facturaDirectaUuid;
  final String facturaDirectaName;
  final String? clientCategoryId;
  final Map<String, String> shippingMethodsByDay;

  const ClientModel({
    required this.id,
    required this.name,
    required this.facturaDirectaUuid,
    required this.facturaDirectaName,
    this.clientCategoryId,
    this.shippingMethodsByDay = const {},
  });

  factory ClientModel.fromFirestore(String id, Map<String, dynamic> data) {
    final rawByDay = data['shippingMethodsByDay'] as Map<String, dynamic>?;
    final byDay = <String, String>{};
    if (rawByDay != null) {
      for (final entry in rawByDay.entries) {
        if (entry.value is String) {
          byDay[entry.key] = entry.value as String;
        }
      }
    }

    return ClientModel(
      id: id,
      name: data['name'] as String? ?? '',
      facturaDirectaUuid: data['facturaDirectaUuid'] as String? ?? '',
      facturaDirectaName: data['facturaDirectaName'] as String? ?? '',
      clientCategoryId: data['clientCategoryId'] as String?,
      shippingMethodsByDay: byDay,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'facturaDirectaUuid': facturaDirectaUuid,
      'facturaDirectaName': facturaDirectaName,
      'clientCategoryId': clientCategoryId,
      'shippingMethodsByDay': shippingMethodsByDay,
    };
  }

  Client toEntity({String? categoryName, String? categoryColor}) {
    return Client(
      id: id,
      name: name,
      facturaDirectaUuid: facturaDirectaUuid,
      facturaDirectaName: facturaDirectaName,
      clientCategoryId: clientCategoryId,
      categoryName: categoryName,
      categoryColor: categoryColor,
      shippingMethodsByDay: shippingMethodsByDay,
    );
  }
}
