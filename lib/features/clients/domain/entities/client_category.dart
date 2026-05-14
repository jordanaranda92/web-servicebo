import 'package:equatable/equatable.dart';

class ClientCategory extends Equatable {
  final String id;
  final String name;
  final String? color;

  const ClientCategory({required this.id, required this.name, this.color});

  @override
  List<Object?> get props => [id, name, color];
}
