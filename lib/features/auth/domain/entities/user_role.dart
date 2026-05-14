enum UserRole {
  employee,
  admin;

  static UserRole fromString(String? value) {
    if (value == 'admin') return UserRole.admin;
    return UserRole.employee;
  }
}
