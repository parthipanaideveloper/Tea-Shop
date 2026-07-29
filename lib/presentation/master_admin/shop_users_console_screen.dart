import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/notification_helper.dart';
import 'master_admin_screen.dart'; // for ShopRegistryEntry
import 'master_admin_shell.dart'; // for kMasterWorkspaceColor

class ShopUsersConsoleDialog extends ConsumerStatefulWidget {
  final ShopRegistryEntry shop;

  const ShopUsersConsoleDialog({super.key, required this.shop});

  @override
  ConsumerState<ShopUsersConsoleDialog> createState() =>
      _ShopUsersConsoleDialogState();
}

class _ShopUsersConsoleDialogState
    extends ConsumerState<ShopUsersConsoleDialog> {
  bool _loading = true;
  List<dynamic> _staffList = [];
  List<dynamic> _adminList = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shop.shopCode)
          .get();
      if (snap.exists) {
        final data = snap.data()!;
        setState(() {
          final rawStaff = data['staff'] as List<dynamic>? ?? [];
          final rawAdmins = data['adminDevices'] as List<dynamic>? ?? [];

          final seenStaff = <String>{};
          _staffList = rawStaff.where((staff) {
            final username = staff['username']?.toString() ?? '';
            if (username.isEmpty || seenStaff.contains(username)) return false;
            seenStaff.add(username);
            return true;
          }).toList();

          final seenAdmins = <String>{};
          _adminList = rawAdmins.where((admin) {
            final deviceId = admin['deviceId']?.toString() ?? '';
            if (deviceId.isEmpty || seenAdmins.contains(deviceId)) return false;
            seenAdmins.add(deviceId);
            return true;
          }).toList();
        });
      }
    } catch (e) {
      if (mounted)
        NotificationHelper.showCenter(
          context,
          'Error loading users: $e',
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteUser(dynamic userObj, bool isAdmin) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete User?',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to permanently delete this ${isAdmin ? 'admin' : 'staff'} device?',
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
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      if (isAdmin) {
        final newList = List<dynamic>.from(_adminList)
          ..removeWhere((s) => s['deviceId'] == userObj['deviceId']);
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shop.shopCode)
            .update({'adminDevices': newList});
        setState(() => _adminList = newList);
      } else {
        final newList = List<dynamic>.from(_staffList)
          ..removeWhere((s) => s['username'] == userObj['username']);
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shop.shopCode)
            .update({'staff': newList});
        setState(() => _staffList = newList);
      }
      if (mounted)
        NotificationHelper.showCenter(
          context,
          'User deleted successfully',
          isError: false,
        );
    } catch (e) {
      if (mounted)
        NotificationHelper.showCenter(
          context,
          'Error deleting user: $e',
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _blockUser(dynamic userObj, bool block, bool isAdmin) async {
    setState(() => _loading = true);
    try {
      if (isAdmin) {
        final newList = List<dynamic>.from(_adminList);
        final idx = newList.indexWhere(
          (s) => s['deviceId'] == userObj['deviceId'],
        );
        if (idx != -1) {
          newList[idx] = Map<String, dynamic>.from(newList[idx])
            ..['isBlocked'] = block;
          await FirebaseFirestore.instance
              .collection('shops')
              .doc(widget.shop.shopCode)
              .update({'adminDevices': newList});
          setState(() => _adminList = newList);
        }
      } else {
        final newList = List<dynamic>.from(_staffList);
        final idx = newList.indexWhere(
          (s) => s['username'] == userObj['username'],
        );
        if (idx != -1) {
          newList[idx] = Map<String, dynamic>.from(newList[idx])
            ..['isBlocked'] = block;
          await FirebaseFirestore.instance
              .collection('shops')
              .doc(widget.shop.shopCode)
              .update({'staff': newList});
          setState(() => _staffList = newList);
        }
      }
      if (mounted)
        NotificationHelper.showCenter(
          context,
          block ? 'User blocked' : 'User unblocked',
          isError: false,
        );
    } catch (e) {
      if (mounted)
        NotificationHelper.showCenter(
          context,
          'Error updating user: $e',
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _impersonateUser(String targetUserId, UserRole role) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Impersonate User?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        content: Text(
          'You are about to securely login as "$targetUserId" into the shop "${widget.shop.shopCode}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('LOGIN'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    final error = await ref
        .read(authProvider.notifier)
        .impersonateShop(
          widget.shop.shopCode,
          targetUserId: targetUserId,
          role: role,
        );

    if (mounted) {
      setState(() => _loading = false);
      if (error != null) {
        NotificationHelper.showCenter(context, error, isError: true);
      } else {
        Navigator.pop(context); // Close the popup dialog on success!
      }
    }
  }

  Widget _buildUserTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onLogin,
    VoidCallback? onDelete,
    bool isBlocked = false,
    ValueChanged<bool>? onToggleBlock,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: kMasterWorkspaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.white, blurRadius: 6, offset: Offset(-3, -3)),
          BoxShadow(
            color: Color(0xFFD1D9E6),
            blurRadius: 6,
            offset: Offset(3, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 450;

          final userInfo = Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isBlocked) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red),
                            ),
                            child: const Text(
                              'BLOCKED',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          );

          final actions = Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onToggleBlock != null) 
                Tooltip(
                  message: isBlocked ? 'Unblock User' : 'Block User',
                  child: Switch(
                    value: isBlocked,
                    activeColor: Colors.red,
                    inactiveThumbColor: Colors.green,
                    inactiveTrackColor: Colors.green.withValues(alpha: 0.3),
                    onChanged: onToggleBlock,
                  ),
                ),
              if (onDelete != null) 
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete User',
                  onPressed: onDelete,
                ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: isBlocked ? null : onLogin,
                icon: const Icon(Icons.person, size: 16),
                label: const Text('Impersonate'),
              ),
            ],
          );

          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                userInfo,
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: actions,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: userInfo),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kMasterWorkspaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'View Shops Console',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.business_center,
                          color: Colors.deepPurple,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Registered Users & Devices',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                'Select a user to login to their console for ',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Expanded(
                      child: ListView(
                        children: [
                          const Text(
                            'Master Admin (Host)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildUserTile(
                            title: 'Master Admin',
                            subtitle: 'Host Device • Full Global Access',
                            icon: Icons.shield,
                            color: Colors.deepPurple,
                            onLogin: () =>
                                _impersonateUser('admin', UserRole.admin),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Registered Admin Devices (Limit 3)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_adminList.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                'No external admin devices registered.',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          else
                            ..._adminList.map((admin) {
                              final deviceId =
                                  admin['deviceId'] ?? 'Unknown Device';
                              final isBlocked = admin['isBlocked'] == true;
                              return _buildUserTile(
                                title: 'Registered Admin',
                                subtitle: 'Device ID: $deviceId',
                                icon: Icons.admin_panel_settings,
                                color: Colors.deepPurple,
                                isBlocked: isBlocked,
                                onLogin: () =>
                                    _impersonateUser('admin', UserRole.admin),
                                onDelete: () => _deleteUser(admin, true),
                                onToggleBlock: (val) =>
                                    _blockUser(admin, val, true),
                              );
                            }),
                          const SizedBox(height: 24),
                          const Text(
                            'Staff Devices',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_staffList.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                'No staff accounts registered for this shop.',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ..._staffList.map((staff) {
                            final username = staff['username'] ?? 'Unknown';
                            final deviceId =
                                staff['deviceId'] ?? 'No mapped device';
                            final isBlocked = staff['isBlocked'] == true;
                            return _buildUserTile(
                              title: username,
                              subtitle: 'Device ID: $deviceId',
                              icon: Icons.person,
                              color: Colors.blue,
                              isBlocked: isBlocked,
                              onLogin: () =>
                                  _impersonateUser(username, UserRole.staff),
                              onDelete: () => _deleteUser(staff, false),
                              onToggleBlock: (val) =>
                                  _blockUser(staff, val, false),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
