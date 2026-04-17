import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/constants/supabase_constants.dart';

void main() {
  // Do only the *synchronous* binding here so runApp is reached in the first
  // frame. All other startup work (dotenv, Supabase session restore, display
  // mode) happens AFTER the first paint — the user sees a splash almost
  // immediately instead of waiting ~300-500ms for cold init to finish.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Boot());
}

class _Boot extends StatefulWidget {
  const _Boot();
  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  late final Future<void> _ready = _bootstrap();

  Future<void> _bootstrap() async {
    // dotenv must finish before Supabase.initialize (SupabaseConstants reads
    // from it). Everything else runs in parallel afterwards.
    await dotenv.load(fileName: '.env');
    await Future.wait<void>([
      Supabase.initialize(
        url: SupabaseConstants.supabaseUrl,
        anonKey: SupabaseConstants.supabaseAnonKey,
      ),
      _tryEnableHighRefreshRate(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _BootError(error: snapshot.error!);
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const _Splash();
        }
        return const ProviderScope(child: KeepBillNotesApp());
      },
    );
  }
}

/// Minimal first-frame widget. Matches the dark launch background so there's
/// no flash between the Android launch theme and the first Flutter frame.
class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFF0B0718),
        child: Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(Color(0xFFB79BFF)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown if bootstrap fails (usually missing / bad .env or network handshake
/// error). Small + dependency-free so it can render even when nothing is set
/// up.
class _BootError extends StatelessWidget {
  const _BootError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF0B0718),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'Failed to start Keepsplit.\n\n$error',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _tryEnableHighRefreshRate() async {
  if (kIsWeb) return;
  if (!Platform.isAndroid) return;
  try {
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (_) {
    // Devices without multiple display modes just stay at their default.
  }
}
