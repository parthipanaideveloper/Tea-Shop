import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../domain/models/order.dart';

class RevenueTrendChart extends StatelessWidget {
  final List<OrderModel> orders;
  final bool isDesktop;

  const RevenueTrendChart({super.key, required this.orders, this.isDesktop = false});

  @override
  Widget build(BuildContext context) {
    final Map<DateTime, double> revenueByDate = {};
    for (var order in orders) {
      if (!order.isVoided && !order.isRefunded && !order.isDeleted) {
        final localDate = order.date.toLocal();
        final date = DateTime(localDate.year, localDate.month, localDate.day);
        revenueByDate[date] = (revenueByDate[date] ?? 0) + order.total;
      }
    }
    
    if (revenueByDate.isEmpty) {
      return const SizedBox();
    }

    // Ensure we have at least 3 days for a trend
    if (revenueByDate.isNotEmpty && revenueByDate.length < 3) {
      final sortedKeys = revenueByDate.keys.toList()..sort();
      final latestDate = sortedKeys.last;
      for (int i = 1; i <= 2; i++) {
        final d = latestDate.subtract(Duration(days: i));
        if (!revenueByDate.containsKey(d)) {
          revenueByDate[d] = 0.0;
        }
      }
    }

    final sortedDates = revenueByDate.keys.toList()..sort();
    
    List<FlSpot> revenueSpots = [];
    double maxRevenue = 0;
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final revenue = revenueByDate[date]!;
      if (revenue > maxRevenue) maxRevenue = revenue;
      revenueSpots.add(FlSpot(i.toDouble(), revenue));
    }

    final maxY = maxRevenue == 0 ? 100.0 : maxRevenue * 1.2;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDesktop ? [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))
        ] : null,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Revenue Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: isDesktop ? 280 : 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? (maxY / 4) : 25,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: Colors.grey.shade100, strokeWidth: 1);
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: sortedDates.length > 7 ? (sortedDates.length / 5).ceilToDouble() : 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < sortedDates.length) {
                          final date = sortedDates[value.toInt()];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(DateFormat('MMM d').format(date), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      interval: maxY > 0 ? (maxY / 4) : 25,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text('');
                        return Text('₹${value.toInt()}', style: const TextStyle(color: Colors.grey, fontSize: 11));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (sortedDates.length > 1 ? sortedDates.length - 1 : 1).toDouble(),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: revenueSpots.isEmpty ? [const FlSpot(0, 0)] : (revenueSpots.length == 1 ? [revenueSpots[0], FlSpot(1, revenueSpots[0].y)] : revenueSpots),
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.green.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentMethodsDonutChart extends StatelessWidget {
  final double upi;
  final double cash;
  final double card;
  final bool isDesktop;

  const PaymentMethodsDonutChart({
    super.key, 
    required this.upi, 
    required this.cash, 
    required this.card,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final total = upi + cash + card;
    if (total == 0) {
       return const SizedBox(); 
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDesktop ? [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))
        ] : null,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: isDesktop ? 280 : 200,
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(enabled: false),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 4,
                      centerSpaceRadius: isDesktop ? 60 : 40,
                      sections: [
                        if (upi > 0)
                          PieChartSectionData(
                            color: Colors.blue,
                            value: upi,
                            title: '${((upi/total)*100).toStringAsFixed(0)}%',
                            radius: isDesktop ? 45 : 35,
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (cash > 0)
                          PieChartSectionData(
                            color: Colors.green,
                            value: cash,
                            title: '${((cash/total)*100).toStringAsFixed(0)}%',
                            radius: isDesktop ? 45 : 35,
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (card > 0)
                          PieChartSectionData(
                            color: Colors.purple,
                            value: card,
                            title: '${((card/total)*100).toStringAsFixed(0)}%',
                            radius: isDesktop ? 45 : 35,
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Indicator(color: Colors.blue, text: 'UPI', amount: upi),
                      const SizedBox(height: 16),
                      _Indicator(color: Colors.green, text: 'Cash', amount: cash),
                      const SizedBox(height: 16),
                      _Indicator(color: Colors.purple, text: 'Card', amount: card),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  final Color color;
  final String text;
  final double amount;

  const _Indicator({
    required this.color,
    required this.text,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: <Widget>[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
