import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../domain/models/product.dart';
import '../domain/models/cart_item.dart';
import '../domain/models/printer_profile.dart';
import '../providers/settings_provider.dart';
import '../core/hardware/printer_service.dart';
import 'package:flutter_usb_printer/flutter_usb_printer.dart';
import 'package:printing/printing.dart';

class PrintRouterService {
  static Future<void> printInventoryList({
    required List<Product> products,
    required SettingsState settings,
    required String shopName,
    required dynamic printerNotifier, // passing the notifier instance
    bool printTamil = false,
  }) async {
    final bytes = printTamil
        ? await PrinterService.generateInventoryImageBytes(
            products: products,
            shopName: shopName,
            is80mmPaper: settings.is80mmPaper,
          )
        : await PrinterService.generateInventoryBytes(
            products: products,
            shopName: shopName,
            is80mmPaper: settings.is80mmPaper,
          );
    await printerNotifier.printReceipt(bytes);
  }

  static Future<void> routeKOTs({
    required List<CartItem> items,
    required String orderId,
    required String orderType,
    required SettingsState settings,
    int? parcelToken,
    dynamic printerNotifier,
    String shopName = '',
  }) async {
    if (!settings.enableKotReceipt || !settings.enableMultiplePrinters) return;

    // Only route KOT to multiple kitchen printers for PARCEL orders
    if (orderType.toLowerCase() != 'parcel') {
      return;
    }

    bool didDisconnectBluetooth = false;

    for (final printer in settings.customPrinters) {
      if (!printer.isActive) continue;

      List<CartItem> matchedItems = [];

      if (printer.categories.isEmpty) {
        // Fallback: takes all items
        matchedItems = items;
      } else {
        matchedItems = items.where((i) {
          final catMatch = printer.categories.contains(i.product.category);
          final addCatMatch =
              i.product.additionalCategories?.any(
                (c) => printer.categories.contains(c),
              ) ??
              false;
          return catMatch || addCatMatch;
        }).toList();
      }

      if (matchedItems.isEmpty) continue;

      try {
        final bytes = await PrinterService.generateKitchenReceiptBytes(
          items: matchedItems,
          orderId: orderId,
          orderType: orderType,
          is80mmPaper: printer.is80mmPaper,
          printAsImage: settings.printAsImage,
          parcelToken: parcelToken,
          shopName: shopName,
          addressLine1: settings.addressLine1,
          addressLine2: settings.addressLine2,
          hotelType: settings.hotelType,
          mobileNumber: settings.mobileNumber,
          fssaiNumber: settings.fssaiNumber,
          gstNumber: settings.gstNumber,
          enableAddressOnReceipt: settings.enableAddressOnReceipt,
          enableMobileOnReceipt: settings.enableMobileOnReceipt,
          enableFssaiOnReceipt: settings.enableFssaiOnReceipt,
          enableHotelTypeOnReceipt: settings.enableHotelTypeOnReceipt,
          enableShopDetailsOnKot: settings.enableShopDetailsOnKot,
          showGstOnReceipt: settings.showGstOnReceipt,
        );

        if (bytes == null) continue;

        // Bypass for Windows System Printers
        if (defaultTargetPlatform == TargetPlatform.windows) {
          final printers = await Printing.listPrinters();
          final targetPrinter = printers.firstWhere(
            (p) => p.url == printer.identifier || p.name == printer.identifier,
            orElse: () => printers.first,
          );
          
          if (!targetPrinter.isAvailable) {
            throw Exception('KOT Printer "${targetPrinter.name}" is offline. Print job skipped.');
          }

          await Printing.directPrintPdf(
            printer: targetPrinter,
            onLayout: (format) async => Uint8List.fromList(bytes),
          );
          continue;
        }

        if (printer.type == 'Network') {
          await _printToNetwork(printer.identifier, bytes);
        } else if (printer.type == 'Bluetooth') {
          await _printToBluetooth(printer.identifier, bytes);
          didDisconnectBluetooth = true;
        } else if (printer.type == 'USB') {
          await _printToUSB(printer.identifier, bytes);
        }
      } catch (e) {
        debugPrint('Failed to route KOT to ${printer.name}: $e');
      }
    }

    if (didDisconnectBluetooth &&
        settings.printerConnectionType == 'Bluetooth' &&
        printerNotifier != null) {
      try {
        await Future.delayed(const Duration(milliseconds: 1500));
        await printerNotifier.autoConnect();
      } catch (e) {
        debugPrint('Failed to fallback reconnect to main BT printer: $e');
      }
    }
  }

  static Future<void> _printToNetwork(String ip, List<int> bytes) async {
    if (kIsWeb) {
      debugPrint(
        'Web Network KOT Print Mock: printed ${bytes.length} bytes to $ip',
      );
      return;
    }
    Socket? socket;
    try {
      // Typically ESC/POS network printers use port 9100
      socket = await Socket.connect(
        ip,
        9100,
        timeout: const Duration(seconds: 3),
      );
      socket.add(bytes);
      await socket.flush();
    } catch (e) {
      debugPrint('Network Printer Error ($ip): $e');
      throw e;
    } finally {
      socket?.destroy();
    }
  }

