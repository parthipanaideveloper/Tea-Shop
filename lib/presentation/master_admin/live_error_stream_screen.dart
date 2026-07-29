import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_sync_service.dart';
import 'master_admin_shell.dart';

class LiveErrorStreamScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  final bool hideAppBar;
  const LiveErrorStreamScreen({
    super.key,
    this.onOpenDrawer,
    this.hideAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: hideAppBar
          ? null
          : AppBar(
              title: const Text(
                'Live Error Stream',
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
        stream: FirebaseSyncService().getLiveErrorStreamCustom(),
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
                    Icons.gpp_good_outlined,
                    size: 64,
                    color: const Color(0xFF10B981).withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No live errors reported. System healthy.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          final errors = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: errors.length,
            itemBuilder: (context, index) {
              final data = errors[index];
              final errorText = data['error'] ?? 'Unknown Critical Error';
              final shopCode = data['shopCode'] ?? 'Unknown Shop';

              DateTime? time;
              if (data['timestamp'] is Timestamp) {
                time = (data['timestamp'] as Timestamp).toDate();
              } else if (data['timestamp'] is DateTime) {
                time = data['timestamp'] as DateTime;
              }

              final timeStr = time != null
                  ? '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                  : 'Just now';

              // Unique pseudo error code
              final String errCode =
                  'ERR-${(errorText.hashCode.abs() % 9000) + 1000}';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Alert Icon
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.error_outline,
                            color: Color(0xFFEF4444),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Error Title and Code
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFEF4444,
                                      ).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      errCode,
                                      style: const TextStyle(
                                        color: Color(0xFFF87171),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    timeStr,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                errorText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
                        Row(
                          children: [
                            const Icon(
                              Icons.store,
                              color: Colors.grey,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              shopCode,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(
                                text: '[$errCode] $errorText (Shop: $shopCode)',
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF1E293B),
                                shape: RoundedRectangleBorder(
                                  side: const BorderSide(
                                    color: Color(0xFF334155),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                behavior: SnackBarBehavior.floating,
                                content: Row(
                                  children: const [
                                    Icon(
                                      Icons.check_circle_outline,
                                      color: Color(0xFF10B981),
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Error diagnostic logged to clipboard.',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.copy,
                                  color: Color(0xFF6366F1),
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Copy Log',
                                  style: TextStyle(
                                    color: Color(0xFF6366F1),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
