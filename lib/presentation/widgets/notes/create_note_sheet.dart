import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/haptics.dart';
import '../../providers/notes_provider.dart';
import '../liquid_glass/liquid_glass_input.dart';

class CreateNoteSheet extends ConsumerStatefulWidget {
  const CreateNoteSheet({super.key});

  @override
  ConsumerState<CreateNoteSheet> createState() => _CreateNoteSheetState();
}

class _CreateNoteSheetState extends ConsumerState<CreateNoteSheet> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _titleFocus = FocusNode();
  bool _loading = false;
  bool _isPinned = false;
  bool _didSave = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  bool get _hasContent =>
      _titleCtrl.text.trim().isNotEmpty || _contentCtrl.text.trim().isNotEmpty;

  Future<void> _saveAndClose() async {
    if (_didSave || !_hasContent) {
      if (mounted) Navigator.pop(context);
      return;
    }
    _didSave = true;
    Haptics.select();
    setState(() => _loading = true);
    try {
      final note = await ref.read(notesProvider.notifier).create(
            title: _titleCtrl.text.trim(),
            content: _contentCtrl.text.trim(),
          );
      if (_isPinned) {
        await ref.read(notesProvider.notifier).pin(note.id, true);
      }
      if (mounted) Navigator.pop(context, note);
    } catch (e) {
      _didSave = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create note')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _cancel() {
    _didSave = true;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Only block pop while we have unsaved content (so we can auto-save).
    // Otherwise, let the sheet close normally when the user taps outside /
    // swipes down / presses back.
    final shouldInterceptPop = !_didSave && _hasContent && !_loading;

    return PopScope(
      canPop: !shouldInterceptPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _saveAndClose();
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13102B) : const Color(0xFFFAF8FF),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 12,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: LiquidGlassInput(
                      controller: _titleCtrl,
                      hintText: 'Title',
                      focusNode: _titleFocus,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      Haptics.select();
                      setState(() => _isPinned = !_isPinned);
                    },
                    icon: Icon(
                      _isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      color: _isPinned ? scheme.primary : scheme.onSurfaceVariant,
                      size: 20,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: _isPinned
                          ? scheme.primary.withValues(alpha: 0.1)
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    tooltip: _isPinned ? 'Unpin' : 'Pin',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LiquidGlassInput(
                controller: _contentCtrl,
                hintText: 'Take a note...',
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: _cancel,
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _loading ? null : _saveAndClose,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: _loading
                          ? const SizedBox(
                              key: ValueKey('l'),
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save', key: ValueKey('t')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
