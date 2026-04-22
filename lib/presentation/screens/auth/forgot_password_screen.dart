import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_toast.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/liquid_glass/liquid_glass_modal.dart';
import '../../widgets/liquid_glass/liquid_glass_input.dart';

enum _Step { email, otp, newPassword }

// ── Attempt-limit security (flip to true to enforce) ──
const _kEnforceAttemptLimit = true;
const _kMaxOtpSends = 5;
const _kMaxOtpVerifies = 8;
const _kBlockDuration = Duration(minutes: 15);

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  static const _otpLength = 8;
  final List<TextEditingController> _otpCtrls =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _otpFocuses = List.generate(_otpLength, (_) => FocusNode());

  _Step _step = _Step.email;
  bool _loading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  int _otpSendAttempts = 0;
  int _otpVerifyAttempts = 0;
  DateTime? _blockedUntil;

  bool get _isBlocked {
    if (!_kEnforceAttemptLimit) return false;
    if (_blockedUntil == null) return false;
    if (DateTime.now().isAfter(_blockedUntil!)) {
      _blockedUntil = null;
      _otpSendAttempts = 0;
      _otpVerifyAttempts = 0;
      return false;
    }
    return true;
  }

  void _checkAndBlock() {
    if (!_kEnforceAttemptLimit) return;
    if (_otpSendAttempts >= _kMaxOtpSends ||
        _otpVerifyAttempts >= _kMaxOtpVerifies) {
      _blockedUntil = DateTime.now().add(_kBlockDuration);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final f in _otpFocuses) {
      f.dispose();
    }
    _cooldownTimer?.cancel();
    super.dispose();
  }

  String get _otpCode => _otpCtrls.map((c) => c.text).join();

  void _startCooldown() {
    _cooldownSeconds = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) timer.cancel();
      });
    });
  }

  Future<void> _sendOtp() async {
    if (_isBlocked) {
      AppToast.error('Too many attempts. Please try again later.');
      return;
    }
    if (_cooldownSeconds > 0) return;
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    _otpSendAttempts++;
    _checkAndBlock();

    try {
      await ref
          .read(authRepositoryProvider)
          .resetPasswordForEmail(_emailCtrl.text.trim());
      AppToast.success('OTP sent! Check your email.');
      _startCooldown();
      if (mounted) setState(() => _step = _Step.otp);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('too many requests') || msg.contains('rate limit')) {
        _startCooldown();
        if (_step == _Step.email) {
          AppToast.info('OTP was already sent. Check your email.');
          if (mounted) setState(() => _step = _Step.otp);
        } else {
          AppToast.error('Please wait before requesting another code.');
        }
      } else {
        AppToast.error(_friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_isBlocked) {
      AppToast.error('Too many attempts. Please try again later.');
      return;
    }
    final code = _otpCode;
    if (code.length != _otpLength) {
      AppToast.error('Please enter the full $_otpLength-digit code.');
      return;
    }
    setState(() => _loading = true);
    _otpVerifyAttempts++;
    _checkAndBlock();

    try {
      await ref.read(authRepositoryProvider).verifyOtp(
            email: _emailCtrl.text.trim(),
            token: code,
          );
      AppToast.success('Verified! Set your new password.');
      if (mounted) setState(() => _step = _Step.newPassword);
    } catch (e) {
      AppToast.error(_friendlyOtpError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updatePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      await ref
          .read(authRepositoryProvider)
          .updatePassword(_passwordCtrl.text);
      AppToast.success('Password updated!');
      if (mounted) context.go('/dashboard');
    } catch (e) {
      AppToast.error(_friendlyPasswordError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_isBlocked) {
      AppToast.error('Too many attempts. Please try again later.');
      return;
    }
    if (_cooldownSeconds > 0) return;
    setState(() => _loading = true);
    _otpSendAttempts++;
    _checkAndBlock();
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPasswordForEmail(_emailCtrl.text.trim());
      AppToast.success('New OTP sent!');
      _startCooldown();
      for (final c in _otpCtrls) {
        c.clear();
      }
      _otpFocuses.first.requestFocus();
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('too many requests') || msg.contains('rate limit')) {
        _startCooldown();
        AppToast.error('Please wait before requesting another code.');
      } else {
        AppToast.error(_friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('host lookup')) {
      return 'No internet connection. Please check your network.';
    }
    if (msg.contains('too many requests') || msg.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment.';
    }
    return 'Something went wrong. Please try again.';
  }

  String _friendlyOtpError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('otp') && msg.contains('expired')) {
      return 'Code has expired. Please request a new one.';
    }
    if (msg.contains('invalid') || msg.contains('otp')) {
      return 'Invalid code. Please check and try again.';
    }
    return _friendlyError(e);
  }

  String _friendlyPasswordError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('same password') || msg.contains('same_password')) {
      return 'New password must be different from the old one.';
    }
    if (msg.contains('weak password') || msg.contains('password')) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    if (msg.contains('session') || msg.contains('not authenticated')) {
      return 'Session expired. Please start over.';
    }
    return _friendlyError(e);
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
                child: AnimatedSize(
                  duration: 300.ms,
                  curve: Curves.easeOutCubic,
                  child: AnimatedSwitcher(
                    duration: 300.ms,
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: switch (_step) {
                      _Step.email => _buildEmailStep(scheme),
                      _Step.otp => _buildOtpStep(scheme),
                      _Step.newPassword => _buildPasswordStep(scheme),
                    },
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

  // ─── Step 1: Email ───

  Widget _buildEmailStep(ColorScheme scheme) {
    return Form(
      key: _emailFormKey,
      child: Column(
        key: const ValueKey('email'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_reset_rounded, size: 52, color: scheme.primary),
          const SizedBox(height: 16),
          Text(
            'Reset Password',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your email and we\'ll send you an\n8-digit code to reset your password.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 28),
          LiquidGlassInput(
            controller: _emailCtrl,
            hintText: 'Email',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined, size: 20),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              final re = RegExp(
                  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
              if (!re.hasMatch(v.trim())) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 24),
          _actionButton('Send OTP', _loading ? null : _sendOtp),
          const SizedBox(height: 16),
          _backToSignIn(scheme),
        ],
      ),
    );
  }

  // ─── Step 2: OTP ───

  Widget _buildOtpStep(ColorScheme scheme) {
    return Form(
      key: _otpFormKey,
      child: Column(
        key: const ValueKey('otp'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pin_rounded, size: 52, color: scheme.primary),
          const SizedBox(height: 16),
          Text(
            'Enter Code',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'We sent an 8-digit code to\n${_emailCtrl.text.trim()}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 28),
          _buildOtpFields(scheme),
          const SizedBox(height: 24),
          _actionButton('Verify', _loading ? null : _verifyOtp),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _cooldownSeconds > 0 || _loading ? null : _resendOtp,
            child: Text(
              _cooldownSeconds > 0
                  ? 'Resend code in ${_cooldownSeconds}s'
                  : 'Resend code',
              style: TextStyle(
                color: _cooldownSeconds > 0
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
                    : scheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => setState(() {
              _step = _Step.email;
              for (final c in _otpCtrls) {
                c.clear();
              }
            }),
            child: Text.rich(
              TextSpan(
                text: 'Wrong email? ',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
                children: [
                  TextSpan(
                    text: 'Go back',
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
    );
  }

  Widget _buildOtpFields(ColorScheme scheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.70);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.5);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_otpLength, (i) {
        final halfPoint = _otpLength ~/ 2;
        return Container(
          width: 38,
          height: 48,
          margin: EdgeInsets.only(
            left: i == 0 ? 0 : (i == halfPoint ? 12 : 4),
          ),
          child: TextFormField(
            controller: _otpCtrls[i],
            focusNode: _otpFocuses[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: fillColor,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: scheme.primary, width: 1.5),
              ),
            ),
            onChanged: (value) {
              if (value.isNotEmpty && i < _otpLength - 1) {
                _otpFocuses[i + 1].requestFocus();
              }
              if (value.isEmpty && i > 0) {
                _otpFocuses[i - 1].requestFocus();
              }
              if (_otpCode.length == _otpLength) {
                FocusScope.of(context).unfocus();
                _verifyOtp();
              }
            },
          ),
        );
      }),
    );
  }

  // ─── Step 3: New Password ───

  Widget _buildPasswordStep(ColorScheme scheme) {
    return Form(
      key: _passwordFormKey,
      child: Column(
        key: const ValueKey('password'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.password_rounded, size: 52, color: scheme.primary),
          const SizedBox(height: 16),
          Text(
            'New Password',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a strong new password\nfor your account.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 28),
          LiquidGlassInput(
            controller: _passwordCtrl,
            hintText: 'New password',
            obscureText: _obscureNew,
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
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
              if (v == null || v.length < 6) return 'At least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 14),
          LiquidGlassInput(
            controller: _confirmCtrl,
            hintText: 'Confirm password',
            obscureText: _obscureConfirm,
            prefixIcon: const Icon(Icons.lock_outline, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password';
              if (v != _passwordCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 24),
          _actionButton(
              'Update Password', _loading ? null : _updatePassword),
        ],
      ),
    );
  }

  // ─── Shared widgets ───

  Widget _actionButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: onPressed,
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
              : Text(label, key: ValueKey(label)),
        ),
      ),
    );
  }

  Widget _backToSignIn(ColorScheme scheme) {
    return TextButton(
      onPressed: () => context.go('/auth'),
      child: Text.rich(
        TextSpan(
          text: 'Back to ',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w400,
          ),
          children: [
            TextSpan(
              text: 'Sign in',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
