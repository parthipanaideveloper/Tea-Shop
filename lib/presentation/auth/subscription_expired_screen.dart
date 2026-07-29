import 'package:pos/core/utils/notification_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/license_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_sync_service.dart';

class SubscriptionExpiredScreen extends ConsumerStatefulWidget {
  const SubscriptionExpiredScreen({super.key});

  @override
  ConsumerState<SubscriptionExpiredScreen> createState() =>
      _SubscriptionExpiredScreenState();
}

class _SubscriptionExpiredScreenState
    extends ConsumerState<SubscriptionExpiredScreen> {
  final _keyCtrl = TextEditingController();
  String? _errorMessage;

  Future<void> _contactSupport(String shopName, String deviceId) async {
    final message =
        "Hello support, I need to renew my DTS POS subscription.\n\nShop Name: $shopName\nDevice ID: $deviceId";
    final cleanPhone = FirebaseSyncService().getSupportPhoneNumber().replaceAll(RegExp(r'\D'), '');
    final url = Uri.parse(
      "https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          NotificationHelper.showCenter(context, 'Could not launch WhatsApp. Copying Device ID to clipboard.', isError: false);
          Clipboard.setData(ClipboardData(text: deviceId));
        }
      }
    } catch (_) {
      if (mounted) {
        Clipboard.setData(ClipboardData(text: deviceId));
        NotificationHelper.showCenter(context, 'Error launching WhatsApp. Device ID copied to clipboard.', isError: true);
      }
    }
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  void _activate() async {
    setState(() {
      _errorMessage = null;
    });

    final key = _keyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an activation key';
      });
      return;
    }

    final settings = ref.read(settingsProvider);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()));

    final success = await ref
        .read(licenseProvider.notifier)
        .activateLicense(key, settings.shopName);

    if (mounted) {
      Navigator.pop(context); // Dismiss loader
      if (success) {
        NotificationHelper.showCenter(context, 'Subscription activated successfully! 🎉', isError: false);
      } else {
        setState(() {
          _errorMessage = 'Invalid activation key for ${settings.shopName}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Lock icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle),
                        child: Icon(
                          Icons.lock_person_outlined,
                          size: 48,
                          color: Colors.red.shade700))),
                    const SizedBox(height: 24),
                    Text(
                      'Subscription Expired',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                    const SizedBox(height: 8),
                    Text(
                      'Subscription period ends. Please subscribe to continue.\n\nContact Number: +91 76677 40044',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        height: 1.5)),
                    const SizedBox(height: 24),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200)),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.bold))),
                      const SizedBox(height: 16),
                    ],

                    // License key input
                    TextField(
                      controller: _keyCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Activation / License Key',
                        hintText: 'Paste the base64 renewal key here...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder())),
                    const SizedBox(height: 20),

                    // Activate button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white),
                      onPressed: _activate,
                      child: const Text(
                        'ACTIVATE SYSTEM',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15))),
                    const SizedBox(height: 12),

                    // WhatsApp verification button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: Colors.green.shade600,
                          width: 1.5),
                        foregroundColor: Colors.green.shade800,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text(
                        'WhatsApp Support for Key',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        final license = ref.read(licenseProvider);
                        _contactSupport(settings.shopName, license.deviceId);
                      }),
                    const SizedBox(height: 16),

                    // Device ID Display
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Device Hardware ID:',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                              fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ref.watch(licenseProvider).deviceId,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87))),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.copy, size: 16),
                                onPressed: () {
                                  final license = ref.read(licenseProvider);
                                  Clipboard.setData(
                                    ClipboardData(text: license.deviceId));
                                  NotificationHelper.showCenter(context, 'Device ID copied to clipboard', isError: false);
                                }),
                            ]),
                        ])),
                    const SizedBox(height: 16),

                    // Simple logout to allow switching screens/users if needed
                    TextButton(
                      onPressed: () {
                        ref.read(authProvider.notifier).logout();
                      },
                      child: const Text('Back to Login')),
                  ])))))));
  }
}
