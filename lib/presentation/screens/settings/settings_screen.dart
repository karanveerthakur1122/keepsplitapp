import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/sign_out_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/layout_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/tutorial_provider.dart';
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
  bool _obscurePassword = true;

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
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  String _humanError(Object e) {
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
      AppToast.error('Display name cannot be empty');
      return;
    }
    Haptics.tap();
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile(
            userId: user.id,
            displayName: newName,
          );
      ref.invalidate(currentProfileProvider);
      ref.invalidate(profileProvider(user.id));
      ref.invalidate(authStateProvider);
      if (!mounted) return;
      Haptics.confirm();
      AppToast.success('Profile updated');
    } on AuthException catch (e) {
      AppToast.error(e.message);
    } catch (e) {
      AppToast.error('Failed to update profile: ${_humanError(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changePassword() async {
    final pw = _passwordCtrl.text.trim();
    if (pw.length < 6) {
      AppToast.error('Password must be at least 6 characters');
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
      AppToast.success('Password updated successfully');
    } on AuthException catch (e) {
      AppToast.error(e.message);
    } catch (e) {
      AppToast.error('Failed to update password: ${_humanError(e)}');
    } finally {
      if (mounted) setState(() => _passwordLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);
    final layout = ref.watch(layoutModeProvider);
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final displayName = profileAsync.valueOrNull?.displayName ?? '';
    final email = user?.email ?? '';
    final initials = _initials(displayName, email);

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
              // ── Header ──
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
              // ── Body ──
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // ── Avatar + Name + Email ──
                    _buildProfileHeader(
                        scheme, isDark, initials, displayName, email),
                    const SizedBox(height: 20),

                    // ── Account section ──
                    _SectionLabel(label: 'Account'),
                    const SizedBox(height: 8),
                    LiquidGlassSurface(
                      borderRadius: 16,
                      child: Column(
                        children: [
                          _SettingsTile(
                            icon: Icons.person_outline_rounded,
                            iconColor: scheme.primary,
                            title: 'Edit display name',
                            subtitle: displayName.isEmpty
                                ? 'Not set'
                                : displayName,
                            onTap: () => _showNameDialog(scheme, isDark),
                          ),
                          _TileDivider(),
                          _SettingsTile(
                            icon: Icons.lock_outline_rounded,
                            iconColor: scheme.primary,
                            title: 'Change password',
                            onTap: () =>
                                _showPasswordDialog(scheme, isDark),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Appearance section ──
                    _SectionLabel(label: 'Appearance'),
                    const SizedBox(height: 8),
                    LiquidGlassSurface(
                      borderRadius: 16,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              children: [
                                Icon(Icons.palette_outlined,
                                    size: 20, color: scheme.primary),
                                const SizedBox(width: 12),
                                Text(
                                  'Theme',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                          fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                16, 4, 16, 16),
                            child: _buildThemeSelector(
                                scheme, isDark, themeMode),
                          ),
                          _TileDivider(),
                          _SettingsTile(
                            icon: layout == LayoutMode.grid
                                ? Icons.grid_view_rounded
                                : Icons.view_agenda_outlined,
                            iconColor: scheme.primary,
                            title: 'Layout',
                            subtitle: layout == LayoutMode.grid
                                ? 'Grid'
                                : 'List',
                            trailing: Switch.adaptive(
                              value: layout == LayoutMode.grid,
                              onChanged: (_) {
                                Haptics.select();
                                ref
                                    .read(layoutModeProvider.notifier)
                                    .toggle();
                              },
                              activeColor: scheme.primary,
                            ),
                            onTap: () {
                              Haptics.select();
                              ref
                                  .read(layoutModeProvider.notifier)
                                  .toggle();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── About & Legal section ──
                    _SectionLabel(label: 'About'),
                    const SizedBox(height: 8),
                    LiquidGlassSurface(
                      borderRadius: 16,
                      child: Column(
                        children: [
                          _SettingsTile(
                            icon: Icons.replay_rounded,
                            iconColor: Colors.orange,
                            title: 'Replay tutorial',
                            subtitle: 'Show the first-launch walkthrough',
                            onTap: () async {
                              Haptics.select();
                              await ref
                                  .read(tutorialProvider.notifier)
                                  .reset();
                              if (!context.mounted) return;
                              AppToast.success(
                                  'Tutorial will show on next launch');
                              context.go('/dashboard');
                            },
                          ),
                          _TileDivider(),
                          _SettingsTile(
                            icon: Icons.description_outlined,
                            iconColor: scheme.primary,
                            title: 'Terms & Conditions',
                            trailing: const Icon(
                                Icons.chevron_right_rounded,
                                size: 20),
                            onTap: () => context.push('/terms'),
                          ),
                          _TileDivider(),
                          _SettingsTile(
                            icon: Icons.shield_outlined,
                            iconColor: scheme.primary,
                            title: 'Privacy Policy',
                            trailing: const Icon(
                                Icons.chevron_right_rounded,
                                size: 20),
                            onTap: () => context.push('/privacy'),
                          ),
                          _TileDivider(),
                          _SettingsTile(
                            icon: Icons.info_outline_rounded,
                            iconColor: scheme.onSurfaceVariant,
                            title: 'Version',
                            subtitle: '1.0.0',
                            onTap: null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Sign Out ──
                    LiquidGlassSurface(
                      borderRadius: 16,
                      child: _SettingsTile(
                        icon: Icons.logout_rounded,
                        iconColor: scheme.error,
                        title: 'Sign Out',
                        titleColor: scheme.error,
                        onTap: () async {
                          Haptics.confirm();
                          await performSignOut(ref);
                          AppToast.info('Signed out');
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Made with love for Keepsplit',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.35),
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

  // ── Helpers ──

  String _initials(String name, String email) {
    if (name.isNotEmpty) {
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return name[0].toUpperCase();
    }
    if (email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }

  Widget _buildProfileHeader(
    ColorScheme scheme,
    bool isDark,
    String initials,
    String displayName,
    String email,
  ) {
    return LiquidGlassSurface(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accentA, AppColors.accentB],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentA.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName.isEmpty ? 'No name set' : displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant
                            .withValues(alpha: 0.6),
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(
    ColorScheme scheme,
    bool isDark,
    ThemeMode current,
  ) {
    return Row(
      children: [
        _ThemeChip(
          icon: Icons.light_mode_rounded,
          label: 'Light',
          selected: current == ThemeMode.light,
          scheme: scheme,
          onTap: () {
            Haptics.select();
            ref.read(themeModeProvider.notifier).setTheme(ThemeMode.light);
          },
        ),
        const SizedBox(width: 8),
        _ThemeChip(
          icon: Icons.brightness_auto_rounded,
          label: 'Auto',
          selected: current == ThemeMode.system,
          scheme: scheme,
          onTap: () {
            Haptics.select();
            ref
                .read(themeModeProvider.notifier)
                .setTheme(ThemeMode.system);
          },
        ),
        const SizedBox(width: 8),
        _ThemeChip(
          icon: Icons.dark_mode_rounded,
          label: 'Dark',
          selected: current == ThemeMode.dark,
          scheme: scheme,
          onTap: () {
            Haptics.select();
            ref.read(themeModeProvider.notifier).setTheme(ThemeMode.dark);
          },
        ),
      ],
    );
  }

  void _showNameDialog(ColorScheme scheme, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF13102B)
                : const Color(0xFFFAF8FF),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Edit display name',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              LiquidGlassInput(
                controller: _nameCtrl,
                hintText: 'Display name',
                prefixIcon:
                    const Icon(Icons.person_outline, size: 20),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _loading
                      ? null
                      : () {
                          _updateName();
                          Navigator.pop(ctx);
                        },
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPasswordDialog(ColorScheme scheme, bool isDark) {
    _passwordCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF13102B)
                  : const Color(0xFFFAF8FF),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Change password',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Must be at least 6 characters.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: scheme.onSurfaceVariant
                            .withValues(alpha: 0.6),
                      ),
                ),
                const SizedBox(height: 16),
                LiquidGlassInput(
                  controller: _passwordCtrl,
                  hintText: 'New password',
                  obscureText: _obscurePassword,
                  prefixIcon:
                      const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () {
                      setSheetState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                      setState(() {});
                    },
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _passwordLoading
                        ? null
                        : () {
                            _changePassword();
                            Navigator.pop(ctx);
                          },
                    child: _passwordLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : const Text('Update Password'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reusable private widgets ──

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.5),
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.titleColor,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: titleColor,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant
                                      .withValues(alpha: 0.55),
                                ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: Theme.of(context)
            .colorScheme
            .outlineVariant
            .withValues(alpha: 0.18),
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.scheme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.15)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.white.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.4)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06)),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? scheme.primary
                      : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected
                        ? scheme.primary
                        : scheme.onSurfaceVariant
                            .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
