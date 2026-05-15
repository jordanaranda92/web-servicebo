import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/log/app_logger.dart';
import '../../../../core/log/firebase_operations_logger.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import 'auth_remote_data_source.dart';

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(
    this._firebaseAuth,
    this._firestore,
    this._logger,
    this._fbLogger,
  );

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final AppLogger _logger;
  final FirebaseOperationsLogger _fbLogger;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  @override
  Future<AppUser> signInWithEmailPassword(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const ServerException(message: 'User is null after sign-in');
      }
      final profile = await _fetchUserProfile(user.uid);
      return AppUser(
        uid: user.uid,
        email: user.email ?? email,
        userName: profile['userName'] as String?,
        role: UserRole.fromString(profile['role'] as String?),
      );
    } on FirebaseAuthException {
      rethrow;
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Firebase error during sign-in: $e');
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  @override
  AppUser? getCurrentUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return AppUser(uid: user.uid, email: user.email ?? '');
  }

  @override
  Future<AppUser?> getCurrentUserWithProfile() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    final profile = await _fetchUserProfile(user.uid);
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      userName: profile['userName'] as String?,
      role: UserRole.fromString(profile['role'] as String?),
    );
  }

  @override
  Future<String?> getUserName(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      _fbLogger.logRead('users', doc.exists ? 1 : 0, doc.data());
      if (!doc.exists || doc.data() == null) return null;
      return doc.data()!['userName'] as String?;
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error reading user name: $e');
    }
  }

  @override
  Future<void> saveUserName(String uid, String name) async {
    try {
      await _usersCollection.doc(uid).set({
        'userName': name,
      }, SetOptions(merge: true));
      _fbLogger.logWrite('users', 1, {'userName': name});
    } on FirebaseException catch (e) {
      throw ServerException(message: 'Error saving user name: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchUserProfile(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      _fbLogger.logRead('users', doc.exists ? 1 : 0, doc.data());
      if (!doc.exists || doc.data() == null) {
        _logger.info(
          '[Auth] No user profile found for uid=$uid, defaulting to employee',
        );
        return {};
      }
      return doc.data()!;
    } on FirebaseException catch (e) {
      _logger.warning('[Auth] Error reading user profile for uid=$uid', e);
      return {};
    }
  }
}
