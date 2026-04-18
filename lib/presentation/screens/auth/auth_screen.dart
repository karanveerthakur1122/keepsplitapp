import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/liquid_glass/liquid_glass_modal.dart';
import '../../widgets/liquid_glass/liquid_glass_input.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLogin = true;
  bool _loading = false;
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final repo = ref.read(authRepositoryProvider);
      if (_isLogin) {
        await repo.signIn(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      } else {
        await repo.signUp(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          displayName: _nameCtrl.text.trim().isEmpty
              ? null
              : _nameCtrl.text.trim(),
        );
      }
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please check your email and confirm your account.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already exists')) {
      return 'An account with this email already exists.';
    }
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('host lookup')) {
      return 'No internet connection. Please check your network.';
    }
    if (msg.contains('too many requests') || msg.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment.';
    }
    if (msg.contains('weak password') || msg.contains('password')) {
      return 'Password is too weak. Use at least 6 characters.';
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
            colors: isDark
                ? AppColors.darkGradient
                : AppColors.lightGradient,
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/icon/logo png.png',
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) => Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  scheme.primary,
                                  AppColors.accentB,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.sticky_note_2_rounded,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                          .animate()
                          .scale(
                            begin: const Offset(0.6, 0.6),
                            end: const Offset(1.0, 1.0),
                            duration: 500.ms,
                            curve: Curves.elasticOut,
                          ),
                      const SizedBox(height: 16),
                      Text(
                        'Keepsplit',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedSwitcher(
                        duration: 200.ms,
                        child: Text(
                          _isLogin ? 'Welcome back' : 'Create your account',
                          key: ValueKey(_isLogin),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      AnimatedSize(
                        duration: 250.ms,
                        curve: Curves.easeOutCubic,
                        child: Column(
                          children: [
                            if (!_isLogin) ...[
                              LiquidGlassInput(
                                controller: _nameCtrl,
                                hintText: 'Display name',
                                prefixIcon: const Icon(Icons.person_outline, size: 20),
                                validator: (v) => null,
                              ),
                              const SizedBox(height: 14),
                            ],
                          ],
                        ),
                      ),
                      LiquidGlassInput(
                        controller: _emailCtrl,
                        hintText: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.email_outlined, size: 20),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          final emailRegex = RegExp(
                            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                          );
                          if (!emailRegex.hasMatch(v.trim())) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      LiquidGlassInput(
                        controller: _passwordCtrl,
                        hintText: 'Password',
                        obscureText: _obscure,
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                        validator: (v) {
                          if (v == null || v.length < 6) {
                            return 'At least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
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
                                : Text(
                                    _isLogin ? 'Sign in' : 'Create account',
                                    key: ValueKey(_isLogin),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () =>
                            setState(() => _isLogin = !_isLogin),
                        child: Text.rich(
                          TextSpan(
                            text: _isLogin
                                ? "Don't have an account? "
                                : 'Already have an account? ',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w400,
                            ),
                            children: [
                              TextSpan(
                                text: _isLogin ? 'Sign up' : 'Sign in',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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
                      curve: Curves.easeOutCubic),
            ),
          ),
        ),
      ),
    );
  }
}
