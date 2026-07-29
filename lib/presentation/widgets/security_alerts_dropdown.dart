import 'package:flutter/material.dart';
import '../../services/firebase_sync_service.dart';
import '../master_admin/security_alerts_screen.dart';

class SecurityAlertsDropdown extends StatelessWidget {
  const SecurityAlertsDropdown({super.key});

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
        stream: FirebaseSyncService().getLiveSecurityAlertsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final alerts = snapshot.data ?? [];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Text('Security Alerts (${alerts.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                  ],
                ),
              ),
              if (alerts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('No active security alerts', style: TextStyle(color: Colors.grey)),
                )
              else
                ...alerts.take(3).map((alert) {
                  final isFailedLogin = alert['type'] == 'unauthorized_attempt' || alert['type'] == 'failed_login';
                  final shopText = alert['shopName'] ?? alert['shopCode'] ?? 'Unknown Shop';
                  final subtitleText = alert['subtitle'] ?? ('Attempted Device: ' + (alert['attemptedDeviceId'] ?? 'Unknown'));
                  return Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          isFailedLogin ? Icons.login : Icons.devices_other,
                          color: isFailedLogin ? Colors.orange : Colors.red,
                        ),
                        title: Text(alert['title'] ?? (isFailedLogin ? 'Failed Login Attempt' : 'Security Warning'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('Shop: $shopText\n$subtitleText', style: const TextStyle(fontSize: 11)),
                        isThreeLine: true,
                        trailing: TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Flagged alert for ${alert['shopCode']}')),
                            );
                          },
                          child: Text(isFailedLogin ? 'Block' : 'Review', style: const TextStyle(fontSize: 12)),
                        ),
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
                      child: const Text('View All', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626)))),
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
