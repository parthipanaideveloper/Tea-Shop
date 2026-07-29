import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'customer_history_screen.dart';
import '../widgets/neumorphic_widgets.dart';

class Customer {
  final String id;
  final String name;
  final String phone;
  final String email;
  final int totalOrders;
  final double totalSpent;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.totalOrders = 0,
    this.totalSpent = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'totalOrders': totalOrders,
    'totalSpent': totalSpent,
  };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    email: json['email'] as String? ?? '',
    totalOrders: json['totalOrders'] as int? ?? 0,
    totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0);
}

class CustomersNotifier extends Notifier<List<Customer>> {
  @override
  List<Customer> build() {
    final box = Hive.box<String>('customers');
    final List<Customer> customers = [];
    for (var key in box.keys) {
      final jsonString = box.get(key);
      if (jsonString != null) {
        customers.add(Customer.fromJson(jsonDecode(jsonString)));
      }
    }
    return customers;
  }

  void addCustomer(Customer customer) {
    final box = Hive.box<String>('customers');
    box.put(customer.id, jsonEncode(customer.toJson()));
    state = [...state, customer];
  }

  void updateCustomer(Customer updatedCustomer) {
    final box = Hive.box<String>('customers');
    box.put(updatedCustomer.id, jsonEncode(updatedCustomer.toJson()));
    state = state
        .map((c) => c.id == updatedCustomer.id ? updatedCustomer : c)
        .toList();
  }

  void deleteCustomer(String id) {
    final box = Hive.box<String>('customers');
    box.delete(id);
    state = state.where((c) => c.id != id).toList();
  }
}

final customersProvider = NotifierProvider<CustomersNotifier, List<Customer>>(
  CustomersNotifier.new);

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _searchQuery = '';
  Customer? _selectedCustomerForHistory;

  // Call utility
  Future<void> _makeCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber.replaceAll(' ', ''));
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  // Email utility
  Future<void> _sendEmail(String emailAddress) async {
    final Uri launchUri = Uri(scheme: 'mailto', path: emailAddress);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allCustomers = ref.watch(customersProvider);
    
    // Filter customers based on search query
    final customers = _searchQuery.isEmpty 
        ? allCustomers 
        : allCustomers.where((c) => 
            c.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
            c.phone.contains(_searchQuery) ||
            c.email.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();
          

    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final canPop = Navigator.canPop(context);

    if (isDesktop && _selectedCustomerForHistory != null) {
      return CustomerHistoryScreen(
        customer: _selectedCustomerForHistory!,
        onBack: () => setState(() => _selectedCustomerForHistory = null),
      );
    }

    return Scaffold(
      backgroundColor: isDesktop ? NeumorphicTheme.background : null,
      appBar: isDesktop ? null : AppBar(
        title: const Text('Customer Management'),
        elevation: 0,
        automaticallyImplyLeading: canPop,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop())
            : null,
      ),
      body: customers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No Customers Yet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  Text('Add customers to start tracking their orders.', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isGrid = constraints.maxWidth >= 800;
                
                Widget buildCustomerCard(customer) {
                  return Card(
                    color: Colors.white,
                    elevation: 4,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3), width: 1.5)
                    ),
                    margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                                child: Text(
                                  customer.name.isNotEmpty
                                      ? customer.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20))),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            customer.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18))),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _showAddCustomerDialog(context, ref, customer: customer)),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Delete Customer?'),
                                                content: Text('Are you sure you want to delete ${customer.name}?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx),
                                                    child: const Text('Cancel')),
                                                  TextButton(
                                                    onPressed: () {
                                                      ref.read(customersProvider.notifier).deleteCustomer(customer.id);
                                                      Navigator.pop(ctx);
                                                    },
                                                    child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                                ]));
                                          }),
                                        const SizedBox(width: 8),
                                      ]),
                                    const SizedBox(height: 4),
                                    Text(
                                      customer.phone,
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                                    if (customer.email.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        customer.email,
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                    ],
                                  ])),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${customer.totalSpent.toStringAsFixed(0)}',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green)),
                                  Text(
                                    '${customer.totalOrders} Orders',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ]),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton.icon(
                                onPressed: customer.phone.isNotEmpty ? () => _makeCall(customer.phone) : null,
                                icon: const Icon(Icons.call, size: 18),
                                label: const Text('Call')),
                              TextButton.icon(
                                onPressed: customer.email.isNotEmpty ? () => _sendEmail(customer.email) : null,
                                icon: const Icon(Icons.email, size: 18),
                                label: const Text('Email')),
                              TextButton.icon(
                                onPressed: () {
                                  if (isDesktop) {
                                    setState(() => _selectedCustomerForHistory = customer);
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => CustomerHistoryScreen(customer: customer)));
                                  }
                                },
                                icon: const Icon(Icons.history, size: 18),
                                label: const Text('History')),
                            ]),
                        ])));
                }

                if (isGrid) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search customers by name, phone, or email...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 450,
                            childAspectRatio: 2.3,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: customers.length,
                          itemBuilder: (context, index) => buildCustomerCard(customers[index]),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search customers...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: customers.length,
                          itemBuilder: (context, index) => buildCustomerCard(customers[index]),
                        ),
                      ),
                    ],
                  );
                }
              }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCustomerDialog(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer')));
  }

  void _showAddCustomerDialog(
    BuildContext context,
    WidgetRef ref, {
    Customer? customer,
  }) {
    final formKey = GlobalKey<FormState>();
    final isEdit = customer != null;
    String name = customer?.name ?? '';
    String phone = customer?.phone ?? '';
    String email = customer?.email ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isEdit ? 'Edit Customer' : 'New Customer',
            style: const TextStyle(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: name,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder()),
                    validator: (v) =>
                        v!.isEmpty ? 'Full name is required' : null,
                    onChanged: (val) => name = val),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder()),
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        v!.isEmpty ? 'Phone number is required' : null,
                    onChanged: (val) => phone = val),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: email,
                    decoration: const InputDecoration(
                      labelText: 'Email Address (Optional)',
                      border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (val) => email = val),
                ]))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  if (isEdit) {
                    ref
                        .read(customersProvider.notifier)
                        .updateCustomer(
                          Customer(
                            id: customer.id,
                            name: name.trim(),
                            phone: phone.trim(),
                            email: email.trim(),
                            totalOrders: customer.totalOrders,
                            totalSpent: customer.totalSpent));
                  } else {
                    ref
                        .read(customersProvider.notifier)
                        .addCustomer(
                          Customer(
                            id: const Uuid().v4(),
                            name: name.trim(),
                            phone: phone.trim(),
                            email: email.trim()));
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('Confirm & Save')),
          ]);
      });
  }
}
