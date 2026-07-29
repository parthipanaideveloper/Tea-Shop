import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import '../domain/models/expense.dart';
import '../services/firebase_sync_service.dart';

class ExpenseNotifier extends Notifier<List<Expense>> {
  @override
  List<Expense> build() {
    final box = Hive.box<Expense>('expenses');
    box.watch().listen((_) {
      state = box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    });
    return box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<String?> addExpense(Expense expense) async {
    if (expense.amount <= 0) {
      return 'Expense amount must be greater than 0';
    }
    final box = Hive.box<Expense>('expenses');
    await box.put(expense.id, expense);
    FirebaseSyncService().pushExpense(expense);
    return null;
  }

  Future<String?> updateExpense(Expense expense) async {
    if (expense.amount <= 0) {
      return 'Expense amount must be greater than 0';
    }
    final box = Hive.box<Expense>('expenses');
    await box.put(expense.id, expense);
    FirebaseSyncService().pushExpense(expense);
    return null;
  }

  Future<void> deleteExpense(String id) async {
    final box = Hive.box<Expense>('expenses');
    await box.delete(id);
    FirebaseSyncService().deleteExpense(id);
  }

  Future<void> clearAllExpenses() async {
    final box = Hive.box<Expense>('expenses');
    final allExpenses = box.values.toList();
    await box.clear();
    for (var e in allExpenses) {
      FirebaseSyncService().deleteExpense(e.id);
    }
    state = [];
  }
}

final expenseProvider = NotifierProvider<ExpenseNotifier, List<Expense>>(() {
  return ExpenseNotifier();
});

class ExpenseCategoriesNotifier extends Notifier<List<String>> {
  static const String _boxKey = 'expense_categories';
  static const List<String> _defaultCategories = [
    'Raw Materials & Supplies',
    'Travel & Transport',
    'Maintenance & Repairs',
    'Utility Bills',
    'Staff Expenses',
    'Miscellaneous'
  ];

  @override
  List<String> build() {
    final box = Hive.box<String>('settings');
    // Listen to changes in the Hive box to handle sync down from other devices
    box.watch(key: _boxKey).listen((_) {
      final storedJson = box.get(_boxKey);
      if (storedJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(storedJson);
          state = decoded.cast<String>();
        } catch (_) {}
      }
    });

    final storedJson = box.get(_boxKey);
    if (storedJson == null) {
      return _defaultCategories;
    }
    try {
      final List<dynamic> decoded = jsonDecode(storedJson);
      return decoded.cast<String>();
    } catch (_) {
      return _defaultCategories;
    }
  }

  Future<void> addCategory(String category) async {
    final box = Hive.box<String>('settings');
    final trimmed = category.trim();
    if (trimmed.isEmpty || state.contains(trimmed)) return;
    
    final updated = [...state, trimmed];
    await box.put(_boxKey, jsonEncode(updated));
    state = updated;
    FirebaseSyncService().pushSettingsSync(); // Sync up instantly
  }

  Future<void> removeCategory(String category) async {
    final box = Hive.box<String>('settings');
    final updated = state.where((c) => c != category).toList();
    await box.put(_boxKey, jsonEncode(updated));
    state = updated;

    // Reassign existing expenses under deleted category to 'Miscellaneous'
    try {
      final expBox = Hive.box<Expense>('expenses');
      for (var exp in expBox.values.toList()) {
        if (exp.category == category || exp.title == category) {
          final updatedExp = exp.copyWith(
            category: exp.category == category ? 'Miscellaneous' : exp.category,
            title: exp.title == category ? 'Miscellaneous' : exp.title,
          );
          await expBox.put(exp.id, updatedExp);
          FirebaseSyncService().pushExpense(updatedExp);
        }
      }
    } catch (_) {}

    FirebaseSyncService().pushSettingsSync(); // Sync up instantly
  }

  Future<void> editCategory(String oldCategory, String newCategory) async {
    final box = Hive.box<String>('settings');
    final trimmedNew = newCategory.trim();
    if (trimmedNew.isEmpty || state.contains(trimmedNew)) return;

    final updated = state.map((c) => c == oldCategory ? trimmedNew : c).toList();
    await box.put(_boxKey, jsonEncode(updated));
    state = updated;

    // Update all existing expenses under oldCategory
    try {
      final expBox = Hive.box<Expense>('expenses');
      for (var exp in expBox.values.toList()) {
        if (exp.category == oldCategory || exp.title == oldCategory) {
          final updatedExp = exp.copyWith(
            category: exp.category == oldCategory ? trimmedNew : exp.category,
            title: exp.title == oldCategory ? trimmedNew : exp.title,
          );
          await expBox.put(exp.id, updatedExp);
          FirebaseSyncService().pushExpense(updatedExp);
        }
      }
    } catch (_) {}

    FirebaseSyncService().pushSettingsSync(); // Sync up instantly
  }
}

final expenseCategoriesProvider = NotifierProvider<ExpenseCategoriesNotifier, List<String>>(() {
  return ExpenseCategoriesNotifier();
});
