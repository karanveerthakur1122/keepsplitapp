import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/demo_data.dart';
import 'auth_provider.dart';

// ── Currency helpers ───────────────────────────────────────────────

class CurrencyInfo {
  const CurrencyInfo(this.code, this.symbol, this.name);
  final String code;
  final String symbol;
  final String name;
}

const currencies = <CurrencyInfo>[
  CurrencyInfo('INR', '₹', 'Indian Rupee'),
  CurrencyInfo('USD', '\$', 'US Dollar'),
  CurrencyInfo('EUR', '€', 'Euro'),
  CurrencyInfo('GBP', '£', 'British Pound'),
  CurrencyInfo('JPY', '¥', 'Japanese Yen'),
  CurrencyInfo('CNY', '¥', 'Chinese Yuan'),
  CurrencyInfo('AUD', 'A\$', 'Australian Dollar'),
  CurrencyInfo('CAD', 'C\$', 'Canadian Dollar'),
  CurrencyInfo('SGD', 'S\$', 'Singapore Dollar'),
  CurrencyInfo('AED', 'د.إ', 'UAE Dirham'),
  CurrencyInfo('BDT', '৳', 'Bangladeshi Taka'),
  CurrencyInfo('THB', '฿', 'Thai Baht'),
  CurrencyInfo('KRW', '₩', 'Korean Won'),
  CurrencyInfo('BRL', 'R\$', 'Brazilian Real'),
];

String currencySymbol(String code) {
  for (final c in currencies) {
    if (c.code == code) return c.symbol;
  }
  return code;
}

// ── Expense settings (currency) per note ──────────────────────────

typedef ExpenseSettings = ({String currency});

final noteExpenseSettingsProvider =
    FutureProvider.family<ExpenseSettings, String>((ref, noteId) async {
  if (noteId == demoNoteId) return (currency: 'INR');
  final client = ref.watch(supabaseClientProvider);
  final row = await client
      .from('note_expense_settings')
      .select('currency')
      .eq('note_id', noteId)
      .maybeSingle();
  final currency = (row?['currency'] as String?) ?? 'INR';
  return (currency: currency);
});

Future<void> updateNoteCurrency(
  WidgetRef ref, {
  required String noteId,
  required String currency,
}) async {
  final client = ref.read(supabaseClientProvider);
  await client.from('note_expense_settings').upsert(
    {'note_id': noteId, 'currency': currency},
    onConflict: 'note_id',
  );
  ref.invalidate(noteExpenseSettingsProvider(noteId));
}

// ── Manual users per note ─────────────────────────────────────────

typedef ManualUser = ({String id, String displayName});

final noteManualUsersProvider =
    FutureProvider.family<List<ManualUser>, String>((ref, noteId) async {
  if (noteId == demoNoteId) return demoManualUsers;
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('note_manual_users')
      .select('id, display_name')
      .eq('note_id', noteId)
      .order('created_at', ascending: true);
  return (rows as List)
      .map((r) => (
            id: r['id'] as String,
            displayName: r['display_name'] as String,
          ))
      .toList();
});

Future<void> addManualUser(
  WidgetRef ref, {
  required String noteId,
  required String displayName,
}) async {
  final client = ref.read(supabaseClientProvider);
  final user = ref.read(currentUserProvider);
  if (user == null) return;
  await client.from('note_manual_users').insert({
    'note_id': noteId,
    'display_name': displayName.trim(),
    'created_by': user.id,
  });
  ref.invalidate(noteManualUsersProvider(noteId));
}

Future<void> removeManualUser(WidgetRef ref, {
  required String noteId,
  required String manualUserId,
}) async {
  final client = ref.read(supabaseClientProvider);
  await client.from('note_manual_users').delete().eq('id', manualUserId);
  ref.invalidate(noteManualUsersProvider(noteId));
}

Future<void> renameManualUser(WidgetRef ref, {
  required String noteId,
  required String manualUserId,
  required String newName,
}) async {
  final client = ref.read(supabaseClientProvider);
  await client
      .from('note_manual_users')
      .update({'display_name': newName.trim()})
      .eq('id', manualUserId);
  ref.invalidate(noteManualUsersProvider(noteId));
}

// ── Expense audit timeline ────────────────────────────────────────

typedef AuditEntry = ({
  String id,
  String userId,
  String action,
  String entityType,
  Map<String, dynamic>? details,
  DateTime createdAt,
});

final noteExpenseAuditsProvider =
    FutureProvider.family<List<AuditEntry>, String>((ref, noteId) async {
  if (noteId == demoNoteId) return [];
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('expense_audits')
      .select()
      .eq('note_id', noteId)
      .order('created_at', ascending: false)
      .limit(100);
  return (rows as List).map((r) {
    return (
      id: r['id'] as String,
      userId: r['user_id'] as String,
      action: r['action'] as String,
      entityType: r['entity_type'] as String,
      details: r['details'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(r['created_at'] as String),
    );
  }).toList();
});
