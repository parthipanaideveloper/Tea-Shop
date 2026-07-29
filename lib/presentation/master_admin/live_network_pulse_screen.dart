import 'package:flutter/material.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class LiveNetworkPulseScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final bool hideAppBar;
  const LiveNetworkPulseScreen({
    super.key,
    this.onOpenDrawer,
    this.hideAppBar = false,
  });

  @override
  State<LiveNetworkPulseScreen> createState() => _LiveNetworkPulseScreenState();
}

class _LiveNetworkPulseScreenState extends State<LiveNetworkPulseScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();
  Map<String, dynamic>? _selectedNode;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  double _getCoord(String code, int salt) {
    return ((code.hashCode ^ salt).abs() % 100) / 100.0;
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              title: const Text(
                'Live Network Pulse',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              backgroundColor: const Color(0xFF1E293B),
              iconTheme: const IconThemeData(color: Colors.white),
              elevation: 0,
              leading: widget.onOpenDrawer != null
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: widget.onOpenDrawer,
                    )
                  : null,
              actions: [
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF10B981),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'GLOBAL MONITORS ACTIVE',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main Map Area
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0B132B),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF1E293B)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('shops')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4F46E5),
                        ),
                      );
                    }

                    final shops = snapshot.data!.docs;
                    final nodes = shops.map((doc) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final code = doc.id;
                      final name = data['shopName'] ?? code;
                      final ts = data['lastSeenAt'];
                      DateTime? lastSeenDate;
                      if (ts is Timestamp) lastSeenDate = ts.toDate();
                      final bool isOnline =
                          lastSeenDate != null &&
                          DateTime.now().difference(lastSeenDate).inHours < 1;

                      final x = 0.15 + (_getCoord(code, 123) * 0.7);
                      final y = 0.15 + (_getCoord(code, 456) * 0.7);

                      return {
                        'code': code,
                        'name': name,
                        'x': x,
                        'y': y,
                        'latency': isOnline
                            ? '${(15 + _getCoord(code, 789) * 35).toInt()}ms'
                            : '--',
                        'status': isOnline ? 'Online' : 'Offline',
                        'lastSeen': lastSeenDate,
                      };
                    }).toList();

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final h = constraints.maxHeight;

                        return Stack(
                          children: [
                            // Custom painted background map lines and radial scan
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: _anim,
                                builder: (context, child) {
                                  return CustomPaint(
                                    painter: _RadarGridPainter(
                                      nodes,
                                      _anim.value,
                                    ),
                                    size: Size.infinite,
                                  );
                                },
                              ),
                            ),
                            // Positioned interactive nodes on the overlay stack
                            ...nodes.map((node) {
                              final nx = w * (node['x'] as double);
                              final ny = h * (node['y'] as double);
                              final isOnline = node['status'] == 'Online';
                              final isSelected =
                                  _selectedNode != null &&
                                  _selectedNode!['code'] == node['code'];

                              return Positioned(
                                left: nx - 24,
                                top: ny - 24,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedNode = node;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(24),
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Ripple glow if online
                                        if (isOnline)
                                          AnimatedBuilder(
                                            animation: _anim,
                                            builder: (context, child) {
                                              final val = _anim.value;
                                              final radiusFactor = (val * 2)
                                                  .clamp(0.0, 1.0);
                                              return Container(
                                                width: 14 + (radiusFactor * 20),
                                                height:
                                                    14 + (radiusFactor * 20),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color:
                                                        const Color(
                                                          0xFF10B981,
                                                        ).withOpacity(
                                                          1.0 - radiusFactor,
                                                        ),
                                                    width: 1.5,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        // Node Core Circle
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: isOnline
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFEF4444),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.transparent,
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color:
                                                    (isOnline
                                                            ? const Color(
                                                                0xFF10B981,
                                                              )
                                                            : const Color(
                                                                0xFFEF4444,
                                                              ))
                                                        .withOpacity(0.6),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Tiny abbreviation label
                                        Positioned(
                                          bottom: 0,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black87,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: const Color(0xFF334155),
                                                width: 0.5,
                                              ),
                                            ),
                                            child: Text(
                                              (node['code'] as String)
                                                  .substring(
                                                    0,
                                                    min(
                                                      3,
                                                      (node['code'] as String)
                                                          .length,
                                                    ),
                                                  )
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          // Side details panel
          if (_selectedNode != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: isMobile ? double.infinity : 320,
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(left: BorderSide(color: Color(0xFF334155))),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'NODE INSPECTOR',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _selectedNode = null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedNode!['code'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedNode!['name'],
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (_selectedNode!['status'] == 'Online'
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFEF4444))
                                        .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedNode!['status'] == 'Online'
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                ),
                              ),
                              child: Text(
                                _selectedNode!['status'].toUpperCase(),
                                style: TextStyle(
                                  color: _selectedNode!['status'] == 'Online'
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.bolt,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _selectedNode!['latency'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'TELEMETRY DATA',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _telemetryRow(
                    'Registry Hash',
                    _selectedNode!['code'].hashCode
                        .abs()
                        .toString()
                        .toUpperCase(),
                  ),
                  _telemetryRow(
                    'Connection',
                    _selectedNode!['status'] == 'Online'
                        ? 'SECURE SOCKET'
                        : 'DISCONNECTED',
                  ),
                  _telemetryRow(
                    'Network Load',
                    _selectedNode!['status'] == 'Online' ? 'OPTIMAL' : 'N/A',
                  ),
                  _telemetryRow(
                    'Last Handshake',
                    _selectedNode!['lastSeen'] != null
                        ? '${(_selectedNode!['lastSeen'] as DateTime).hour.toString().padLeft(2, '0')}:${(_selectedNode!['lastSeen'] as DateTime).minute.toString().padLeft(2, '0')}'
                        : 'UNKNOWN',
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.settings, size: 18),
                      label: const Text(
                        'Configure Store Terminal',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _telemetryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarGridPainter extends CustomPainter {
  final List<Map<String, dynamic>> nodes;
  final double pulse;

  _RadarGridPainter(this.nodes, this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF0B132B);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw tech wireframe lines
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    final center = Offset(size.width / 2, size.height / 2);

    // Draw futuristic concentric circles
    final circlePaint = Paint()
      ..color = const Color(0xFF4F46E5).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (double r = 60; r < max(size.width, size.height); r += 100) {
      canvas.drawCircle(center, r, circlePaint);
    }

    // Radial sweep line
    final double angle = pulse * 2 * pi;
    final sweepPaint = Paint()
      ..color = const Color(0xFF4F46E5).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final sweepEnd = Offset(
      center.dx + 600 * cos(angle),
      center.dy + 600 * sin(angle),
    );
    canvas.drawLine(center, sweepEnd, sweepPaint);

    // Draw connection lines to active nodes
    for (var node in nodes) {
      final nx = size.width * (node['x'] as double);
      final ny = size.height * (node['y'] as double);
      final isOnline = node['status'] == 'Online';
      final nCenter = Offset(nx, ny);

      final linePaint = Paint()
        ..color = isOnline
            ? const Color(0xFF10B981).withOpacity(0.15)
            : const Color(0xFFEF4444).withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawLine(center, nCenter, linePaint);
    }

    // Central Server Node Core
    canvas.drawCircle(center, 10, Paint()..color = const Color(0xFF4F46E5));
    final pServer = Paint()
      ..color = const Color(0xFF4F46E5).withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 18, pServer);

    // Central Server pulse
    final double centerPulseRadius = 18 + ((pulse % 1.0) * 20);
    final pPulse = Paint()
      ..color = const Color(0xFF4F46E5).withOpacity(1.0 - (pulse % 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, centerPulseRadius, pPulse);

    final tpS = TextPainter(
      text: const TextSpan(
        text: 'COMMAND CONTROL SERVER',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpS.paint(canvas, Offset(center.dx - tpS.width / 2, center.dy + 24));
  }

  @override
  bool shouldRepaint(covariant _RadarGridPainter oldDelegate) => true;
}
