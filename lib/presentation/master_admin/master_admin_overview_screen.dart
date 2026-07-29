import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firebase_sync_service.dart';
import '../widgets/premium_shine.dart';
import 'master_admin_shell.dart';

class MasterAdminOverviewScreen extends StatefulWidget {
  final VoidCallback onNavigateToShops;
  final VoidCallback onNavigateToPulse;
  final VoidCallback onNavigateToFranchises;
  final VoidCallback onNavigateToSupport;
  final VoidCallback onNavigateToDevices;
  final VoidCallback onNavigateToErrors;
  final VoidCallback onNavigateToActivity;
  final VoidCallback onNavigateToRegistrations;
  final VoidCallback? onOpenDrawer;

  const MasterAdminOverviewScreen({
    super.key,
    required this.onNavigateToShops,
    required this.onNavigateToPulse,
    required this.onNavigateToFranchises,
    required this.onNavigateToSupport,
    required this.onNavigateToDevices,
    required this.onNavigateToErrors,
    required this.onNavigateToActivity,
    required this.onNavigateToRegistrations,
    this.onOpenDrawer,
  });

  @override
  State<MasterAdminOverviewScreen> createState() =>
      _MasterAdminOverviewScreenState();
}

class _MasterAdminOverviewScreenState extends State<MasterAdminOverviewScreen> {
  int _totalShops = 0;
  int _activeShops = 0;
  int _blockedShops = 0;
  int _inactiveShops = 0;
  bool _loading = true;
  String? _error;

  int _totalFranchises = 0;
  List<Map<String, dynamic>> _recentShops = [];
  List<Map<String, dynamic>> _securityAlerts = [];
  List<Map<String, dynamic>> _franchiseLeaderboard = [];
  List<Map<String, dynamic>> _dailyTrend = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sync = FirebaseSyncService();
      final futures = await Future.wait([
        sync.getAllShopsFromRegistry(),
        sync.getTotalFranchises(),
        sync.getGlobalLoginAlerts(),
        sync.getFranchiseLeaderboard(),
      ]);

      final rawShops = futures[0] as List<Map<String, dynamic>>;
      final totalFranchises = futures[1] as int;
      final alerts = futures[2] as List<Map<String, dynamic>>;
      final leaderboard = futures[3] as List<Map<String, dynamic>>;

      int active = 0, blocked = 0, inactive = 0;
      final now = DateTime.now();

      for (var data in rawShops) {
        final isBlocked = data['isBlocked'] == true;
        DateTime? validUntil;
        if (data['validUntil'] != null) {
          validUntil = DateTime.tryParse(data['validUntil'].toString());
        }
        if (isBlocked) {
          blocked++;
        } else {
          final isExpired = validUntil != null && validUntil.isBefore(now);
          if (!isExpired) {
            active++;
          } else {
            inactive++;
          }
        }
      }

      var recent = List<Map<String, dynamic>>.from(rawShops);
      recent.sort((a, b) {
        final dA = DateTime.tryParse(a['registeredAt'] ?? '') ?? DateTime(2000);
        final dB = DateTime.tryParse(b['registeredAt'] ?? '') ?? DateTime(2000);
        return dB.compareTo(dA);
      });
      if (recent.length > 5) recent = recent.sublist(0, 5);

