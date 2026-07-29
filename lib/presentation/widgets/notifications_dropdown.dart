import 'package:flutter/material.dart';
import '../../services/firebase_sync_service.dart';
import '../master_admin/notifications_screen.dart';

class NotificationsDropdown extends StatelessWidget {
  const NotificationsDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseSyncService().getLiveNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final notifications = snapshot.data ?? [];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications, color: Color(0xFF4338CA)),
                    const SizedBox(width: 8),
                    Text('Notifications (${notifications.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3730A3))),
                  ],
                ),
              ),
              if (notifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('No new notifications', style: TextStyle(color: Colors.grey)),
                )
              else
                ...notifications.take(3).map((notif) {
                  return Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: notif['bgColor'] as Color,
                          child: Icon(notif['icon'] as IconData, color: notif['iconColor'] as Color, size: 20),
                        ),
                        title: Text(notif['title'] ?? 'Notification', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(notif['subtitle'] ?? '', style: const TextStyle(fontSize: 11)),
                        trailing: Text(notif['timeStr'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                      const Divider(height: 1),
                    ],
                  );
                }),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, 'view_all');
                      },
                      child: const Text('View All', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)))),
                  ],
                ),
              )
            ],
          );
        }
      ),
    );
  }
}
