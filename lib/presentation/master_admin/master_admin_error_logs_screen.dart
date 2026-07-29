import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/services/app_error_logger.dart';
import '../../core/utils/notification_helper.dart';

class MasterAdminErrorLogsScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final bool hideAppBar;

  const MasterAdminErrorLogsScreen({
    super.key,
    this.onOpenDrawer,
    this.hideAppBar = false,
  });

  @override
  State<MasterAdminErrorLogsScreen> createState() =>
      _MasterAdminErrorLogsScreenState();
}

class _MasterAdminErrorLogsScreenState
    extends State<MasterAdminErrorLogsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'today', '7days'

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmClearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.delete_sweep, color: Colors.red),
            SizedBox(width: 10),
            Text(
              'Clear All Error Logs?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete all recorded application error logs from Firebase? This action cannot be undone.',
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AppErrorLogger.clearAllLogs();
      if (mounted) {
        NotificationHelper.showCenter(
          context,
          'All error logs cleared successfully! ✅',
          isError: false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF8FAFC);
    const primaryColor = Color(0xFF4F46E5);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              title: const Text(
                'App Error Logs & Diagnostics',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              backgroundColor: backgroundColor,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
              leading: widget.onOpenDrawer != null
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: widget.onOpenDrawer,
                    )
                  : null,
              actions: [
                IconButton(
                  tooltip: 'Clear All Logs',
                  icon: const Icon(Icons.delete_sweep, color: Colors.red),
                  onPressed: _confirmClearLogs,
                ),
              ],
            ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP HEADER & CONTROLS CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.bug_report,
                          color: Colors.red.shade600,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Central App Error Monitor',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              'Detailed un-sanitized exception logs with Shop Name and User Details',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.delete_sweep, size: 18),
                        label: const Text('Clear Logs'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red.shade700,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _confirmClearLogs,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // SEARCH FIELD
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (val) => setState(
                              () => _searchQuery = val.trim().toLowerCase(),
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'Search by Shop Name, Code, User, or Error...',
                              hintStyle: const TextStyle(fontSize: 13),
                              prefixIcon: const Icon(
                                Icons.search,
                                size: 20,
                                color: Color(0xFF64748B),
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // FILTER SEGMENTS
                      SegmentedButton<String>(
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: const Color(0xFFE0E7FF),
                          selectedForegroundColor: primaryColor,
                        ),
                        segments: const [
                          ButtonSegment(value: 'all', label: Text('All')),
                          ButtonSegment(value: 'today', label: Text('Today')),
                          ButtonSegment(
                            value: '7days',
                            label: Text('Last 7 Days'),
                          ),
                        ],
                        selected: {_selectedFilter},
                        onSelectionChanged: (set) =>
                            setState(() => _selectedFilter = set.first),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ERROR LOGS LIST VIEW
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('app_error_logs')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading logs: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final now = DateTime.now();

                  // Filter documents
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final shopName = (data['shopName'] ?? '')
                        .toString()
                        .toLowerCase();
                    final shopCode = (data['shopCode'] ?? '')
                        .toString()
                        .toLowerCase();
                    final userName = (data['userName'] ?? '')
                        .toString()
                        .toLowerCase();
                    final errorMsg = (data['errorMessage'] ?? '')
                        .toString()
                        .toLowerCase();
                    final contextStr = (data['context'] ?? '')
                        .toString()
                        .toLowerCase();

                    // Search Query Match
                    if (_searchQuery.isNotEmpty) {
                      final matches =
                          shopName.contains(_searchQuery) ||
                          shopCode.contains(_searchQuery) ||
                          userName.contains(_searchQuery) ||
                          errorMsg.contains(_searchQuery) ||
                          contextStr.contains(_searchQuery);
                      if (!matches) return false;
                    }

                    // Date Filter Match
                    DateTime? timestamp;
                    if (data['timestamp'] is Timestamp) {
                      timestamp = (data['timestamp'] as Timestamp).toDate();
                    } else if (data['createdAt'] != null) {
                      timestamp = DateTime.tryParse(data['createdAt']);
                    }

                    if (_selectedFilter == 'today' && timestamp != null) {
                      if (timestamp.year != now.year ||
                          timestamp.month != now.month ||
                          timestamp.day != now.day) {
                        return false;
                      }
                    } else if (_selectedFilter == '7days' &&
                        timestamp != null) {
                      if (now.difference(timestamp).inDays > 7) {
                        return false;
                      }
                    }

                    return true;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: Colors.green.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No Error Logs Found',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Your application is running smoothly with no logged exceptions.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final docId = doc.id;
                      final shopName = data['shopName'] ?? 'Unknown Shop';
                      final shopCode = data['shopCode'] ?? 'N/A';
                      final userName = data['userName'] ?? 'Unknown User';
                      final contextName = data['context'] ?? 'General';
                      final errorMsg =
                          data['errorMessage'] ?? 'No error details';
                      final stackTrace = data['stackTrace'] ?? '';

                      DateTime? time;
                      if (data['timestamp'] is Timestamp) {
                        time = (data['timestamp'] as Timestamp).toDate();
                      } else if (data['createdAt'] != null) {
                        time = DateTime.tryParse(data['createdAt']);
                      }

                      final timeStr = time != null
                          ? DateFormat('dd MMM yyyy, hh:mm a').format(time)
                          : 'Just now';

                      return _ErrorLogCard(
                        docId: docId,
                        shopName: shopName,
                        shopCode: shopCode,
                        userName: userName,
                        contextName: contextName,
                        errorMsg: errorMsg,
                        stackTrace: stackTrace,
                        timeStr: timeStr,
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
}

class _ErrorLogCard extends StatefulWidget {
  final String docId;
  final String shopName;
  final String shopCode;
  final String userName;
  final String contextName;
  final String errorMsg;
  final String stackTrace;
  final String timeStr;

  const _ErrorLogCard({
    required this.docId,
    required this.shopName,
    required this.shopCode,
    required this.userName,
    required this.contextName,
    required this.errorMsg,
    required this.stackTrace,
    required this.timeStr,
  });

  @override
  State<_ErrorLogCard> createState() => _ErrorLogCardState();
}

class _ErrorLogCardState extends State<_ErrorLogCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red.shade600,
                size: 22,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.shopName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.shopCode,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Text(
                        widget.contextName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.timeStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.errorMsg,
                  maxLines: _isExpanded ? 100 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
              ),
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF0F172A),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FULL UN-SANITIZED DIAGNOSTIC ERROR:',
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    widget.errorMsg,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                  if (widget.stackTrace.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'STACK TRACE:',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          widget.stackTrace,
                          style: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Copy Diagnostics'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF475569)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(
                              text:
                                  'Shop: ${widget.shopName} (${widget.shopCode})\nUser: ${widget.userName}\nTime: ${widget.timeStr}\nError: ${widget.errorMsg}\nStack:\n${widget.stackTrace}',
                            ),
                          );
                          NotificationHelper.showCenter(
                            context,
                            'Error diagnostics copied to clipboard!',
                            isError: false,
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.delete, size: 14),
                        label: const Text('Delete Log'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          await AppErrorLogger.deleteLog(widget.docId);
                          if (context.mounted) {
                            NotificationHelper.showCenter(
                              context,
                              'Error log deleted.',
                              isError: false,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
