import 'package:flutter/material.dart';
import '../../services/firebase_sync_service.dart';
import 'master_admin_shell.dart'; // for kMasterWorkspaceColor

class NotificationsScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  final bool hideAppBar;
  const NotificationsScreen({
    super.key,
    this.onOpenDrawer,
    this.hideAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMasterWorkspaceColor,
      appBar: hideAppBar
          ? null
          : AppBar(
              title: const Text(
                'Notification Timeline',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              backgroundColor: kMasterWorkspaceColor,
              elevation: 0,
              foregroundColor: const Color(0xFF1E293B),
              leading: onOpenDrawer != null
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: onOpenDrawer,
                    )
                  : null,
            ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseSyncService().getLiveNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return const Center(
              child: Text(
                'No notifications found.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kMasterWorkspaceColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.white,
                      blurRadius: 6,
                      offset: Offset(-3, -3),
                    ),
                    BoxShadow(
                      color: Color(0xFFD1D9E6),
                      blurRadius: 6,
                      offset: Offset(3, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          (notif['bgColor'] as Color?) ??
                          const Color(0xFFE0E7FF),
                      radius: 20,
                      child: Icon(
                        (notif['icon'] as IconData?) ?? Icons.notifications,
                        color:
                            (notif['iconColor'] as Color?) ??
                            const Color(0xFF4F46E5),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notif['title'] ?? 'Notification',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notif['subtitle'] ?? '',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      notif['timeStr'] ?? '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
