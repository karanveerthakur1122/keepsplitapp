import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/profile_model.dart';

class SupabaseAuthDatasource {
  SupabaseAuthDatasource(this._client);
  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'https://llpvrckmkchzinatxvbf.supabase.co/auth/v1/callback',
      data: displayName != null
          ? {'display_name': displayName, 'full_name': displayName}
          : null,
    );
    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> resetPasswordForEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
  }) async {
    return await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.recovery,
    );
  }

  Future<ProfileModel?> getProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return ProfileModel.fromJson(response);
  }

  Future<void> updateProfile({
    required String userId,
    String? displayName,
  }) async {
    if (displayName == null) return;

    final user = _client.auth.currentUser;
    final email = user?.email ?? '';

    // Upsert into profiles so the operation succeeds even when the
    // handle_new_user trigger didn't create the row.
    await _client.from('profiles').upsert(
      {
        'user_id': userId,
        'display_name': displayName,
        'email': email.toLowerCase(),
      },
      onConflict: 'user_id',
    );

    // Also update Supabase auth user_metadata so that
    // user.userMetadata['display_name'] stays in sync everywhere.
    await _client.auth.updateUser(
      UserAttributes(data: {
        'display_name': displayName,
        'full_name': displayName,
      }),
    );
  }

  Future<List<ProfileModel>> getProfilesByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    final response = await _client
        .from('profiles')
        .select()
        .inFilter('user_id', userIds);

    return (response as List).map((e) => ProfileModel.fromJson(e)).toList();
  }

  Future<ProfileModel?> getProfileByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    // Case-insensitive match (ilike with no wildcards acts like ieq).
    // We use `limit(1)` + first because ilike may return multiple rows in
    // theory, though emails should be unique.
    final response = await _client
        .from('profiles')
        .select()
        .ilike('email', normalized)
        .limit(1);

    final rows = response as List;
    if (rows.isEmpty) return null;
    return ProfileModel.fromJson(rows.first as Map<String, dynamic>);
  }
}
