import 'package:flutter/material.dart';
import '../../services/firebase_sync_service.dart';
import 'master_admin_shell.dart'; // for kMasterWorkspaceColor

class FirebaseStorageUsageScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  final bool hideAppBar;
  const FirebaseStorageUsageScreen({
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
                'Firebase Storage Usage',
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
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: FirebaseSyncService.instance
                    .getStorageUsagePerShopCustom(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final shops = snapshot.data ?? [];
                  if (shops.isEmpty) {
                    return const Center(
                      child: Text(
                        'No storage metrics found',
                        style: TextStyle(color: Colors.grey, fontSize: 18),
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width < 800
                          ? 1
                          : 2,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: 2.5,
                    ),
                    itemCount: shops.length,
                    itemBuilder: (context, index) {
                      final data = shops[index];
                      final shopName = data['shopName'] ?? data['shopCode'];
                      final totalGb =
                          (data['totalGb'] as num?)?.toDouble() ?? 0.0;
                      final imagesGb =
                          (data['imagesGb'] as num?)?.toDouble() ?? 0.0;
                      final docsGb =
                          (data['docsGb'] as num?)?.toDouble() ?? 0.0;
                      final backupsGb =
                          (data['backupsGb'] as num?)?.toDouble() ?? 0.0;

                      return _buildShopStorageCard(
                        shopName,
                        totalGb,
                        imagesGb,
                        docsGb,
                        backupsGb,
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

  Widget _buildShopStorageCard(
    String shopName,
    double totalGb,
    double imagesGb,
    double docsGb,
    double backupsGb,
  ) {
    // Avoid division by zero
    final total = totalGb > 0.0 ? totalGb : 1.0;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                shopName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${totalGb.toStringAsFixed(2)}GB Total',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stacked Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 20,
              width: double.infinity,
              child: Row(
                children: [
                  if (imagesGb > 0.0)
                    Expanded(
                      flex: (imagesGb * 100).toInt(),
                      child: Container(color: const Color(0xFF3B82F6)),
                    ),
                  if (docsGb > 0.0)
                    Expanded(
                      flex: (docsGb * 100).toInt(),
                      child: Container(color: const Color(0xFF10B981)),
                    ),
                  if (backupsGb > 0.0)
                    Expanded(
                      flex: (backupsGb * 100).toInt(),
                      child: Container(color: const Color(0xFFF59E0B)),
                    ),
                  // Fill remaining if empty
                  if (totalGb == 0.0)
                    Expanded(child: Container(color: Colors.grey.shade300)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _legendItem(
                'Images',
                const Color(0xFF3B82F6),
                '${imagesGb.toStringAsFixed(2)}GB',
              ),
              _legendItem(
                'Docs',
                const Color(0xFF10B981),
                '${docsGb.toStringAsFixed(2)}GB',
              ),
              _legendItem(
                'Backups',
                const Color(0xFFF59E0B),
                '${backupsGb.toStringAsFixed(2)}GB',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color, String value) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($value)',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
