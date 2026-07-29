import 'package:pos/core/utils/notification_helper.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/firebase_sync_service.dart';
import '../widgets/neumorphic_widgets.dart';

class StaffManagementScreen extends ConsumerStatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  ConsumerState<StaffManagementScreen> createState() =>
      _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen> {
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _showAddStaffDialog() {
    _nameCtrl.clear();
    _usernameCtrl.clear();
    _passwordCtrl.clear();

    showDialog(
      context: context,
      builder: (context) {
        String selectedRole = 'receptionist';
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.person_add_alt_1, color: Color(0xFF0EA5E9)),
                SizedBox(width: 8),
                Text(
                  'Add Staff Account',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ]),
            content: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'e.g. Alice Cooper',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter staff name'
                              : null),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        hintText: 'e.g. alice123',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter username';
                        }
                        // Check duplicate username
                        final staffList = ref.read(staffAccountsProvider);
                        if (staffList.any(
                              (s) =>
                                  s.username.toLowerCase() ==
                                  value.trim().toLowerCase()) ||
                            value.trim().toLowerCase() == 'admin') {
                          return 'Username already exists';
                        }
                        return null;
                      }),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordCtrl,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Enter password'
                          : null),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Role',
                        prefixIcon: const Icon(Icons.work_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50),
                      items: const [
                        DropdownMenuItem(value: 'receptionist', child: Text('Receptionist')),
                        DropdownMenuItem(value: 'captain', child: Text('Captain')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => selectedRole = val);
                      }),
                  ]))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
                icon: const Icon(Icons.check),
                onPressed: () {
                if (_formKey.currentState!.validate()) {
                  final error = ref
                      .read(staffAccountsProvider.notifier)
                      .addStaffAccount(
                        _nameCtrl.text,
                        _usernameCtrl.text,
                        _passwordCtrl.text,
                        selectedRole);
                  if (error != null) {
                    NotificationHelper.showCenter(context, error, isError: true);
                    return;
                  }
                  FirebaseSyncService().pushSync(); // Auto sync
                  Navigator.pop(context);
                  NotificationHelper.showCenter(context, 'Staff account created successfully!', isError: false);
                }
              },
              label: const Text('Create')),
            ]);
          });
      });
  }

  void _showResetPasswordDialog(StaffAccount staff) {
    _passwordCtrl.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.lock_reset, color: Color(0xFF0EA5E9)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Reset Password: ${staff.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis)),
            ]),
          content: TextField(
            controller: _passwordCtrl,
            decoration: InputDecoration(
              labelText: 'New Password',
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
              icon: const Icon(Icons.save),
              onPressed: () {
                final newPass = _passwordCtrl.text.trim();
                if (newPass.isNotEmpty) {
                  ref
                      .read(staffAccountsProvider.notifier)
                      .updateStaffPassword(staff.id, newPass);
                  FirebaseSyncService().pushSync(); // Auto sync
                  Navigator.pop(context);
                  NotificationHelper.showCenter(context, 'Password updated successfully!', isError: false);
                }
              },
              label: const Text('Update')),
          ]);
      });
  }

  void _confirmDeleteStaff(StaffAccount staff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ]),
        content: Text(
          'Are you sure you want to delete the staff account for "${staff.name}"?\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              ref
                  .read(staffAccountsProvider.notifier)
                  .removeStaffAccount(staff.id);
              FirebaseSyncService().pushSync(); // Auto sync
              Navigator.pop(context);
            },
            icon: const Icon(Icons.delete),
            label: const Text('Delete')),
        ]));
  }

  void _showStaffPermissionsDialog(StaffAccount staff) {
    showDialog(
      context: context,
      builder: (context) => StaffPermissionsDialog(staff: staff),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffList = ref.watch(staffAccountsProvider);
    final box = Hive.box<String>('settings');
    final isImpersonating = box.get('is_impersonating') == 'true';
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: isDesktop ? NeumorphicTheme.background : const Color(0xFFF8FAFC),
      appBar: isDesktop ? null : AppBar(
        title: const Text(
          'Staff Management',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0EA5E9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: staffList.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    const Text(
                      'No staff accounts created yet',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showAddStaffDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white),
                      icon: const Icon(Icons.add),
                      label: const Text('Add First Staff Account')),
                  ]))
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: MediaQuery.of(context).size.width < 600 ? 600 : 340,
                  childAspectRatio: MediaQuery.of(context).size.width < 600 ? 2.5 : 1.8,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: staffList.length,
                itemBuilder: (context, index) {
                  final staff = staffList[index];
                  final isCaptain = staff.role == 'captain';
                  final borderColor = isCaptain 
                      ? Colors.orange.shade300 
                      : const Color(0xFF0EA5E9).withOpacity(0.4);

                  return InkWell(
                    onTap: () => _showStaffPermissionsDialog(staff),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                            offset: const Offset(0, 4),
                            blurRadius: 12,
                            spreadRadius: -1,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: isCaptain
                                    ? Colors.orange.shade50
                                    : const Color(0xFF0EA5E9).withOpacity(0.1),
                                child: Text(
                                  staff.name.isNotEmpty
                                      ? staff.name[0].toUpperCase()
                                      : 'S',
                                  style: TextStyle(
                                    color: isCaptain ? Colors.orange.shade800 : const Color(0xFF0EA5E9),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16))),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      staff.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF1E293B)),
                                      overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.person_outline,
                                          size: 12,
                                          color: Color(0xFF94A3B8)),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            staff.username,
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 11),
                                            overflow: TextOverflow.ellipsis),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isCaptain 
                                          ? Colors.orange.shade50 
                                          : Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8)),
                                    child: Text(
                                      staff.role.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isCaptain ? Colors.orange.shade800 : Colors.blue.shade800))),
                                  if (staff.isBlocked) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'BLOCKED',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isImpersonating)
                                    IconButton(
                                      icon: const Icon(Icons.person, color: Colors.deepPurple, size: 20),
                                      tooltip: 'Impersonate Staff',
                                      onPressed: () {
                                        ref.read(authProvider.notifier).impersonateStaffInSameShop(
                                          staff.username,
                                          staff.name,
                                          UserRole.staff,
                                        );
                                      },
                                    ),
                                  IconButton(
                                    icon: Icon(
                                      staff.isBlocked ? Icons.lock : Icons.lock_open,
                                      color: staff.isBlocked ? Colors.red : Colors.grey.shade600,
                                      size: 20,
                                    ),
                                    tooltip: staff.isBlocked ? 'Unblock Staff' : 'Block Staff',
                                    onPressed: () {
                                      ref
                                          .read(staffAccountsProvider.notifier)
                                          .toggleBlockStaffAccount(staff.id);
                                      NotificationHelper.showCenter(
                                        context,
                                        staff.isBlocked
                                            ? '${staff.name} unblocked'
                                            : '${staff.name} blocked',
                                        isError: !staff.isBlocked,
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.key, color: Colors.blue, size: 20),
                                    tooltip: 'Reset Password',
                                    onPressed: () => _showResetPasswordDialog(staff)),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    tooltip: 'Delete Account',
                                    onPressed: () => _confirmDeleteStaff(staff)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
      ),
      floatingActionButton: staffList.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showAddStaffDialog,
              backgroundColor: const Color(0xFF0EA5E9),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Staff'))
          : null,
    );
  }
}

