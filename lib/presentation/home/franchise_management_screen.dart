import 'package:pos/core/utils/notification_helper.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_sync_service.dart';
import 'package:flutter/material.dart';
import '../master_admin/master_admin_shell.dart'; // for kMasterWorkspaceColor

class FranchiseManagementScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final bool hideAppBar;
  const FranchiseManagementScreen({
    super.key,
    this.onOpenDrawer,
    this.hideAppBar = false,
  });

  @override
  State<FranchiseManagementScreen> createState() =>
      _FranchiseManagementScreenState();
}

class _FranchiseManagementScreenState extends State<FranchiseManagementScreen> {
  List<Map<String, dynamic>> _availableShops = [];
  Map<String, dynamic>? _selectedOwner; // selected owner for details panel
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchShops();
  }

  Future<void> _fetchShops() async {
    try {
      final shops = await FirebaseSyncService().getAllShopsFromRegistry();
      if (mounted) {
        setState(() {
          _availableShops = shops;
        });
      }
    } catch (e) {
      debugPrint('FranchiseManagementScreen: failed to fetch shops: $e');
    }
  }

  // Decodes base64 password
  String _decodePassword(String hash) {
    try {
      return utf8.decode(base64.decode(hash));
    } catch (e) {
      return 'Encrypted / Invalid';
    }
  }

  // Encodes to base64
  String _encodePassword(String plain) {
    return base64.encode(utf8.encode(plain));
  }

  Future<void> _deleteOwner(String phone) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Franchise Owner?'),
        content: Text(
          'Are you sure you want to delete owner profiles for phone: $phone?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance
            .collection('franchise_owners')
            .doc(phone)
            .delete();
        if (mounted) {
          NotificationHelper.showCenter(
            context,
            'Franchise owner deleted successfully.',
            isError: false,
          );
          setState(() {
            _selectedOwner = null;
          });
        }
      } catch (e) {
        if (mounted) {
          NotificationHelper.showCenter(
            context,
            'Delete failed: $e',
            isError: true,
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showOwnerFormDialog([Map<String, dynamic>? ownerToEdit]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: ownerToEdit?['name']);
    final phoneCtrl = TextEditingController(
      text: ownerToEdit?['id'],
    ); // doc.id is phone
    final passwordCtrl = TextEditingController(
      text: ownerToEdit != null
          ? _decodePassword(ownerToEdit['passwordHash'] ?? '')
          : '',
    );

    List<String> assignedShops = List<String>.from(
      ownerToEdit?['ownedShops'] ?? [],
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: kMasterWorkspaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                ownerToEdit == null
                    ? 'Add Franchise Owner'
                    : 'Edit Franchise Owner',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Owner Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: phoneCtrl,
                          enabled: ownerToEdit == null, // lock phone if editing
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number (10 Digits)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (!RegExp(r'^[0-9]{10}$').hasMatch(v.trim())) {
                              return 'Must be exactly 10 digits';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: passwordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Franchise Password',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock),
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Assigned Branches',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                hint: const Text('Select Shop'),
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: _availableShops.map((shop) {
                                  return DropdownMenuItem<String>(
                                    value: shop['shopCode'] as String,
                                    child: Text(
                                      '${shop['shopName']} (${shop['shopCode']})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null &&
                                      !assignedShops.contains(val)) {
                                    setDialogState(() {
                                      assignedShops.add(val);
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (assignedShops.isEmpty)
                          const Text(
                            'No shops assigned yet',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: assignedShops.map((code) {
                              final name = _availableShops.firstWhere(
                                (s) => s['shopCode'] == code,
                                orElse: () => {'shopName': 'Unknown'},
                              )['shopName'];
                              return Chip(
                                label: Text('$name ($code)'),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () {
                                  setDialogState(() {
                                    assignedShops.remove(code);
                                  });
                                },
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    if (assignedShops.isEmpty) {
                      NotificationHelper.showCenter(
                        ctx,
                        'Please select at least one shop code',
                        isError: false,
                      );
                      return;
                    }

                    final phone = phoneCtrl.text.trim();
                    final passwordHash = _encodePassword(
                      passwordCtrl.text.trim(),
                    );

                    try {
                      await FirebaseFirestore.instance
                          .collection('franchise_owners')
                          .doc(phone)
                          .set({
                            'name': nameCtrl.text.trim(),
                            'passwordHash': passwordHash,
                            'ownedShops': assignedShops,
                            'updatedAt': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        NotificationHelper.showCenter(
                          context,
                          'Franchise Owner successfully saved!',
                          isError: false,
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        NotificationHelper.showCenter(
                          ctx,
                          'Save failed: $e',
                          isError: true,
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      backgroundColor: kMasterWorkspaceColor,
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              title: const Text(
                'Franchise Management',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              backgroundColor: kMasterWorkspaceColor,
              foregroundColor: const Color(0xFF1E293B),
              elevation: 0,
              leading: widget.onOpenDrawer != null
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: widget.onOpenDrawer,
                    )
                  : null,
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        onPressed: () => _showOwnerFormDialog(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('franchise_owners')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No franchise owners found. Click + to add one.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          final owners = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id; // phone is document id
            return data;
          }).toList();

          if (isDesktop) {
            return Row(
              children: [
                // Owners List (Left Panel)
                Expanded(
                  flex: 2,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: owners.length,
                    itemBuilder: (context, index) {
                      final owner = owners[index];
                      final isSelected = _selectedOwner?['id'] == owner['id'];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFE0E7FF)
                              : kMasterWorkspaceColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.white,
                              blurRadius: 4,
                              offset: Offset(-2, -2),
                            ),
                            BoxShadow(
                              color: Color(0xFFD1D9E6),
                              blurRadius: 4,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          title: Text(
                            owner['name'] ?? 'Unknown Owner',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          subtitle: Text(
                            'Phone: ${owner['id']}',
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF64748B),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedOwner = owner;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),
                // Details Inspector (Right Panel)
                Expanded(
                  flex: 3,
                  child: _selectedOwner == null
                      ? const Center(
                          child: Text(
                            'Select a franchise owner to view details',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        )
                      : _buildDetailsPanel(_selectedOwner!),
                ),
              ],
            );
          }

          // Mobile Layout: Lists owners, clicking opens a detailed bottom sheet
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: owners.length,
            itemBuilder: (context, index) {
              final owner = owners[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: kMasterWorkspaceColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.white,
                      blurRadius: 4,
                      offset: Offset(-2, -2),
                    ),
                    BoxShadow(
                      color: Color(0xFFD1D9E6),
                      blurRadius: 4,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: Text(
                    owner['name'] ?? 'Unknown Owner',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  subtitle: Text('Phone: ${owner['id']}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: kMasterWorkspaceColor,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      builder: (ctx) => _buildDetailsPanel(owner),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailsPanel(Map<String, dynamic> owner) {
    final List<dynamic> ownedCodes = owner['ownedShops'] ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                owner['name'] ?? 'Owner Details',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFF4F46E5)),
                    onPressed: () => _showOwnerFormDialog(owner),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteOwner(owner['id']),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Metadata Panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kMasterWorkspaceColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.white,
                  blurRadius: 6,
                  offset: Offset(-3, -3),
                ),
                BoxShadow(
                  color: Color(0xFFD1D9E6),
                  blurRadius: 6,
                  offset: Offset(3, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                _detailRow('Phone Number', owner['id']),
                const Divider(height: 20),
                _detailRow(
                  'Portal Password',
                  _decodePassword(owner['passwordHash'] ?? ''),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Owned Shop Locations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          if (ownedCodes.isEmpty)
            const Text(
              'No shops assigned to this franchise.',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            )
          else
            ...ownedCodes.map((code) {
              final shop = _availableShops.firstWhere(
                (s) => s['shopCode'] == code,
                orElse: () => {'shopName': 'Unknown Registry Name'},
              );
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kMasterWorkspaceColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.white,
                      blurRadius: 4,
                      offset: Offset(-2, -2),
                    ),
                    BoxShadow(
                      color: Color(0xFFD1D9E6),
                      blurRadius: 4,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.store, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shop['shopName'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            code,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
