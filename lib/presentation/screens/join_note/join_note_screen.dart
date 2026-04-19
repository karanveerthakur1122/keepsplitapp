import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/datasources/remote/supabase_collaborator_datasource.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/liquid_glass/liquid_glass_modal.dart';

class JoinNoteScreen extends ConsumerStatefulWidget {
  const JoinNoteScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<JoinNoteScreen> createState() => _JoinNoteScreenState();
}

class _JoinNoteScreenState extends ConsumerState<JoinNoteScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _joinNote();
  }

  Future<void> _joinNote() async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        setState(() {
          _error = 'You must be logged in to join a note';
          _loading = false;
        });
        return;
      }

      final client = ref.read(supabaseClientProvider);
      final datasource = SupabaseCollaboratorDatasource(client);
      await datasource.joinViaToken(widget.token, user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully joined the note!')),
        );
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _humanError(e);
          _loading = false;
        });
      }
    }
  }

  String _humanError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('invalid share token')) {
      return 'This invite link is invalid or has expired.';
    }
    if (s.contains('not authenticated')) {
      return 'You must be signed in to join a note.';
    }
    if (s.contains('violates foreign key') || s.contains('23503')) {
      return 'Account setup incomplete. Please sign out and sign back in, then try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0B1220), const Color(0xFF1a1040)]
                : [const Color(0xFFe0e7ff), const Color(0xFFf0e6ff)],
          ),
        ),
        child: Center(
          child: LiquidGlassModal(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loading) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Joining note...'),
                ] else if (_error != null) ...[
                  Icon(Icons.error_outline, size: 48, color: scheme.error),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to join',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/dashboard'),
                    child: const Text('Go to Dashboard'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