  static Future<void> _printToBluetooth(String mac, List<int> bytes) async {
    try {
      // Disconnect any existing connection first to free up the adapter
      await PrintBluetoothThermal.disconnect;
      await Future.delayed(
        const Duration(milliseconds: 1500),
      ); // Need ample time for Android OS to clear socket

      bool connected = false;
      int retries = 3;

      while (retries > 0 && !connected) {
        connected = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
        if (!connected) {
          retries--;
          if (retries > 0) {
            await Future.delayed(const Duration(milliseconds: 1000));
          }
        }
      }

      if (connected) {
        await PrintBluetoothThermal.writeBytes(bytes);
        // Wait a bit for the buffer to flush to the printer
        await Future.delayed(const Duration(milliseconds: 1000));
        // Disconnect immediately to free up the BT adapter for the main printer
        await PrintBluetoothThermal.disconnect;
        // Wait for the adapter to free up
        await Future.delayed(const Duration(milliseconds: 1500));
      } else {
        throw Exception('Could not connect to BT printer $mac after retries');
      }
    } catch (e) {
      debugPrint('Bluetooth Printer Error ($mac): $e');
      throw e;
    }
  }

  static Future<void> _printToUSB(String identifier, List<int> bytes) async {
    try {
      final flutterUsbPrinter = FlutterUsbPrinter();
      final devices = await FlutterUsbPrinter.getUSBDeviceList();
      if (devices.isEmpty) throw Exception('No USB printers found');

      int? targetVendorId;
      int? targetProductId;
      if (identifier.startsWith('USB_')) {
        final parts = identifier.split('_');
        if (parts.length >= 3) {
          targetVendorId = int.tryParse(parts[1]);
          targetProductId = int.tryParse(parts[2]);
        }
      } else if (identifier.isNotEmpty && identifier != 'USB') {
        final parts = identifier.split('_');
        if (parts.length >= 2) {
          targetVendorId = int.tryParse(parts[0]);
          targetProductId = int.tryParse(parts[1]);
        }
      }

      Map<dynamic, dynamic>? device;
      if (targetVendorId != null && targetProductId != null) {
        for (final d in devices) {
          final int vId = d['vendorId'] is int
              ? d['vendorId'] as int
              : int.parse(d['vendorId']!.toString());
          final int pId = d['productId'] is int
              ? d['productId'] as int
              : int.parse(d['productId']!.toString());
          if (vId == targetVendorId && pId == targetProductId) {
            device = d;
            break;
          }
        }
      }

      if (device == null) {
        for (final d in devices) {
          final manufacturer = (d['manufacturer'] ?? '')
              .toString()
              .toLowerCase();
          final productName = (d['productName'] ?? '').toString().toLowerCase();
          if (manufacturer.contains('print') ||
              manufacturer.contains('pos') ||
              manufacturer.contains('thermal') ||
              productName.contains('print') ||
              productName.contains('pos') ||
              productName.contains('thermal')) {
            device = d;
            break;
          }
        }
      }

      device ??= devices.first;

      final int vendorId = device['vendorId'] is int
          ? device['vendorId'] as int
          : int.parse(device['vendorId']!.toString());
      final int productId = device['productId'] is int
          ? device['productId'] as int
          : int.parse(device['productId']!.toString());
      bool? connected = await flutterUsbPrinter.connect(vendorId, productId);

      if (connected == true) {
        await flutterUsbPrinter.write(Uint8List.fromList(bytes));
      } else {
        throw Exception('Failed to connect to USB printer');
      }
    } catch (e) {
      debugPrint('USB Printer Error: $e');
      throw e;
    }
  }

  static Future<bool> checkConnection(PrinterProfile printer) async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      try {
        final printers = await Printing.listPrinters();
        return printers.any(
          (p) => p.url == printer.identifier || p.name == printer.identifier,
        );
      } catch (_) {
        return false;
      }
    }
    try {
      if (printer.type == 'Network') {
        if (kIsWeb) return true;
        final socket = await Socket.connect(
          printer.identifier,
          9100,
          timeout: const Duration(seconds: 1),
        );
        socket.destroy();
        return true;
      } else if (printer.type == 'USB') {
        final devices = await FlutterUsbPrinter.getUSBDeviceList();
        if (devices.isEmpty) return false;

        int? targetVendorId;
        int? targetProductId;
        if (printer.identifier.startsWith('USB_')) {
          final parts = printer.identifier.split('_');
          if (parts.length >= 3) {
            targetVendorId = int.tryParse(parts[1]);
            targetProductId = int.tryParse(parts[2]);
          }
        }

        if (targetVendorId != null && targetProductId != null) {
          for (final d in devices) {
            final int vId = d['vendorId'] is int
                ? d['vendorId'] as int
                : int.parse(d['vendorId']!.toString());
            final int pId = d['productId'] is int
                ? d['productId'] as int
                : int.parse(d['productId']!.toString());
            if (vId == targetVendorId && pId == targetProductId) {
              return true;
            }
          }
          return false;
        }

        // If no saved ID, check if any printer is connected
        for (final d in devices) {
          final manufacturer = (d['manufacturer'] ?? '')
              .toString()
              .toLowerCase();
          final productName = (d['productName'] ?? '').toString().toLowerCase();
          if (manufacturer.contains('print') ||
              manufacturer.contains('pos') ||
              manufacturer.contains('thermal') ||
              productName.contains('print') ||
              productName.contains('pos') ||
              productName.contains('thermal')) {
            return true;
          }
        }
        return false;
      } else if (printer.type == 'Bluetooth') {
        bool alreadyConnected = await PrintBluetoothThermal.connectionStatus;
        if (alreadyConnected) {
          return true; // Already connected, don't disrupt the socket
        }
        bool connected = await PrintBluetoothThermal.connect(
          macPrinterAddress: printer.identifier,
        );
        if (connected) await PrintBluetoothThermal.disconnect;
        return connected;
      }
    } catch (_) {
      return false;
    }
    return false;
  }
}
