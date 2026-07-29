import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_sync_service.dart';
import 'master_admin_shell.dart';

class LiveDeviceHealthScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  final bool hideAppBar;
  const LiveDeviceHealthScreen({
    super.key,
    this.onOpenDrawer,
    this.hideAppBar = false,
  });

  Widget _buildBatteryIndicator(int pct) {
    Color color = const Color(0xFF10B981); // Green
    IconData icon = Icons.battery_full;
    if (pct < 20) {
      color = const Color(0xFFEF4444); // Red
      icon = Icons.battery_alert;
    } else if (pct < 60) {
      color = const Color(0xFFF59E0B); // Amber
      icon = Icons.battery_3_bar;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            '$pct%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: hideAppBar
          ? null
          : AppBar(
              title: const Text(
                'Live Device Health',
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
        stream: FirebaseSyncService().getRegisteredDevicesStream(),
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
                    Icons.devices_other,
                    size: 64,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No devices currently tracking.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final data = snapshot.data![index];
              final bat = data['battery'] as int;
              final isOnline = data['isOnline'] as bool;
              final deviceId = data['deviceId'].toString();
              final deviceModel =
                  data['deviceModel']?.toString() ?? 'POS-001 Terminal';
              final shopName = data['shopName']?.toString() ?? 'Unknown Shop';
              final shopCode = data['shopCode']?.toString() ?? 'Unknown';

              DateTime? lastPingTime;
              if (data['lastPing'] is Timestamp) {
                lastPingTime = (data['lastPing'] as Timestamp).toDate();
              }

              final timeStr = lastPingTime != null
                  ? '${lastPingTime.day.toString().padLeft(2, '0')}/${lastPingTime.month.toString().padLeft(2, '0')} ${lastPingTime.hour.toString().padLeft(2, '0')}:${lastPingTime.minute.toString().padLeft(2, '0')}'
                  : 'Just now';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isOnline
                        ? const Color(0xFF10B981).withOpacity(0.2)
                        : const Color(0xFF334155),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Device Icon with glowing status ring
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0xFF10B981).withOpacity(0.12)
                            : const Color(0xFF334155).withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isOnline
                              ? const Color(0xFF10B981).withOpacity(0.3)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.settings_cell,
                        color: isOnline
                            ? const Color(0xFF10B981)
                            : const Color(0xFF94A3B8),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Device Info Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  deviceModel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildBatteryIndicator(bat),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Text(
                                'DEVICE ID: ',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                deviceId.length > 12
                                    ? deviceId.substring(0, 12)
                                    : deviceId,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Color(0xFF334155), height: 1),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'REGISTERED SHOP',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$shopName ($shopCode)',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'LAST PING',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    timeStr,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
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
