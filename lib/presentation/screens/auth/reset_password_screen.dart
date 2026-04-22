import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_toast.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/liquid_glass/liquid_glass_modal.dart';
import '../../widgets/liquid_glass/liquid_glass_input.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      await ref
          .read(authRepositoryProvider)
          .updatePassword(_passwordCtrl.text);
      AppToast.success('Password updated!');
      if (mounted) context.go('/dashboard');
    } catch (e) {
      AppToast.error(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('same password') || msg.contains('same_password')) {
      return 'New password must be different from the old one.';
    }
    if (msg.contains('weak password') || msg.contains('password')) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('host lookup')) {
      return 'No internet connection. Please check your network.';
    }
    if (msg.contains('session') || msg.contains('not authenticated')) {
      return 'Session expired. Please request a new reset link.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: LiquidGlassModal(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.password_rounded,
                        size: 52,
                        color: scheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'New Password',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose a strong new password for your account.',
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                      ),
                      const SizedBox(height: 28),
                      LiquidGlassInput(
                        controller: _passwordCtrl,
                        hintText: 'New password',
                        obscureText: _obscureNew,
                        prefixIcon:
                            const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNew
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscureNew = !_obscureNew),
                        ),
                        validator: (v) {
                          if (v == null || v.length < 6) {
                            return 'At least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      LiquidGlassInput(
                        controller: _confirmCtrl,
                        hintText: 'Confirm password',
                        obscureText: _obscureConfirm,
                        prefixIcon:
                            const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (v != _passwordCtrl.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _loading ? null : _submit,
                          child: AnimatedSwitcher(
                            duration: 150.ms,
                            child: _loading
                                ? const SizedBox(
                                    key: ValueKey('loading'),
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Update Password',
                                    key: ValueKey('text'),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms, curve: Curves.easeOut)
                  .slideY(
                    begin: 0.04,
                    end: 0,
                    duration: 500.ms,
                    curve: Curves.easeOutCubic,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
