import 'package:flutter/material.dart';
import '../../services/firebase_sync_service.dart';
import 'master_admin_shell.dart'; // for kMasterWorkspaceColor

class FirebaseLimitsScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  final bool hideAppBar;
  const FirebaseLimitsScreen({
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
                'Firebase Daily Limits Monitor',
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Usage Status (Resets daily at 00:00 UTC)',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<Map<String, dynamic>>(
                stream: FirebaseSyncService.instance.getFirebaseLimitsCustom(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data ?? {};

                  final reads = (data['reads'] as num?)?.toDouble() ?? 0.0;
                  final writes = (data['writes'] as num?)?.toDouble() ?? 0.0;
                  final storage = (data['storage'] as num?)?.toDouble() ?? 0.0;
                  final bandwidth =
                      (data['bandwidth'] as num?)?.toDouble() ?? 0.0;

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final bool isDesktop = constraints.maxWidth >= 800;
                      final int crossAxisCount = isDesktop ? 4 : 2;
                      final double spacing = 24.0;
                      // Subtract the total spacing from maxWidth, then divide by columns
                      final double itemWidth =
                          (constraints.maxWidth -
                              (spacing * (crossAxisCount - 1))) /
                          crossAxisCount;

                      return SingleChildScrollView(
                        child: Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            SizedBox(
                              width: itemWidth,
                              child: _buildGaugeCard(
                                'Document Reads',
                                reads,
                                50000,
                                const Color(0xFF3B82F6),
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: _buildGaugeCard(
                                'Document Writes',
                                writes,
                                20000,
                                const Color(0xFF10B981),
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: _buildGaugeCard(
                                'Storage (GB)',
                                storage,
                                5.0,
                                const Color(0xFFF59E0B),
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: _buildGaugeCard(
                                'Network Bandwidth',
                                bandwidth,
                                10.0,
                                const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGaugeCard(
    String title,
    double current,
    double maxLimit,
    Color color,
  ) {
    final double percentage = (current / maxLimit).clamp(0.0, 1.0);
    final bool isWarning = percentage > 0.85;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kMasterWorkspaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: Offset(-4, -4),
          ),
          BoxShadow(
            color: Color(0xFFD1D9E6),
            blurRadius: 10,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            width: 120,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 12,
                  color: color.withOpacity(0.1),
                ),
                CircularProgressIndicator(
                  value: percentage,
                  strokeWidth: 12,
                  color: isWarning ? Colors.red : color,
                  backgroundColor: Colors.transparent,
                ),
                Center(
                  child: Text(
                    '${(percentage * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isWarning ? Colors.red : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '${_formatValue(current)} / ${_formatValue(maxLimit)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (isWarning) ...[
            const SizedBox(height: 8),
            const Text(
              'Nearing Quota!',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatValue(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(1);
  }
}
