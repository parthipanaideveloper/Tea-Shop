import 'package:pos/core/utils/notification_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../providers/auth_provider.dart';

class ExpenseAdderScreen extends ConsumerStatefulWidget {
  const ExpenseAdderScreen({super.key});

  @override
  ConsumerState<ExpenseAdderScreen> createState() => _ExpenseAdderScreenState();
}

class _ExpenseAdderScreenState extends ConsumerState<ExpenseAdderScreen> {

  void _showExpenseDialog({Expense? expense}) {
    final categories = ref.read(expenseCategoriesProvider);
    final isEditing = expense != null;
    final formKey = GlobalKey<FormState>();
    final amountCtrl = TextEditingController(text: isEditing ? expense.amount.toString() : '');
    final descCtrl = TextEditingController(text: isEditing ? expense.notes?.replaceAll(RegExp(r' \(By .*\)$'), '') ?? '' : '');
    String selectedCategory = isEditing ? expense.category : (categories.isNotEmpty ? categories.first : 'Miscellaneous');
    if (!categories.contains(selectedCategory)) {
      selectedCategory = categories.isNotEmpty ? categories.first : 'Miscellaneous';
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Expense' : 'Add Expense', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Amount (Rs.)',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          if (double.tryParse(val) == null) return 'Invalid number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => selectedCategory = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Description (Optional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48), foregroundColor: Colors.white),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final amount = double.tryParse(amountCtrl.text) ?? 0.0;
                      if (amount <= 0) {
                        NotificationHelper.showCenter(context, 'Please enter a valid amount', isError: true);
                        return;
                      }

                      final authState = ref.read(authProvider);
                      final staffName = authState?.id != 'host_admin' 
                          ? (authState?.id ?? 'Staff')
                          : 'Staff';

                      if (isEditing) {
                        final updatedExpense = expense.copyWith(
                          amount: amount,
                          category: selectedCategory,
                          title: selectedCategory,
                          notes: '${descCtrl.text.trim()} (By $staffName)',
                        );
                        ref.read(expenseProvider.notifier).updateExpense(updatedExpense);
                        NotificationHelper.showCenter(context, 'Expense updated', isError: false);
                      } else {
                        final newExpense = Expense(
                          id: const Uuid().v4(),
                          title: selectedCategory,
                          amount: amount,
                          category: selectedCategory,
                          date: DateTime.now(),
                          notes: '${descCtrl.text.trim()} (By $staffName)',
                        );
                        ref.read(expenseProvider.notifier).addExpense(newExpense);
                        NotificationHelper.showCenter(context, 'Expense logged', isError: false);
                      }
                      Navigator.pop(context);
                    }
                  },
                  child: Text(isEditing ? 'UPDATE' : 'SAVE'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _confirmDelete(Expense expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              ref.read(expenseProvider.notifier).deleteExpense(expense.id);
              Navigator.pop(ctx);
              NotificationHelper.showCenter(context, 'Expense deleted', isError: false);
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allExpenses = ref.watch(expenseProvider);
    final now = DateTime.now();
    // Filter for TODAY only
    final todayExpenses = allExpenses.where((e) {
      final localDate = e.date.toLocal();
      return localDate.year == now.year && localDate.month == now.month && localDate.day == now.day;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Today\'s Expenses', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFFE11D48),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: todayExpenses.isEmpty 
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.black26),
                SizedBox(height: 16),
                Text('No expenses added today.', style: TextStyle(fontSize: 16, color: Colors.black54)),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: todayExpenses.length,
            itemBuilder: (context, index) {
              final expense = todayExpenses[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE11D48).withOpacity(0.1),
                    child: const Icon(Icons.receipt_long, color: Color(0xFFE11D48)),
                  ),
                  title: Text(expense.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(DateFormat('hh:mm a').format(expense.date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      if (expense.notes != null && expense.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(expense.notes!, style: const TextStyle(fontSize: 13, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ]
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('₹${expense.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFE11D48))),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showExpenseDialog(expense: expense);
                          } else if (value == 'delete') {
                            _confirmDelete(expense);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Edit')])),
                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFE11D48),
        foregroundColor: Colors.white,
        onPressed: () => _showExpenseDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
