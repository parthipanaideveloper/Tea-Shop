import 'package:pos/core/utils/notification_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../providers/license_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/firebase_sync_service.dart';

class LicenseSettingsScreen extends ConsumerStatefulWidget {
  const LicenseSettingsScreen({super.key});

  @override
  ConsumerState<LicenseSettingsScreen> createState() =>
      _LicenseSettingsScreenState();
}

class _LicenseSettingsScreenState extends ConsumerState<LicenseSettingsScreen> {
  @override
  void dispose() {
    super.dispose();
  }

  void _showContactSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.support_agent, color: Colors.blue),
            SizedBox(width: 10),
            Text('Contact Support'),
          ]),
        content: Text(
          'To renew or extend your subscription validity, please contact Customer Support at ${FirebaseSyncService().getSupportPhoneNumber()}. '
          'Once extended, your device will automatically update the new validity date securely.',
          style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
        ]));
  }

  Widget _buildStatusRow(
    String label,
    String value, {
    Color? textColor,
    FontWeight? fontWeight,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            color: textColor ?? Colors.black87,
            fontWeight: fontWeight ?? FontWeight.w600,
            fontSize: 14)),
      ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final license = ref.watch(licenseProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Subscription & Licensing',
          style: TextStyle(fontWeight: FontWeight.bold))),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<String>(
          'settings').listenable(keys: ['subscriptionEnd']),
        builder: (context, box, _) {
          final subEndStr = box.get('subscriptionEnd');
          final subEnd = subEndStr != null
              ? DateTime.tryParse(subEndStr)
              : license.subscriptionEnd;

          final isTrial =
              license.activationKey == null || license.activationKey!.isEmpty;
          final isExpired = subEnd != null && DateTime.now().isAfter(subEnd);
          final daysRemaining = subEnd != null
              ? subEnd.difference(DateTime.now()).inDays
              : 0;

          final String statusText;
          final Color statusColor;

          if (isTrial) {
            statusText = isExpired ? 'Trial Expired' : 'Active Trial';
            statusColor = isExpired ? Colors.red : Colors.green;
          } else {
            if (subEnd == null) {
              statusText = 'Lifetime Access';
              statusColor = Colors.green;
            } else {
              statusText = isExpired
                  ? 'Subscription Expired'
                  : 'Active Subscription ($daysRemaining days left)';
              statusColor = isExpired
                  ? Colors.red
                  : (daysRemaining <= 7 ? Colors.orange : Colors.green);
            }
          }

          final modeText = isTrial
              ? 'Trial License'
              : 'Full Commercial License';
          final expiryText = subEnd != null
              ? DateFormat('dd MMM yyyy, hh:mm a').format(subEnd)
              : 'No Expiration';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Current Status Card
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Licensing Status',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildStatusRow('Shop Name', settings.shopName),
                        const Divider(height: 24),
                        _buildStatusRow('License Mode', modeText),
                        const Divider(height: 24),
                        _buildStatusRow(
                          'Status',
                          statusText,
                          textColor: statusColor,
                          fontWeight: FontWeight.bold),
                        const Divider(height: 24),
                        _buildStatusRow('Expiry Date', expiryText),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Device ID',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 14)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  license.deviceId.length > 12
                                      ? '${license.deviceId.substring(0, 12)}...'
                                      : license.deviceId,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14)),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(
                                    Icons.copy,
                                    size: 16,
                                    color: Colors.blue),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: license.deviceId));
                                    NotificationHelper.showCenter(context, 'Device ID copied to clipboard!', isError: false);
                                  }),
                              ]),
                          ]),
                      ]))),
                const SizedBox(height: 20),

                // Info Box
                Card(
                  elevation: 0,
                  color: Colors.blue.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                shape: BoxShape.circle),
                              child: Icon(Icons.admin_panel_settings, color: Colors.blue.shade700, size: 28)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Subscription Management',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.blue.shade900)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Your subscription validity is securely managed by the system.',
                                    style: TextStyle(
                                      color: Colors.blue.shade800,
                                      fontSize: 13,
                                      height: 1.4)),
                                ])),
                          ]),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _showContactSupportDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                              elevation: 0),
                            icon: const Icon(Icons.support_agent),
                            label: const Text(
                              'REQUEST RENEWAL',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1)))),
                      ]))),
              ]));
        }));
  }
}
