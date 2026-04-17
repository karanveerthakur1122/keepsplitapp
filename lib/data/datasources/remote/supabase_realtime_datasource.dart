import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeNotePayload {
  RealtimeNotePayload({required this.eventType, required this.noteId, this.data});
  final String eventType;
  final String noteId;
  final Map<String, dynamic>? data;
}

class PresenceUser {
  PresenceUser({required this.userId, required this.displayName, required this.color, this.isTyping = false});
  final String userId;
  final String displayName;
  final String color;
  final bool isTyping;
}

class SupabaseRealtimeDatasource {
  SupabaseRealtimeDatasource(this._client);
  final SupabaseClient _client;

  final _channels = <String, RealtimeChannel>{};

  static const _presenceColors = [
    '#EF4444', '#F59E0B', '#10B981', '#3B82F6',
    '#8B5CF6', '#EC4899', '#14B8A6', '#F97316',
  ];

  RealtimeChannel subscribeToNote(
    String noteId, {
    required void Function(Map<String, dynamic> payload) onUpdate,
  }) {
    final channelName = 'note-$noteId';
    _channels[channelName]?.unsubscribe();

    final channel = _client.channel(channelName);
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: noteId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();

    _channels[channelName] = channel;
    return channel;
  }

  RealtimeChannel subscribeToNotesList({
    required void Function() onAnyChange,
  }) {
    const channelName = 'notes-list';
    _channels[channelName]?.unsubscribe();

    final channel = _client.channel(channelName);
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notes',
          callback: (_) => onAnyChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'note_collaborators',
          callback: (_) => onAnyChange(),
        )
        .subscribe();

    _channels[channelName] = channel;
    return channel;
  }

  RealtimeChannel subscribeToExpenses(
    String noteId, {
    required void Function() onAnyChange,
  }) {
    final channelName = 'expenses-$noteId';
    _channels[channelName]?.unsubscribe();

    final channel = _client.channel(channelName);
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'expenses',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'note_id',
            value: noteId,
          ),
          callback: (_) => onAnyChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'expense_items',
          callback: (_) => onAnyChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'expense_item_participants',
          callback: (_) => onAnyChange(),
        )
        .subscribe();

    _channels[channelName] = channel;
    return channel;
  }

  RealtimeChannel trackPresence(
    String noteId, {
    required String userId,
    required String displayName,
    required void Function(List<PresenceUser> users) onSync,
  }) {
    final channelName = 'presence-$noteId';
    _channels[channelName]?.unsubscribe();

    final channel = _client.channel(
      channelName,
      opts: const RealtimeChannelConfig(self: true),
    );

    final colorIndex = userId.hashCode.abs() % _presenceColors.length;

    channel
        .onPresenceSync((payload) {
          final state = channel.presenceState();
          final users = <PresenceUser>[];
          for (final singleState in state) {
            for (final presence in singleState.presences) {
              final data = presence.payload;
              users.add(PresenceUser(
                userId: data['user_id'] as String? ?? '',
                displayName: data['display_name'] as String? ?? '',
                color: data['color'] as String? ?? '#999',
                isTyping: data['is_typing'] as bool? ?? false,
              ));
            }
          }
          onSync(users.where((u) => u.userId != userId).toList());
        })
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            channel.track({
              'user_id': userId,
              'display_name': displayName,
              'color': _presenceColors[colorIndex],
              'is_typing': false,
            });
          }
        });

    _channels[channelName] = channel;
    return channel;
  }

  void updateTyping(String noteId, bool isTyping) {
    final channel = _channels['presence-$noteId'];
    if (channel == null) return;

    final user = _client.auth.currentUser;
    if (user == null) return;

    final colorIndex = user.id.hashCode.abs() % _presenceColors.length;
    channel.track({
      'user_id': user.id,
      'display_name': user.userMetadata?['display_name'] ?? user.email ?? '',
      'color': _presenceColors[colorIndex],
      'is_typing': isTyping,
    });
  }

  void unsubscribe(String channelName) {
    _channels[channelName]?.unsubscribe();
    _channels.remove(channelName);
  }

  void unsubscribeAll() {
    for (final channel in _channels.values) {
      channel.unsubscribe();
    }
    _channels.clear();
  }
}
