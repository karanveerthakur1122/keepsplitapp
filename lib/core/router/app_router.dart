import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../presentation/screens/auth/auth_screen.dart';
import '../../presentation/screens/dashboard/dashboard_screen.dart';
import '../../presentation/screens/join_note/join_note_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/widgets/common/animated_list_item.dart';

String? _authRedirect(GoRouterState state) {
  final session = Supabase.instance.client.auth.currentSession;
  final loggedIn = session != null;
  final location = state.uri.path;

  if (location == '/') {
    return loggedIn ? '/dashboard' : '/auth';
  }

  if (location == '/auth' && loggedIn) {
    return '/dashboard';
  }

  final isProtected =
      location.startsWith('/dashboard') || location.startsWith('/settings');
  if (isProtected && !loggedIn) {
    return '/auth';
  }

  if (location.startsWith('/join') && !loggedIn) {
    return '/auth';
  }

  return null;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier();
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) => _authRedirect(state),
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, __) => '/dashboard',
      ),
      GoRoute(
        path: '/auth',
        pageBuilder: (context, state) => _sharedAxis(
          state,
          const AuthScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard',
        pageBuilder: (context, state) => _sharedAxis(
          state,
          const DashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => _sharedAxis(
          state,
          const _SettingsPage(),
        ),
      ),
      GoRoute(
        path: '/join/:token',
        pageBuilder: (context, state) {
          final token = state.pathParameters['token']!;
          return _sharedAxis(state, JoinNoteScreen(token: token));
        },
      ),
    ],
  );
});

/// Horizontal shared-axis page transition used for secondary routes (auth,
/// settings, join). The new page slides in from the right while the old page
/// slides out to the left, both fading — feels like a cohesive stack push.
CustomTransitionPage<T> _sharedAxis<T>(GoRouterState state, Widget child) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, anim, secondary, child) {
      const inCurve = Curves.easeOutCubic;
      const outCurve = Curves.easeInCubic;

      final forward = Tween<Offset>(
        begin: const Offset(0.12, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: inCurve));
      final back = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.08, 0),
      ).animate(CurvedAnimation(parent: secondary, curve: outCurve));

      return SlideTransition(
        position: forward,
        child: SlideTransition(
          position: back,
          child: FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: inCurve),
            child: child,
          ),
        ),
      );
    },
  );
}

class _AuthRefreshNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _sub;
  String? _lastUserId;

  _AuthRefreshNotifier() {
    _lastUserId = Supabase.instance.client.auth.currentUser?.id;
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      final newId = event.session?.user.id;
      // When the signed-in user changes (sign-out + sign-in, or account
      // switch), reset per-session UI memos so they don't leak across users.
      if (newId != _lastUserId) {
        _lastUserId = newId;
        resetAnimatedListItemMemo();
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0B1220), const Color(0xFF131a2e)]
                : [const Color(0xFFe8eef7), const Color(0xFFf0e6ff)],
          ),
        ),
        child: const SettingsScreen(),
      ),
    );
  }
}
