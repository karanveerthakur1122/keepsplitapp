import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/sign_out_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/liquid_glass/liquid_glass_input.dart';
import '../../widgets/liquid_glass/liquid_glass_surface.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _passwordLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final profile = await ref.read(authRepositoryProvider).getProfile(user.id);
    if (!mounted) return;
    if (profile != null && profile.displayName.isNotEmpty) {
      _nameCtrl.text = profile.displayName;
    } else {
      // Fall back to auth metadata if the profiles row doesn't exist yet.
      _nameCtrl.text =
          user.userMetadata?['display_name'] as String? ??
          user.userMetadata?['full_name'] as String? ??
          user.userMetadata?['name'] as String? ??
          '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _goBack() {
    // The settings screen is pushed on top of the dashboard, so a plain pop
    // returns us. Fall back to an explicit `/dashboard` navigation in case
    // this screen was reached via a deep link with no stack underneath.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  String _humanError(Object e) {
    // Supabase AuthException has a .message property.
    if (e is AuthException) return e.message;

    final s = e.toString().replaceFirst('Exception: ', '');
    if (s.contains('AuthException')) {
      final match = RegExp(r'message: ([^,}]+)').firstMatch(s);
      if (match != null) return match.group(1)!.trim();
    }
    if (s.length > 160) return '${s.substring(0, 160)}…';
    return s;
  }

  Future<void> _updateName() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name cannot be empty')),
      );
      return;
    }
    Haptics.tap();
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).updateProfile(
            userId: user.id,
            displayName: newName,
          );
      // Refresh all providers that surface the display name so the drawer,
      // header, expense payer lists, and collaborator chips all update.
      ref.invalidate(currentProfileProvider);
      ref.invalidate(profileProvider(user.id));
      ref.invalidate(authStateProvider);
      if (!mounted) return;
      Haptics.confirm();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          backgroundColor: Colors.green,
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update profile: ${_humanError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changePassword() async {
    final messenger = ScaffoldMessenger.of(context);
    final pw = _passwordCtrl.text.trim();
    if (pw.length < 6) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Password must be at least 6 characters')),
      );
      return;
    }
    Haptics.tap();
    FocusScope.of(context).unfocus();
    setState(() => _passwordLoading = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(pw);
      if (!mounted) return;
      _passwordCtrl.clear();
      Haptics.confirm();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content:
                Text('Failed to update password: ${_humanError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _passwordLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Haptics.tap();
                          _goBack();
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.arrow_back_rounded, size: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Settings',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    LiquidGlassSurface(
                      borderRadius: 18,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profile',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant
                                          .withValues(alpha: 0.6),
                                    ),
                          ),
                          const SizedBox(height: 18),
                          LiquidGlassInput(
                            controller: _nameCtrl,
                            hintText: 'Display name',
                            prefixIcon:
                                const Icon(Icons.person_outline, size: 20),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: _loading ? null : _updateName,
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Update Profile'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    LiquidGlassSurface(
                      borderRadius: 18,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Security',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 18),
                          LiquidGlassInput(
                            controller: _passwordCtrl,
                            hintText: 'New password',
                            obscureText: true,
                            prefixIcon:
                                const Icon(Icons.lock_outline, size: 20),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed:
                                  _passwordLoading ? null : _changePassword,
                              child: _passwordLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text('Change Password'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    LiquidGlassSurface(
                      borderRadius: 18,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Appearance',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<ThemeMode>(
                              segments: const [
                                ButtonSegment(
                                  value: ThemeMode.light,
                                  icon: Icon(Icons.light_mode_outlined,
                                      size: 18),
                                  label: Text('Light'),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.system,
                                  icon: Icon(Icons.brightness_auto, size: 18),
                                  label: Text('Auto'),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.dark,
                                  icon: Icon(Icons.dark_mode_outlined,
                                      size: 18),
                                  label: Text('Dark'),
                                ),
                              ],
                              selected: {themeMode},
                              onSelectionChanged: (modes) {
                                Haptics.select();
                                ref
                                    .read(themeModeProvider.notifier)
                                    .setTheme(modes.first);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Haptics.confirm();
                          await performSignOut(ref);
                        },
                        icon: Icon(Icons.logout_rounded,
                            color: scheme.error, size: 18),
                        label: Text('Sign Out',
                            style: TextStyle(color: scheme.error)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: scheme.error.withValues(alpha: 0.3)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
