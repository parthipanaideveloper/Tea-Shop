import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'master_admin_shell.dart';

class DaywiseRegistrationsScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final bool hideAppBar;
  const DaywiseRegistrationsScreen({
    super.key,
    this.onOpenDrawer,
    this.hideAppBar = false,
  });

  @override
  State<DaywiseRegistrationsScreen> createState() =>
      _DaywiseRegistrationsScreenState();
}

class _DaywiseRegistrationsScreenState
    extends State<DaywiseRegistrationsScreen> {
  DateTime _currentMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMasterWorkspaceColor,
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              title: const Text(
                'Day-wise Registrations',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              backgroundColor: kMasterWorkspaceColor,
              elevation: 0,
              foregroundColor: const Color(0xFF1E293B),
              leading: widget.onOpenDrawer != null
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: widget.onOpenDrawer,
                    )
                  : null,
            ),
      body: Container(
        color: kMasterWorkspaceColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device Registrations Calendar',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Track daily activation counts based on real-time shop registrations.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: kMasterWorkspaceColor,
                  borderRadius: BorderRadius.circular(20),
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
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('shops')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final Map<String, int> dailyCounts = {};
                    final docs = snapshot.data?.docs ?? [];

                    for (var doc in docs) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      DateTime? date;
                      if (data['registeredAt'] is Timestamp) {
                        date = (data['registeredAt'] as Timestamp).toDate();
                      } else if (data['registeredAt'] is String) {
                        date = DateTime.tryParse(data['registeredAt']);
                      } else if (data['createdAt'] is Timestamp) {
                        date = (data['createdAt'] as Timestamp).toDate();
                      } else if (data['createdAt'] is String) {
                        date = DateTime.tryParse(data['createdAt']);
                      }

                      if (date != null) {
                        final key =
                            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                        dailyCounts[key] = (dailyCounts[key] ?? 0) + 1;
                      }
                    }

                    return _buildCalendar(dailyCounts);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(Map<String, int> dailyCounts) {
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    final daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
    final firstWeekday = firstDayOfMonth.weekday; // 1 (Mon) to 7 (Sun)

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(
                    () => _currentMonth = DateTime(
                      _currentMonth.year,
                      _currentMonth.month - 1,
                    ),
                  );
                },
              ),
              Text(
                '${_monthName(_currentMonth.month)} ${_currentMonth.year}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(
                    () => _currentMonth = DateTime(
                      _currentMonth.year,
                      _currentMonth.month + 1,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Weekdays
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const Divider(height: 1),
        // Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 42, // 6 weeks
            itemBuilder: (context, index) {
              final dayOffset = index - firstWeekday + 2;
              if (dayOffset <= 0 || dayOffset > daysInMonth) {
                return const SizedBox();
              }

              final dateStr =
                  '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}-${dayOffset.toString().padLeft(2, '0')}';
              final count = dailyCounts[dateStr] ?? 0;
              final isToday =
                  DateTime.now().year == _currentMonth.year &&
                  DateTime.now().month == _currentMonth.month &&
                  DateTime.now().day == dayOffset;

              return Container(
                decoration: BoxDecoration(
                  color: isToday ? const Color(0xFFEEF2FF) : Colors.transparent,
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayOffset',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isToday
                            ? const Color(0xFF4F46E5)
                            : Colors.black87,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$count Devices',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _monthName(int m) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[m - 1];
  }
}
