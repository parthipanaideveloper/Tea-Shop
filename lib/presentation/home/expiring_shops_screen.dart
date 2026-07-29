import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_sync_service.dart';
import '../master_admin/master_admin_screen.dart';

class ExpiringShopsScreen extends StatefulWidget {
  const ExpiringShopsScreen({super.key});

  @override
  State<ExpiringShopsScreen> createState() => _ExpiringShopsScreenState();
}

class _ExpiringShopsScreenState extends State<ExpiringShopsScreen> {
  List<ShopRegistryEntry> _shops = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('shops').get();
      final now = DateTime.now();
      final shops = snap.docs
          .where((d) => d.id != 'host_admin')
          .map((d) {
        final data = d.data();
        DateTime? validUntil;
        if (data['validUntil'] != null) {
          validUntil = DateTime.tryParse(data['validUntil']);
        }
        return ShopRegistryEntry(
          shopCode: d.id,
          shopName: data['shopName'] ?? 'Unknown Shop',
          isBlocked: data['isBlocked'] == true,
          registeredAt: data['registeredAt'] != null
              ? (DateTime.tryParse(data['registeredAt']) ?? DateTime.now())
              : DateTime.now(),
          validUntil: validUntil);
      }).toList();

      shops.sort((a, b) {
        if (a.validUntil == null && b.validUntil == null) return 0;
        if (a.validUntil == null) return 1;
        if (b.validUntil == null) return -1;
        return a.validUntil!.compareTo(b.validUntil!);
      });

      if (mounted) {
        setState(() {
          _shops = shops;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expiring Shops'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _shops.length,
              itemBuilder: (context, index) {
                final shop = _shops[index];
                final fmt = DateFormat('dd MMM yyyy');
                final daysLeft = shop.validUntil != null
                    ? shop.validUntil!.difference(DateTime.now()).inDays
                    : 0;

                Color statusColor = Colors.green;
                if (shop.isBlocked) statusColor = Colors.red;
                else if (shop.isExpired) statusColor = Colors.red;
                else if (daysLeft <= 30) statusColor = Colors.orange;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withOpacity(0.2),
                      child: Icon(Icons.store, color: statusColor)),
                    title: Text(shop.shopName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Code: ${shop.shopCode}\nExpires: ${shop.validUntil != null ? fmt.format(shop.validUntil!) : 'N/A'} ($daysLeft days)'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => ShopActionScreen(
                            shop: shop,
                            onRefresh: _loadShops)));
                    }));
              }));
  }
}
