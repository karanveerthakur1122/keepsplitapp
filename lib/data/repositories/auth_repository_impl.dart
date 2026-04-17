import 'package:supabase_flutter/supabase_flutter.dart' show AuthResponse, Session, User;

import '../../domain/entities/profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/remote/supabase_auth_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);
  final SupabaseAuthDatasource _remote;

  @override
  Stream<User?> get authStateChanges =>
      _remote.authStateChanges.map((state) => state.session?.user);

  @override
  User? get currentUser => _remote.currentUser;

  @override
  Session? get currentSession => _remote.currentSession;

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) =>
      _remote.signUp(email: email, password: password, displayName: displayName);

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      _remote.signIn(email: email, password: password);

  @override
  Future<void> signOut() => _remote.signOut();

  @override
  Future<void> updatePassword(String newPassword) =>
      _remote.updatePassword(newPassword);

  @override
  Future<Profile?> getProfile(String userId) async {
    final model = await _remote.getProfile(userId);
    return model?.toEntity();
  }

  @override
  Future<void> updateProfile({required String userId, String? displayName}) =>
      _remote.updateProfile(userId: userId, displayName: displayName);
}
