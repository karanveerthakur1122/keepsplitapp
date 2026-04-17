import 'package:supabase_flutter/supabase_flutter.dart' show AuthResponse, Session, User;
import '../entities/profile.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  Session? get currentSession;
  Future<AuthResponse> signUp({required String email, required String password, String? displayName});
  Future<AuthResponse> signIn({required String email, required String password});
  Future<void> signOut();
  Future<void> updatePassword(String newPassword);
  Future<Profile?> getProfile(String userId);
  Future<void> updateProfile({required String userId, String? displayName});
}
