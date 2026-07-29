import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../domain/models/product.dart';
import '../domain/models/order.dart';
import '../domain/models/expense.dart';

class BackupService {
  Future<String?> exportBackup(String shopName, String password) async {
    try {
      final productBox = Hive.box<Product>('products');
      final orderBox = Hive.box<OrderModel>('orders');
      final settingsBox = Hive.box<String>('settings');
      final expenseBox = Hive.box<Expense>('expenses');

      final List<Map<String, dynamic>> productsList = productBox.values
          .map(
            (p) => {
              'id': p.id,
              'name': p.name,
              'nameTamil': p.nameTamil,
              'category': p.category,
              'categoryTamil': p.categoryTamil,
              'additionalCategories': p.additionalCategories,
              'price': p.price,
              'stockCount': p.stockCount,
              'barcode': p.barcode,
              'allowHalfPortion': p.allowHalfPortion,
            })
          .toList();

      final List<Map<String, dynamic>> ordersList = orderBox.values
          .map(
            (o) => {
              'id': o.id,
              'total': o.total,
              'subtotal': o.subtotal,
              'tax': o.tax,
              'discount': o.discount,
              'date': o.date.toIso8601String(),
              'itemsJson': o.itemsJson,
            })
          .toList();

      final List<Map<String, dynamic>> expensesList = expenseBox.values
          .map(
            (e) => {
              'id': e.id,
              'title': e.title,
              'amount': e.amount,
              'category': e.category,
              'date': e.date.toIso8601String(),
              'notes': e.notes,
            })
          .toList();

      // Collect settings
      final Map<String, String> settingsMap = {};
      for (final key in settingsBox.keys) {
        final val = settingsBox.get(key);
        if (val != null) {
          settingsMap[key.toString()] = val;
        }
      }

      final Map<String, dynamic> backupPayload = {
        'backup_timestamp': DateTime.now().toIso8601String(),
        'shopName': shopName,
        'products': productsList,
        'orders': ordersList,
        'expenses': expensesList,
        'settings': settingsMap,
      };

      final String rawJson = jsonEncode(backupPayload);

      // Obfuscate backup string using base64 + XOR with the custom password
      final List<int> bytes = utf8.encode(rawJson);
      final String secureSalt = password; // Use user-provided password
      final List<int> encryptedBytes = List<int>.generate(bytes.length, (i) {
        return bytes[i] ^ secureSalt.codeUnitAt(i % secureSalt.length);
      });

      final String base64Payload = base64Encode(encryptedBytes);

      // Prompt user to pick a save location
      final formattedDate = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final String filename = 'DTS_POS_BACKUP_$formattedDate.dts';

      String? selectedDirectory;
      String? outputFile;

      if (kIsWeb) {
        // Not supported
        return null;
      } else if (Platform.isAndroid || Platform.isIOS) {
        // Fallback for mobile: standard downloads
        Directory? dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
        if (dir != null) {
          selectedDirectory = dir.path;
          outputFile = '${dir.path}/$filename';
        }
      } else {
        // Desktop: Open save file dialog
        outputFile = await FilePicker.saveFile(
          dialogTitle: 'Save Backup File',
          fileName: filename,
          type: FileType.custom,
          allowedExtensions: ['dts'],
        );
      }

      if (outputFile == null) return null;

      final File file = File(outputFile);
      await file.writeAsString(base64Payload);

      return file.path;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Export Backup Error: $e");
      }
      return null;
    }
  }

  Future<bool> importBackup(File file, String password) async {
    try {
      final String base64Payload = await file.readAsString();
      final List<int> encryptedBytes = base64Decode(base64Payload.trim());

      final String secureSalt = password; // Use user-provided password
      final List<int> decryptedBytes = List<int>.generate(
        encryptedBytes.length,
        (i) {
          return encryptedBytes[i] ^
              secureSalt.codeUnitAt(i % secureSalt.length);
        });

      final String rawJson = utf8.decode(decryptedBytes);
      final Map<String, dynamic> backupPayload = jsonDecode(rawJson);

      final productBox = Hive.box<Product>('products');
      final orderBox = Hive.box<OrderModel>('orders');
      final settingsBox = Hive.box<String>('settings');
      final expenseBox = Hive.box<Expense>('expenses');

      // Clear existing values safely
      await productBox.clear();
      await orderBox.clear();
      await expenseBox.clear();

      // Restore products
      final List<dynamic> productsList = backupPayload['products'] ?? [];
      for (final item in productsList) {
        final p = Product(
          id: item['id'],
          name: item['name'],
          nameTamil: item['nameTamil'],
          category: item['category'],
          categoryTamil: item['categoryTamil'],
          additionalCategories: item['additionalCategories'] != null
              ? List<String>.from(item['additionalCategories'])
              : null,
          price: (item['price'] as num).toDouble(),
          stockCount: (item['stockCount'] as num).toInt(),
          barcode: item['barcode'],
          allowHalfPortion: item['allowHalfPortion'] ?? false);
        await productBox.put(p.id, p);
      }

      // Restore orders
      final List<dynamic> ordersList = backupPayload['orders'] ?? [];
      for (final item in ordersList) {
        final o = OrderModel(
          id: item['id'],
          total: (item['total'] as num).toDouble(),
          subtotal: (item['subtotal'] as num).toDouble(),
          tax: (item['tax'] as num).toDouble(),
          discount: (item['discount'] as num).toDouble(),
          date: DateTime.parse(item['date']),
          itemsJson: item['itemsJson']);
        await orderBox.put(o.id, o);
      }

      // Restore expenses
      final List<dynamic> expensesList = backupPayload['expenses'] ?? [];
      for (final item in expensesList) {
        final e = Expense(
          id: item['id'] ?? '',
          title: item['title'] ?? '',
          amount: (item['amount'] as num).toDouble(),
          category: item['category'] ?? 'Others',
          date: DateTime.parse(item['date']),
          notes: item['notes']);
        await expenseBox.put(e.id, e);
      }

      // Restore settings
      final Map<String, dynamic> settingsMap = backupPayload['settings'] ?? {};
      settingsMap.forEach((key, val) {
        settingsBox.put(key, val.toString());
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Import Backup Error: $e");
      }
      return false;
    }
  }
}
