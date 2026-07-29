import 'package:flutter/material.dart';
import '../../services/firebase_sync_service.dart';
import 'master_admin_shell.dart'; // for kMasterWorkspaceColor

class SecurityAlertsScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  final bool hideAppBar;
  const SecurityAlertsScreen({
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
                'Security Alerts Console',
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
        stream: FirebaseSyncService().getLiveSecurityAlertsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final alerts = snapshot.data ?? [];
          if (alerts.isEmpty) {
            return const Center(
              child: Text(
                'No security alerts found.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              final isFailedLogin =
                  alert['type'] == 'unauthorized_attempt' ||
                  alert['type'] == 'failed_login';
              final shopText =
                  alert['shopName'] ?? alert['shopCode'] ?? 'Unknown Shop';
              final subtitleText =
                  alert['subtitle'] ??
                  ('Attempted Device: ' +
                      (alert['attemptedDeviceId'] ?? 'Unknown'));

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2), // Very soft red background
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFEE2E2), width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.white,
                      blurRadius: 6,
                      offset: Offset(-3, -3),
                    ),
                    BoxShadow(
                      color: Color(0xFFE5E7EB),
                      blurRadius: 6,
                      offset: Offset(3, 3),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: isFailedLogin
                        ? const Color(0xFFFFEDD5)
                        : const Color(0xFFFEE2E2),
                    child: Icon(
                      isFailedLogin ? Icons.login : Icons.devices_other,
                      color: isFailedLogin ? Colors.orange : Colors.red,
                    ),
                  ),
                  title: Text(
                    alert['title'] ??
                        (isFailedLogin
                            ? 'Failed Login Attempt'
                            : 'Security Warning'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Shop: $shopText\n$subtitleText',
                      style: const TextStyle(
                        color: Color(0xFF7F1D1D),
                        height: 1.4,
                      ),
                    ),
                  ),
                  trailing: Container(
                    decoration: BoxDecoration(
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.white,
                          blurRadius: 4,
                          offset: Offset(-2, -2),
                        ),
                        BoxShadow(
                          color: Color(0xFFFCA5A5),
                          blurRadius: 4,
                          offset: Offset(2, 2),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Flagged alert for ${alert['shopCode']}',
                            ),
                          ),
                        );
                      },
                      child: Text(isFailedLogin ? 'Block' : 'Review'),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
