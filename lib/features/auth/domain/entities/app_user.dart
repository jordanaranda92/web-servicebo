import 'package:equatable/equatable.dart';

import 'user_role.dart';

class AppUser extends Equatable {
  final String uid;
  final String email;
  final String? userName;
  final UserRole role;
  final String? color;

  const AppUser({
    required this.uid,
    required this.email,
    this.userName,
    this.role = UserRole.employee,
    this.color,
  });

  bool get isAdmin => role == UserRole.admin;

  @override
  List<Object?> get props => [uid, email, userName, role, color];
}
