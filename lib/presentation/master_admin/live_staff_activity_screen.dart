import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_sync_service.dart';
import 'master_admin_shell.dart';

class LiveStaffActivityScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  final bool hideAppBar;
  const LiveStaffActivityScreen({
    super.key,
    this.onOpenDrawer,
    this.hideAppBar = false,
  });

  IconData _getActivityIcon(String action) {
    final a = action.toLowerCase();
    if (a.contains('checkout') || a.contains('order') || a.contains('sale'))
      return Icons.shopping_cart_outlined;
    if (a.contains('login') || a.contains('session'))
      return Icons.vpn_key_outlined;
    if (a.contains('product') || a.contains('inventory'))
      return Icons.inventory_2_outlined;
    if (a.contains('expense')) return Icons.payments_outlined;
    if (a.contains('refund')) return Icons.keyboard_return_outlined;
    if (a.contains('printer') || a.contains('receipt'))
      return Icons.print_outlined;
    return Icons.person_outline;
  }

  Color _getActivityColor(String action) {
    final a = action.toLowerCase();
    if (a.contains('checkout') || a.contains('order') || a.contains('sale'))
      return const Color(0xFF10B981); // Emerald Green
    if (a.contains('login') || a.contains('session'))
      return const Color(0xFF3B82F6); // Blue
    if (a.contains('product') || a.contains('inventory'))
      return const Color(0xFF8B5CF6); // Violet
    if (a.contains('expense')) return const Color(0xFFF59E0B); // Orange
    if (a.contains('refund')) return const Color(0xFFEF4444); // Red
    return const Color(0xFF6366F1); // Indigo
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: hideAppBar
          ? null
          : AppBar(
              title: const Text(
                'Live Staff Activity',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              backgroundColor: const Color(0xFF1E293B),
              iconTheme: const IconThemeData(color: Colors.white),
              elevation: 0,
              leading: onOpenDrawer != null
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: onOpenDrawer,
                    )
                  : null,
            ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseSyncService().getLiveStaffActivityStreamCustom(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_toggle_off,
                    size: 64,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No recent staff activity logged.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          final activities = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final isLast = index == activities.length - 1;
              final data = activities[index];
              final action = data['action'] ?? 'Unknown Action';
              final shopCodeStr = data['shopCode'] ?? 'Unknown Shop';

              DateTime? time;
              if (data['timestamp'] is Timestamp) {
                time = (data['timestamp'] as Timestamp).toDate();
              } else if (data['timestamp'] is DateTime) {
                time = data['timestamp'] as DateTime;
              }

              final timeStr = time != null
                  ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                  : 'Just now';

              final themeColor = _getActivityColor(action);
              final iconData = _getActivityIcon(action);

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline wire and node icon
                    Column(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: themeColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: themeColor, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: themeColor.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(iconData, color: themeColor, size: 18),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: const Color(0xFF334155),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Timeline Item Card Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF334155)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      action,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.store,
                                          color: Colors.grey,
                                          size: 12,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            shopCodeStr,
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                                child: Text(
                                  timeStr,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
