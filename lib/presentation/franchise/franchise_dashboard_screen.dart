import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_sync_service.dart';

class FranchiseSalesDashboardScreen extends StatefulWidget {
  const FranchiseSalesDashboardScreen({super.key});

  @override
  State<FranchiseSalesDashboardScreen> createState() =>
      _FranchiseSalesDashboardScreenState();
}

class _FranchiseSalesDashboardScreenState
    extends State<FranchiseSalesDashboardScreen> {
  List<String> _ownedShops = [];
  String _selectedBranch = 'All Branches';
  
  DateTime _startDate = DateTime.now().copyWith(hour: 0, minute: 0, second: 0);
  DateTime _endDate = DateTime.now().copyWith(hour: 23, minute: 59, second: 59);

  bool _isLoading = false;
  Map<String, double> _branchSales = {};

  @override
  void initState() {
    super.initState();
    _loadOwnedShops();
    _fetchData();
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

  Future<void> _fetchData() async {
    if (_ownedShops.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    List<String> targetShops = _selectedBranch == 'All Branches'
        ? _ownedShops
        : [_selectedBranch];

    final data = await FirebaseSyncService().fetchFranchiseSalesSummary(
        targetShops, _startDate, _endDate);
        
    if (mounted) {
      setState(() {
        _branchSales = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    DateTime start = _startDate;
    DateTime end = _endDate;

    final DateTimeRange? pickedRange = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Select Date Range', style: TextStyle(fontWeight: FontWeight.bold)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Start Date'),
                    subtitle: Text(DateFormat('EEEE, MMMM d, yyyy').format(start)),
                    leading: const Icon(Icons.calendar_today, color: Colors.blue),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: start,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setStateDialog(() {
                          start = picked;
                          if (end.isBefore(start)) {
                            end = start;
                          }
                        });
                      }
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('End Date'),
                    subtitle: Text(DateFormat('EEEE, MMMM d, yyyy').format(end)),
                    leading: const Icon(Icons.calendar_today, color: Colors.green),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: end,
                        firstDate: start,
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setStateDialog(() {
                          end = picked;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(context, DateTimeRange(start: start, end: end));
                  },
                  child: const Text('Apply')),
              ],
            );
          },
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        _startDate = pickedRange.start.copyWith(hour: 0, minute: 0, second: 0);
        _endDate = pickedRange.end.copyWith(hour: 23, minute: 59, second: 59);
      });
      _fetchData();
    }
  }

  double get _totalSales {
    return _branchSales.values.fold(0.0, (sum, val) => sum + val);
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Sales Dashboard'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Filter by Date'),
        ]),
      body: Container(
        color: Colors.blue.shade50,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Filters Row
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_alt, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Branch Filter:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedBranch,
                          underline: const SizedBox(),
                          items: [
                            const DropdownMenuItem(
                              value: 'All Branches',
                              child: Text('All Branches (Total)', style: TextStyle(fontWeight: FontWeight.bold))),
                            ..._ownedShops.map((shop) => DropdownMenuItem(
                                  value: shop,
                                  child: Text('Branch: $shop'))),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedBranch = val);
                              _fetchData();
                            }
                          })),
                    ]))),
              const SizedBox(height: 16),
              
              // Total Summary Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.blue.shade600,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        _selectedBranch == 'All Branches'
                            ? 'TOTAL SALES ACROSS ALL BRANCHES'
                            : 'TOTAL SALES FOR $_selectedBranch',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                      const SizedBox(height: 8),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: CircularProgressIndicator(color: Colors.white))
                      else
                        Text(
                          currencyFormat.format(_totalSales),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          '${DateFormat('MMM d, yyyy').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}',
                          style: const TextStyle(color: Colors.white))),
                    ]))),
              const SizedBox(height: 16),

              // Breakdown List
              if (_selectedBranch == 'All Branches') ...[
                const Padding(
                  padding: EdgeInsets.only(left: 8, bottom: 8),
                  child: Text(
                    'Branch Breakdown',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue))),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: _branchSales.length,
                          itemBuilder: (context, index) {
                            final shopCode = _branchSales.keys.elementAt(index);
                            final amount = _branchSales[shopCode]!;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.blue,
                                  child: Icon(Icons.store, color: Colors.white)),
                                title: Text(
                                  shopCode,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                                trailing: Text(
                                  currencyFormat.format(amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.green))));
                          })),
              ] else
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bar_chart, size: 80, color: Colors.blue.shade200),
                        const SizedBox(height: 16),
                        const Text(
                          'Detailed reports are available inside the branch dashboard.',
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ]))),
            ]), // Column
        ), // Padding
      ), // ConstrainedBox
    ), // Center
  ), // Container
); // Scaffold
  }
}
