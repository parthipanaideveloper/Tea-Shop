import 'package:pos/core/utils/notification_helper.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../providers/auth_provider.dart';
import 'franchise_dashboard_screen.dart';

class FranchiseBranchSelectionScreen extends ConsumerStatefulWidget {
  const FranchiseBranchSelectionScreen({super.key});

  @override
  ConsumerState<FranchiseBranchSelectionScreen> createState() =>
      _FranchiseBranchSelectionScreenState();
}

class _FranchiseBranchSelectionScreenState
    extends ConsumerState<FranchiseBranchSelectionScreen> {
  List<String> _ownedShops = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadOwnedShops();
  }

  void _loadOwnedShops() {
    final box = Hive.box<String>('settings');
    final shopsJson = box.get('franchiseOwnedShops');
    if (shopsJson != null) {
      try {
        final List<dynamic> decoded = json.decode(shopsJson);
        setState(() {
          _ownedShops = decoded.cast<String>();
        });
      } catch (e) {
        debugPrint('Error parsing owned shops: $e');
      }
    }
  }

  Future<void> _selectBranch(String shopCode) async {
    setState(() => _isLoading = true);
    final error = await ref
        .read(authProvider.notifier)
        .franchiseBranchLogin(shopCode);
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (error != null) {
        NotificationHelper.showCenter(context, error, isError: true);
      }
    }
  }

  void _logout() {
    ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Franchise Dashboard'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout'),
        ]),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.blue.shade50),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.business,
                  size: 64,
                  color: Colors.blue),
                const SizedBox(height: 16),
                Text(
                  'Welcome, ${session?.name ?? 'Owner'}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900)),
                const SizedBox(height: 8),
                const Text(
                  'Select a branch to manage it as an Admin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FranchiseSalesDashboardScreen()));
                  },
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('View Consolidated Sales Dashboard'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue.shade100,
                    foregroundColor: Colors.blue.shade900,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(height: 32),
                
                if (_ownedShops.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
                          const SizedBox(height: 16),
                          const Text(
                            'No branches found linked to your account.',
                            style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _logout,
                            child: const Text('Go Back')),
                        ])))
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _ownedShops.length,
                      itemBuilder: (context, index) {
                        final shop = _ownedShops[index];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12),
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: const Icon(Icons.storefront, color: Colors.blue)),
                            title: Text(
                              shop,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                            trailing: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.arrow_forward_ios),
                            onTap: _isLoading ? null : () => _selectBranch(shop)));
                      })),
              ])))));
  }
}
