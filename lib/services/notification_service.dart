import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<SystemNotification>> getUnreadNotifications() async {
    final response = await _supabase
        .from('notifications')
        .select()
        .eq('read', false)
        .order('timestamp', ascending: false)
        .limit(10);

    return (response as List)
        .map((item) => SystemNotification.fromMap(item))
        .toList();
  }

  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'read': true})
        .eq('id', notificationId);
  }

  RealtimeChannel setupRealtimeNotifications(Function(dynamic) callback) {
    final channel = _supabase.channel('notifications');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: callback,
        )
        .subscribe();
    return channel;
  }
}