      final dayStarts = List.generate(
        14,
        (i) => DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: 13 - i)),
      );
      final Map<String, int> dailyCounts = {
        for (final ds in dayStarts) _dayKey(ds): 0,
      };
      for (final shop in rawShops) {
        DateTime? reg;
        if (shop['createdAt'] != null && shop['createdAt'] is Timestamp) {
          reg = (shop['createdAt'] as Timestamp).toDate();
        } else {
          reg = DateTime.tryParse(
            shop['registeredAt'] ?? shop['createdAt']?.toString() ?? '',
          );
        }
        if (reg == null) continue;
        final key = _dayKey(reg);
        if (dailyCounts.containsKey(key))
          dailyCounts[key] = dailyCounts[key]! + 1;
      }
      final dailyTrend = dayStarts
          .map(
            (ds) => {
              'label': _shortDate(ds),
              'count': dailyCounts[_dayKey(ds)] ?? 0,
            },
          )
          .toList();

      if (mounted) {
        setState(() {
          _totalShops = rawShops.length;
          _activeShops = active;
          _blockedShops = blocked;
          _inactiveShops = inactive;
          _totalFranchises = totalFranchises;
          _securityAlerts = alerts;
          _recentShops = recent;
          _franchiseLeaderboard = leaderboard.length > 5
              ? leaderboard.sublist(0, 5)
              : leaderboard;
          _dailyTrend = dailyTrend;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _shortDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4338CA)),
            )
          : _error != null
          ? Center(
              child: Text(
                'Error: $_error',
                style: const TextStyle(color: Colors.redAccent),
              ),
            )
          : ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width < 600 ? 12 : 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KPI Grid - Premium Denser Layout
                    _sectionTitle('Network Pulse'),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: MediaQuery.of(context).size.width < 600
                          ? 2
                          : MediaQuery.of(context).size.width < 1100
                          ? 4
                          : 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: MediaQuery.of(context).size.width < 600
                          ? 1.1
                          : 2.0,
                      children: [
                        _kpiCard(
                          'Total Shops',
                          '$_totalShops',
                          Icons.store,
                          const Color(0xFF4F46E5),
                          const Color(0xFFEEF2FF),
                          [const Color(0xFF4F46E5), const Color(0xFF6366F1)],
                        ),
                        _kpiCard(
                          'Active Shops',
                          '$_activeShops',
                          Icons.check_circle,
                          const Color(0xFF10B981),
                          const Color(0xFFD1FAE5),
                          [const Color(0xFF10B981), const Color(0xFF34D399)],
                        ),
                        _kpiCard(
                          'Inactive Shops',
                          '$_inactiveShops',
                          Icons.remove_circle,
                          const Color(0xFFF59E0B),
                          const Color(0xFFFEF3C7),
                          [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
                        ),
                        _kpiCard(
                          'Blocked Shops',
                          '$_blockedShops',
                          Icons.block,
                          const Color(0xFFEF4444),
                          const Color(0xFFFEE2E2),
                          [const Color(0xFFEF4444), const Color(0xFFF87171)],
                        ),
                      ],
                    ),

                    // Security Alerts
                    if (_securityAlerts.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildSecurityAlertsPanel(),
                    ],

                    const SizedBox(height: 20),

                    // Live Tracking Multi-Column
                    LayoutBuilder(
                      builder: (ctx, c) {
                        if (c.maxWidth < 1000) {
                          return Column(
                            children: [
                              _buildLiveNetworkPulse(),
                              const SizedBox(height: 20),
                              _buildLiveStaffActivity(),
                              const SizedBox(height: 20),
                              _buildLiveDeviceHealth(),
                              const SizedBox(height: 20),
                              _buildLiveErrorStream(),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  _buildLiveNetworkPulse(),
                                  const SizedBox(height: 20),
                                  _buildLiveStaffActivity(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  _buildLiveDeviceHealth(),
                                  const SizedBox(height: 20),
                                  _buildLiveErrorStream(),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (ctx, c) {
                        if (c.maxWidth < 800) {
                          return Column(
                            children: [
                              _buildDailyTrendChart(),
                              const SizedBox(height: 20),
                              _buildFranchiseLeaderboard(),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: _buildDailyTrendChart()),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 4,
                              child: _buildFranchiseLeaderboard(),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                    _buildRecentActivityList(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: Color(0xFF1F2937),
      letterSpacing: 0.5,
    ),
  );

  // Premium Neumorphic Card layout
  Widget _card({
    required Widget child,
    Widget? header,
    EdgeInsetsGeometry padding = const EdgeInsets.all(24),
    Color borderColor = Colors.transparent,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8), // Match workspace base to blend
        border: borderColor != Colors.transparent
            ? Border.all(color: borderColor, width: 1.5)
            : null,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(6, 6),
          ),
          const BoxShadow(
            color: Colors.white,
            blurRadius: 24,
            offset: Offset(-6, -6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: header,
            ),
            const Divider(height: 1, color: Colors.white, thickness: 1.5),
            const Divider(height: 1, color: Color(0x11000000), thickness: 1),
          ],
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }

  Widget _kpiCard(
    String title,
    String value,
    IconData icon,
    Color accent,
    Color outline,
    List<Color> gradientColors,
  ) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const PremiumShineCardOverlay(borderRadius: 24),
      ],
    );
  }

  // -- Live Network Pulse -----------------------------------------------------
  Widget _buildLiveNetworkPulse() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('shops').snapshots(),
      builder: (context, snapshot) {
        final now = DateTime.now();
        int onlineNow = 0, activeToday = 0, activeWeek = 0, dormant = 0;
        final List<Map<String, dynamic>> liveShops = [];

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            if (doc.id == 'host_admin') continue;
            final data = doc.data() as Map<String, dynamic>;
            final ts = data['lastSeenAt'];
            DateTime? lastSeen;
            if (ts is Timestamp) lastSeen = ts.toDate();

            final name = data['shopName'] ?? doc.id;
            final diff = lastSeen != null ? now.difference(lastSeen) : null;

            String status;
            Color dot;
            if (diff == null || diff.inDays >= 7) {
              dormant++;
              status = 'Dormant';
              dot = const Color(0xFF9CA3AF);
            } else if (diff.inHours < 1) {
              onlineNow++;
              status = '${diff.inMinutes}m ago';
              dot = const Color(0xFF10B981);
            } else if (diff.inHours < 24) {
              activeToday++;
              status = '${diff.inHours}h ago';
              dot = const Color(0xFF3B82F6);
            } else {
              activeWeek++;
              status = '${diff.inDays}d ago';
              dot = const Color(0xFFF59E0B);
            }

            liveShops.add({
              'name': name,
              'status': status,
              'dot': dot,
              'lastSeen': lastSeen,
            });
          }
          liveShops.sort((a, b) {
            final dA = a['lastSeen'] as DateTime?,
                dB = b['lastSeen'] as DateTime?;
            if (dA == null && dB == null) return 0;
            if (dA == null) return 1;
            if (dB == null) return -1;
            return dB.compareTo(dA);
          });
        }
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return _card(
          borderColor: const Color(0xFF6366F1).withValues(alpha: 0.3),
          header: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.wifi_tethering,
                  color: Color(0xFF4F46E5),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Live Network Pulse',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              InkWell(
                onTap: widget.onNavigateToPulse,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF4F46E5),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: Color(0xFF4F46E5),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isLoading)
                Row(
                  children: [
                    _pulseChip(
                      'Online',
                      onlineNow,
                      const Color(0xFF10B981),
                      const Color(0xFFD1FAE5),
                    ),
                    const SizedBox(width: 8),
                    _pulseChip(
                      'Today',
                      activeToday,
                      const Color(0xFF3B82F6),
                      const Color(0xFFDBEAFE),
                    ),
                    const SizedBox(width: 8),
                    _pulseChip(
                      'This Week',
                      activeWeek,
                      const Color(0xFFF59E0B),
                      const Color(0xFFFEF3C7),
                    ),
                    const SizedBox(width: 8),
                    _pulseChip(
                      'Dormant',
                      dormant,
                      const Color(0xFF6B7280),
                      const Color(0xFFF3F4F6),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (liveShops.isEmpty)
                const Text(
                  'No tracking data',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                )
              else
                ...liveShops
                    .take(6)
                    .map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            s['dot'] == const Color(0xFF10B981)
                                ? _PulsingDot(color: s['dot'], size: 8)
                                : Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: s['dot'],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ),
                            Text(
                              s['status'],
                              style: TextStyle(
                                fontSize: 11,
                                color: s['dot'],
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  // -- Live Staff & Register Activity -----------------------------------------
  Widget _buildLiveStaffActivity() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseSyncService().getLiveStaffActivityStreamCustom(),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final hasData = snapshot.hasData && snapshot.data!.isNotEmpty;

        return _card(
          borderColor: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
          header: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.group_outlined,
                  color: Color(0xFF4F46E5),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Live Staff Activity',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              InkWell(
                onTap: widget.onNavigateToActivity,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF4F46E5),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: Color(0xFF4F46E5),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (!hasData)
                _buildEmptyState(
                  'No live staff activity',
                  Icons.notifications_paused_outlined,
                )
              else
                ...snapshot.data!.asMap().entries.map((e) {
                  final index = e.key;
                  final isLast = index == snapshot.data!.length - 1;
                  final data = e.value;

                  DateTime? time;
                  if (data['timestamp'] is Timestamp)
                    time = (data['timestamp'] as Timestamp).toDate();
                  else if (data['timestamp'] is DateTime)
                    time = data['timestamp'] as DateTime;
                  final timeStr = time != null
                      ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                      : 'Just now';

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFF4F46E5),
                                  width: 3,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['action'] ?? 'Unknown Action',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        data['shopCode'] ?? 'Unknown',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    timeStr,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4B5563),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  // -- Live Device Health & App Versions --------------------------------------
  Widget _buildLiveDeviceHealth() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseSyncService().getRegisteredDevicesStream(),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final hasData = snapshot.hasData && snapshot.data!.isNotEmpty;

        return _card(
          borderColor: const Color(0xFF10B981).withValues(alpha: 0.3),
          header: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.devices,
                  color: Color(0xFF4F46E5),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Live Device Health',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              InkWell(
                onTap: widget.onNavigateToDevices,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF4F46E5),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: Color(0xFF4F46E5),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (!hasData)
                _buildEmptyState(
                  'No devices currently tracking',
                  Icons.devices_other,
                )
              else ...[
                // Table Header
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Device Model',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Shop Name',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Battery',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Last Ping',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 16),
                ...snapshot.data!.map((data) {
                  final bat = data['battery'] as int;
                  final batColor = bat > 20
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444);
                  final isOnline = data['isOnline'] as bool;

                  DateTime? time;
                  if (data['lastPing'] is Timestamp)
                    time = (data['lastPing'] as Timestamp).toDate();
                  else if (data['lastPing'] is DateTime)
                    time = data['lastPing'] as DateTime;
                  final timeStr = time != null
                      ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                      : 'Just now';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            data['deviceModel']?.toString() ?? 'POS-001',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            data['shopName']?.toString() ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: batColor, width: 2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$bat%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: batColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isOnline
                                        ? const Color(0xFF10B981)
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  timeStr,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF111827),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }

  // -- Live Error & Crash Stream ----------------------------------------------
  Widget _buildLiveErrorStream() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseSyncService().getLiveErrorStreamCustom(),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final hasData = snapshot.hasData && snapshot.data!.isNotEmpty;

        return _card(
          borderColor: const Color(0xFFEF4444).withValues(alpha: 0.3),
          header: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bug_report_outlined,
                  color: Color(0xFFEF4444),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Live Error Stream',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              InkWell(
                onTap: widget.onNavigateToErrors,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF4F46E5),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: Color(0xFF4F46E5),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (!hasData)
                _buildEmptyState(
                  'No live errors reported',
                  Icons.check_circle_outline,
                  color: const Color(0xFF10B981),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 4,
                        child: Text(
                          'Error Description',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Shop Code',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Time',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 16),
                ...snapshot.data!.map((data) {
                  DateTime? time;
                  if (data['timestamp'] is Timestamp)
                    time = (data['timestamp'] as Timestamp).toDate();
                  else if (data['timestamp'] is DateTime)
                    time = data['timestamp'] as DateTime;
                  final timeStr = time != null
                      ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                      : 'Just now';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text(
                            data['error'] ?? 'Unknown Error',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFEF4444),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            data['shopCode'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  timeStr,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF111827),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }

  // Standardized row for streams
  Widget _streamRow(
    String title,
    String shopCode,
    dynamic timestamp, {
    bool isError = false,
  }) {
    DateTime? time;
    if (timestamp is Timestamp) time = timestamp.toDate();
    final timeStr = time != null
        ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
        : 'Now';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isError
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF4F46E5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isError
                        ? const Color(0xFFB91C1C)
                        : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  shopCode,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              timeStr,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    String msg,
    IconData icon, {
    Color color = const Color(0xFF9CA3AF),
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              msg,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pulseChip(String label, int count, Color color, Color bg) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildSecurityAlertsPanel() {
    return _card(
      borderColor: const Color(0xFFDC2626).withValues(alpha: 0.3),
      header: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.gpp_bad_rounded,
              color: Color(0xFFEF4444),
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Security Alerts',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  '${_securityAlerts.length} suspicious login attempt${_securityAlerts.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _securityAlerts.clear()),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: const Text(
              'Dismiss All',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              border: Border.all(color: const Color(0xFFFECACA)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'CRITICAL ALERTS',
                      style: TextStyle(
                        color: Color(0xFF991B1B),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._securityAlerts.take(4).toList().asMap().entries.map((e) {
                  final alert = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Suspicious Login: ${alert['deviceId'] ?? 'Unknown'}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF7F1D1D),
                                ),
                              ),
                              Text(
                                'Shop Code: ${alert['shopCode'] ?? 'Unknown'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF991B1B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          'Action Required',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTrendChart() {
    if (_dailyTrend.isEmpty) return const SizedBox.shrink();
    final effectiveMax = _dailyTrend
        .map((w) => w['count'] as int)
        .reduce((a, b) => a > b ? a : b);

    return _card(
      borderColor: const Color(0xFF3B82F6).withValues(alpha: 0.3),
      header: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bar_chart,
                  color: Color(0xFF4F46E5),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Day-wise Registrations',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                'Last 14 days',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: widget.onNavigateToRegistrations,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF4F46E5),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: Color(0xFF4F46E5),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: LayoutBuilder(
              builder: (ctx, c) => Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _dailyTrend.asMap().entries.map((entry) {
                  final count = entry.value['count'] as int;
                  final isLast = entry.key == _dailyTrend.length - 1;
                  final barColor = isLast
                      ? const Color(0xFF4F46E5)
                      : const Color(0xFFD1D5DB);
                  final barHeight =
                      (effectiveMax < 1 ? 1.0 : count / effectiveMax) * 100.0 +
                      (count > 0 ? 4.0 : 2.0);
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (count > 0)
                        Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: barColor,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Container(
                            height: 104,
                            width: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            height: barHeight,
                            width: 24,
                            decoration: BoxDecoration(
                              gradient: isLast
                                  ? const LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Color(0xFF4F46E5),
                                        Color(0xFF818CF8),
                                      ],
                                    )
                                  : const LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Color(0xFFD1D5DB),
                                        Color(0xFFE5E7EB),
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: isLast
                                  ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF4F46E5,
                                        ).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.value['label'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          color: isLast
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFranchiseLeaderboard() {
    return _card(
      borderColor: const Color(0xFFF59E0B).withValues(alpha: 0.3),
      header: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.emoji_events_outlined,
                  color: Color(0xFF4F46E5),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Top Franchises',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          InkWell(
            onTap: widget.onNavigateToFranchises,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF4F46E5), width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'View All',
                style: TextStyle(
                  color: Color(0xFF4F46E5),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_franchiseLeaderboard.isEmpty)
            _buildEmptyState(
              'No franchises yet',
              Icons.business_center_outlined,
            )
          else
            ..._franchiseLeaderboard.asMap().entries.map((e) {
              final f = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${e.key + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B7280),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        f['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                    Text(
                      '${f['shopCount']} shops',
                      style: const TextStyle(
                        color: Color(0xFF4F46E5),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRecentActivityList() {
    return _card(
      borderColor: const Color(0xFF10B981).withValues(alpha: 0.3),
      header: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.add_business_outlined,
              color: Color(0xFF10B981),
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Recent Onboarding',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF111827),
              ),
            ),
          ),
          InkWell(
            onTap: widget.onNavigateToShops,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF4F46E5), width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'View All',
                style: TextStyle(
                  color: Color(0xFF4F46E5),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_recentShops.isEmpty)
                      _buildEmptyState('No recent onboarding', Icons.storefront)
                    else
                      ..._recentShops.map((s) {
                        final reg = DateTime.tryParse(s['registeredAt'] ?? '');
                        return _streamRow(
                          'Registered: ${s['shopName'] ?? s['name'] ?? 'Unknown'}',
                          s['shopCode'] ?? '',
                          reg != null ? Timestamp.fromDate(reg) : null,
                        );
                      }),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Onboarding Trend (30 Days)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _SparklinePainter(const [
                      1.0,
                      2.0,
                      4.0,
                      3.0,
                      6.0,
                      5.0,
                      8.0,
                      12.0,
                      10.0,
                      15.0,
                      20.0,
                    ], const Color(0xFF10B981)),
                  ),
                ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_recentShops.isEmpty)
                      _buildEmptyState('No recent onboarding', Icons.storefront)
                    else
                      ..._recentShops.map((s) {
                        final reg = DateTime.tryParse(s['registeredAt'] ?? '');
                        return _streamRow(
                          'Registered: ${s['shopName'] ?? s['name'] ?? 'Unknown'}',
                          s['shopCode'] ?? '',
                          reg != null ? Timestamp.fromDate(reg) : null,
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Onboarding Trend (30 Days)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 120,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _SparklinePainter(const [
                          1.0,
                          2.0,
                          4.0,
                          3.0,
                          6.0,
                          5.0,
                          8.0,
                          12.0,
                          10.0,
                          15.0,
                          20.0,
                        ], const Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  final double size;
  const _PulsingDot({required this.color, this.size = 12});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);
  late final Animation<double> _s = Tween<double>(
    begin: 1.0,
    end: 1.6,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  late final Animation<double> _o = Tween<double>(
    begin: 0.8,
    end: 0.2,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: _o.value,
          child: Container(
            width: widget.size * _s.value,
            height: widget.size * _s.value,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ],
    ),
  );
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final minVal = data.reduce((a, b) => a < b ? a : b);
    final range = maxVal - minVal == 0 ? 1.0 : maxVal - minVal;

    final xStep = size.width / (data.length - 1 == 0 ? 1 : data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * xStep;
      final y = size.height - ((data[i] - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      // Draw a small dot at each point
      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
