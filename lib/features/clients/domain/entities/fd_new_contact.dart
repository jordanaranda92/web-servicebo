import 'package:equatable/equatable.dart';

class FdNewContact extends Equatable {
  final String uuid;
  final String displayName;
  final String fiscalName;
  final String fiscalId;

  const FdNewContact({
    required this.uuid,
    required this.displayName,
    required this.fiscalName,
    required this.fiscalId,
  });

  @override
  List<Object?> get props => [uuid, displayName, fiscalName, fiscalId];
}
