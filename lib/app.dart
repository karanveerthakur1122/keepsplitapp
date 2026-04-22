import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_toast.dart';
import 'presentation/providers/sync_provider.dart';
import 'presentation/providers/theme_provider.dart';

class KeepBillNotesApp extends ConsumerStatefulWidget {
  const KeepBillNotesApp({super.key});

  @override
  ConsumerState<KeepBillNotesApp> createState() => _KeepBillNotesAppState();
}

class _KeepBillNotesAppState extends ConsumerState<KeepBillNotesApp> {
  @override
  void initState() {
    super.initState();
    // Kick off the offline sync engine AFTER the first frame so it doesn't
    // add to the cold-start latency. `read` eagerly creates it and calls
    // `start()` exactly once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(offlineSyncEngineProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Keepsplit',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: AppToast.scaffoldMessengerKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