class StaffPermissionsDialog extends ConsumerStatefulWidget {
  final StaffAccount staff;
  const StaffPermissionsDialog({super.key, required this.staff});

  @override
  ConsumerState<StaffPermissionsDialog> createState() => _StaffPermissionsDialogState();
}

class _StaffPermissionsDialogState extends ConsumerState<StaffPermissionsDialog> {
  Widget build(BuildContext context) {
    final staffList = ref.watch(staffAccountsProvider);
    final currentStaff = staffList.firstWhere((s) => s.id == widget.staff.id, orElse: () => widget.staff);
    final permissions = currentStaff.permissions;
    
    final customerDir = permissions['customerDirectory'] ?? false;
    final inventory = permissions['inventory'] ?? false;
    final stock = permissions['stockManagement'] ?? false;
    final refund = permissions['refund'] ?? false;
    final orderHistory = permissions['orderHistory'] ?? false;
    final editBill = permissions['editBill'] ?? false;
    final expenses = permissions['expenses'] ?? false;

    void updatePerm(String key, bool val) {
      final newPerms = Map<String, bool>.from(permissions);
      newPerms[key] = val;
      ref.read(staffAccountsProvider.notifier).updateStaffPermissions(widget.staff.id, newPerms);
      // pushStaffOnly works even during impersonation — only updates the 'staff' field
      FirebaseSyncService().pushStaffOnly();
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFFF8FAFC),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Permissions: ${widget.staff.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        'Role: ${widget.staff.role.toUpperCase()}',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildToggle(
                    title: 'Enable Customer Directory',
                    subtitle: 'Access customer records & directories',
                    value: customerDir,
                    icon: Icons.people_outline,
                    color: Colors.blue,
                    onChanged: (val) => updatePerm('customerDirectory', val)),
                  _buildToggle(
                    title: 'Enable Inventory Tab',
                    subtitle: 'Show the main Inventory tab & details',
                    value: inventory,
                    icon: Icons.category_outlined,
                    color: Colors.purple,
                    onChanged: (val) => updatePerm('inventory', val)),
                  _buildToggle(
                    title: 'Enable Stock Management',
                    subtitle: 'Allow adjusting product stock levels',
                    value: stock,
                    icon: Icons.inventory_2_outlined,
                    color: Colors.orange,
                    onChanged: (val) => updatePerm('stockManagement', val)),
                  _buildToggle(
                    title: 'Enable Refunds / Voids',
                    subtitle: 'Allow cancelling items or whole invoices',
                    value: refund,
                    icon: Icons.assignment_return_outlined,
                    color: Colors.red,
                    onChanged: (val) => updatePerm('refund', val)),
                  _buildToggle(
                    title: 'Enable Order History',
                    subtitle: 'Access previous transaction history',
                    value: orderHistory,
                    icon: Icons.history,
                    color: Colors.indigo,
                    onChanged: (val) => updatePerm('orderHistory', val)),
                  _buildToggle(
                    title: 'Enable Edit Bill',
                    subtitle: 'Allow modifying active invoices',
                    value: editBill,
                    icon: Icons.edit_note,
                    color: Colors.teal,
                    onChanged: (val) => updatePerm('editBill', val)),
                  _buildToggle(
                    title: 'Enable Expenses',
                    subtitle: 'Allow registering daily expenses',
                    value: expenses,
                    icon: Icons.money_off,
                    color: Colors.amber.shade800,
                    onChanged: (val) => updatePerm('expenses', val)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () => Navigator.pop(context),
              child: const Text('Save & Close', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        value: value,
        onChanged: onChanged,
        secondary: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          radius: 18,
          child: Icon(icon, color: color, size: 18)),
        activeColor: const Color(0xFF0EA5E9),
      ),
    );
  }
}
