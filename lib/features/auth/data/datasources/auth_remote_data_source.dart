import '../../domain/entities/app_user.dart';

abstract class AuthRemoteDataSource {
  Future<AppUser> signInWithEmailPassword(String email, String password);
  Future<void> signOut();
  AppUser? getCurrentUser();
  Future<AppUser?> getCurrentUserWithProfile();
  Future<String?> getUserName(String uid);
  Future<void> saveUserName(String uid, String name);
}
