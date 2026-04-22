import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_item.dart';
import '../../domain/entities/note.dart';
import '../../domain/entities/participant.dart';

const demoNoteId = '00000000-0000-0000-0000-000000000001';
const demoKaranId = 'demo-karan';
const demoVeerId = 'demo-veer';
const demoThakurId = 'demo-thakur';

final demoNote = Note(
  id: demoNoteId,
  userId: demoKaranId,
  title: 'Weekend Trip \u2014 Goa',
  content:
      'A sample note showing how Keepsplit tracks shared expenses, balances, and settlements.',
  color: '#6C63FF',
  isPinned: false,
  isArchived: false,
  labels: const ['_demo'],
  createdAt: DateTime(2026, 4, 20, 10, 0),
  updatedAt: DateTime(2026, 4, 20, 18, 30),
);

final demoManualUsers = [
  (id: demoKaranId, displayName: 'Karan'),
  (id: demoVeerId, displayName: 'Veer'),
  (id: demoThakurId, displayName: 'Thakur'),
];

final _now = DateTime(2026, 4, 20, 12, 0);

final demoExpenses = <Expense>[
  Expense(
    id: 'demo-expense-hotel',
    noteId: demoNoteId,
    payerId: demoKaranId,
    createdAt: _now,
    items: [
      ExpenseItem(
        id: 'demo-item-room',
        expenseId: 'demo-expense-hotel',
        name: 'Room (2 nights)',
        price: 4500,
        createdAt: _now,
        participants: [
          const Participant(
              id: 'dp-room-k', itemId: 'demo-item-room', userId: demoKaranId),
          const Participant(
              id: 'dp-room-v', itemId: 'demo-item-room', userId: demoVeerId),
          const Participant(
              id: 'dp-room-t', itemId: 'demo-item-room', userId: demoThakurId),
        ],
      ),
    ],
  ),
  Expense(
    id: 'demo-expense-dinner',
    noteId: demoNoteId,
    payerId: demoVeerId,
    createdAt: _now.add(const Duration(hours: 2)),
    items: [
      ExpenseItem(
        id: 'demo-item-pizza',
        expenseId: 'demo-expense-dinner',
        name: 'Pizza',
        price: 600,
        createdAt: _now.add(const Duration(hours: 2)),
        participants: [
          const Participant(
              id: 'dp-pizza-k',
              itemId: 'demo-item-pizza',
              userId: demoKaranId),
          const Participant(
              id: 'dp-pizza-v',
              itemId: 'demo-item-pizza',
              userId: demoVeerId),
        ],
      ),
      ExpenseItem(
        id: 'demo-item-drinks',
        expenseId: 'demo-expense-dinner',
        name: 'Drinks',
        price: 300,
        createdAt: _now.add(const Duration(hours: 2, minutes: 15)),
        participants: [
          const Participant(
              id: 'dp-drinks-k',
              itemId: 'demo-item-drinks',
              userId: demoKaranId),
          const Participant(
              id: 'dp-drinks-v',
              itemId: 'demo-item-drinks',
              userId: demoVeerId),
          const Participant(
              id: 'dp-drinks-t',
              itemId: 'demo-item-drinks',
              userId: demoThakurId),
        ],
      ),
    ],
  ),
  Expense(
    id: 'demo-expense-cab',
    noteId: demoNoteId,
    payerId: demoThakurId,
    createdAt: _now.add(const Duration(hours: 4)),
    items: [
      ExpenseItem(
        id: 'demo-item-cab',
        expenseId: 'demo-expense-cab',
        name: 'Airport Transfer',
        price: 900,
        createdAt: _now.add(const Duration(hours: 4)),
        participants: [
          const Participant(
              id: 'dp-cab-k',
              itemId: 'demo-item-cab',
              userId: demoKaranId),
          const Participant(
              id: 'dp-cab-v',
              itemId: 'demo-item-cab',
              userId: demoVeerId),
          const Participant(
              id: 'dp-cab-t',
              itemId: 'demo-item-cab',
              userId: demoThakurId),
        ],
      ),
    ],
  ),
];

/// Name map used by the demo settlement provider so it never hits Supabase.
const demoParticipantNames = <String, String>{
  demoKaranId: 'Karan',
  demoVeerId: 'Veer',
  demoThakurId: 'Thakur',
};
