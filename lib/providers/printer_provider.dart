import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:flutter_usb_printer/flutter_usb_printer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'settings_provider.dart';

class PrinterState {
  final bool isScanning;
  final List<BluetoothInfo> devices;
  final BluetoothInfo? connectedDevice;

  PrinterState({
    this.isScanning = false,
    this.devices = const [],
    this.connectedDevice,
  });

  PrinterState copyWith({
    bool? isScanning,
    List<BluetoothInfo>? devices,
    BluetoothInfo? connectedDevice,
    bool clearConnectedDevice = false,
  }) {
    return PrinterState(
      isScanning: isScanning ?? this.isScanning,
      devices: devices ?? this.devices,
      connectedDevice: clearConnectedDevice
          ? null
          : (connectedDevice ?? this.connectedDevice));
  }
}

class PrinterNotifier extends Notifier<PrinterState> {
  bool _isUsbConnected = false;

  @override
  PrinterState build() {
    return PrinterState();
  }

  Future<void> startScan() async {
    state = state.copyWith(isScanning: true, devices: []);
    try {
      final settings = ref.read(settingsProvider);
      final connectionType = settings.printerConnectionType;

      if (kIsWeb) {
        final results = [
          BluetoothInfo(name: 'Mock Web Receipt Printer 1', macAdress: '192.168.1.100'),
          BluetoothInfo(name: 'Mock Web USB Printer 2', macAdress: 'USB_0001_0002'),
        ];
        state = state.copyWith(isScanning: false, devices: results);
        return;
      }

      if (defaultTargetPlatform == TargetPlatform.windows) {
        final printers = await Printing.listPrinters();
        final results = printers
            .map((p) => BluetoothInfo(name: p.name, macAdress: p.url))
            .toList();
        state = state.copyWith(isScanning: false, devices: results);
        return;
      }

      if (connectionType == 'Network') {
        final List<String> commonIps = [
          '192.168.1.100',
          '192.168.1.150',
          '192.168.1.200',
          '192.168.0.100',
          '192.168.0.150',
          '192.168.0.200',
        ];
        
        final List<BluetoothInfo> found = [];
        final futures = commonIps.map((ip) async {
          try {
            final socket = await Socket.connect(ip, 9100, timeout: const Duration(milliseconds: 300));
            socket.destroy();
            found.add(BluetoothInfo(name: 'Network Printer ($ip)', macAdress: ip));
          } catch (_) {}
        });
        await Future.wait(futures);
        state = state.copyWith(isScanning: false, devices: found);
        return;
      } else if (connectionType == 'USB') {
        final List<Map<dynamic, dynamic>> usbDevices = await FlutterUsbPrinter.getUSBDeviceList();
        final results = usbDevices.map((d) {
          final manufacturer = d['manufacturer'] ?? 'USB';
          final productName = d['productName'] ?? 'Printer';
          final vendorId = d['vendorId'] is int ? d['vendorId'] : int.parse(d['vendorId'].toString());
          final productId = d['productId'] is int ? d['productId'] : int.parse(d['productId'].toString());
          return BluetoothInfo(
            name: '$manufacturer $productName',
            macAdress: 'USB_${vendorId}_$productId',
          );
        }).toList();
        state = state.copyWith(isScanning: false, devices: results);
        return;
      }

      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      final bool permission =
          await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (!permission) {
        state = state.copyWith(isScanning: false);
        return;
      }

      final List<BluetoothInfo> results =
          await PrintBluetoothThermal.pairedBluetooths;
          
      final savedMac = ref.read(settingsProvider).savedPrinterMacAddress;
      
      results.sort((a, b) {
        if (a.macAdress == savedMac && b.macAdress != savedMac) return -1;
        if (b.macAdress == savedMac && a.macAdress != savedMac) return 1;
        
        final aName = a.name.toLowerCase();
        final bName = b.name.toLowerCase();
        final isAPrinter = aName.contains('print') || aName.contains('pos') || aName.contains('thermal') || aName.contains('pt') || aName.contains('mp');
        final isBPrinter = bName.contains('print') || bName.contains('pos') || bName.contains('thermal') || bName.contains('pt') || bName.contains('mp');
        
        if (isAPrinter && !isBPrinter) return -1;
        if (isBPrinter && !isAPrinter) return 1;
        
        return a.name.compareTo(b.name);
      });

      state = state.copyWith(isScanning: false, devices: results);
    } catch (e) {
      state = state.copyWith(isScanning: false);
      if (kDebugMode) {
        debugPrint("Scan error: $e");
      }
    }
  }

  Future<bool> connectToPrinter(BluetoothInfo printer) async {
    try {
      if (kIsWeb) {
        state = state.copyWith(connectedDevice: printer);
        ref
            .read(settingsProvider.notifier)
            .updateSettings(savedPrinterMacAddress: printer.macAdress);
        return true;
      }
      if (defaultTargetPlatform == TargetPlatform.windows) {
        state = state.copyWith(connectedDevice: printer);
        ref
            .read(settingsProvider.notifier)
            .updateSettings(savedPrinterMacAddress: printer.macAdress);
        return true;
      }

      final bool result = await PrintBluetoothThermal.connect(
        macPrinterAddress: printer.macAdress);
      if (result) {
        state = state.copyWith(connectedDevice: printer);
        ref
            .read(settingsProvider.notifier)
            .updateSettings(savedPrinterMacAddress: printer.macAdress);
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Connection error: $e");
      }
    }
    return false;
  }

  Future<void> disconnectFromPrinter() async {
    try {
      if (defaultTargetPlatform != TargetPlatform.windows) {
        await PrintBluetoothThermal.disconnect;
      }
      _isUsbConnected = false;
      state = state.copyWith(clearConnectedDevice: true);
      ref
          .read(settingsProvider.notifier)
          .updateSettings(savedPrinterMacAddress: '');
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Disconnect error: $e");
      }
    }
  }

  Future<bool> autoConnect() async {
    final settings = ref.read(settingsProvider);
    final connectionType = settings.printerConnectionType;
    
    if (kIsWeb) {
      final savedMac = settings.savedPrinterMacAddress;
      final savedIp = settings.savedPrinterIpAddress;
      if (connectionType == 'Network' && savedIp != null && savedIp.isNotEmpty) {
        state = state.copyWith(
            connectedDevice: BluetoothInfo(name: 'Network Printer ($savedIp)', macAdress: savedIp));
        return true;
      } else if (savedMac != null && savedMac.isNotEmpty) {
        state = state.copyWith(
            connectedDevice: BluetoothInfo(name: savedMac, macAdress: savedMac));
        return true;
      }
      return false;
    }

    if (defaultTargetPlatform == TargetPlatform.windows) {
      final savedMac = settings.savedPrinterMacAddress;
      if (savedMac != null && savedMac.isNotEmpty) {
        state = state.copyWith(
            connectedDevice:
                BluetoothInfo(name: savedMac, macAdress: savedMac));
        return true;
      }
      return false;
    }

    if (connectionType == 'Network') {
      final ip = settings.savedPrinterIpAddress;
      if (ip == null || ip.isEmpty) return false;
      try {
        final socket = await Socket.connect(ip, 9100, timeout: const Duration(seconds: 2));
        socket.destroy();
        state = state.copyWith(
          connectedDevice: BluetoothInfo(name: 'Network Printer ($ip)', macAdress: ip));
        return true;
      } catch (e) {
        return false;
      }
    } else if (connectionType == 'USB') {
      try {
        final flutterUsbPrinter = FlutterUsbPrinter();
        final devices = await FlutterUsbPrinter.getUSBDeviceList();
        if (devices.isNotEmpty) {
          int? targetVendorId;
          int? targetProductId;
          final savedMac = settings.savedPrinterMacAddress;
          if (savedMac != null && savedMac.startsWith('USB_')) {
            final parts = savedMac.split('_');
            if (parts.length >= 3) {
              targetVendorId = int.tryParse(parts[1]);
              targetProductId = int.tryParse(parts[2]);
            }
          }

          Map<dynamic, dynamic>? device;
          if (targetVendorId != null && targetProductId != null) {
            for (final d in devices) {
              final int vId = d['vendorId'] is int ? d['vendorId'] as int : int.parse(d['vendorId']!.toString());
              final int pId = d['productId'] is int ? d['productId'] as int : int.parse(d['productId']!.toString());
              if (vId == targetVendorId && pId == targetProductId) {
                device = d;
                break;
              }
            }
          }

          if (device == null) {
            for (final d in devices) {
              final manufacturer = (d['manufacturer'] ?? '').toString().toLowerCase();
              final productName = (d['productName'] ?? '').toString().toLowerCase();
              if (manufacturer.contains('print') || manufacturer.contains('pos') || manufacturer.contains('thermal') ||
                  productName.contains('print') || productName.contains('pos') || productName.contains('thermal')) {
                device = d;
                break;
              }
            }
          }

          device ??= devices.first;

          final int vendorId = device['vendorId'] is int ? device['vendorId'] as int : int.parse(device['vendorId']!.toString());
          final int productId = device['productId'] is int ? device['productId'] as int : int.parse(device['productId']!.toString());
          final connected = await flutterUsbPrinter.connect(vendorId, productId);
          if (connected == true) {
            _isUsbConnected = true;
            state = state.copyWith(
              connectedDevice: BluetoothInfo(
                  name: 'USB Printer (${device['manufacturer'] ?? 'Unknown'})',
                  macAdress: 'USB_${vendorId}_$productId'));
            if (settings.savedPrinterMacAddress != 'USB_${vendorId}_$productId') {
              ref.read(settingsProvider.notifier).updateSettings(savedPrinterMacAddress: 'USB_${vendorId}_$productId');
            }
            return true;
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint("USB Auto-connect error: $e");
      }
      return false;
    }

    final savedMac = settings.savedPrinterMacAddress;

    if (savedMac == null || savedMac.isEmpty) return false;

    try {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      final bool permission =
          await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (!permission) return false;

      bool result = false;
      int retries = 3;

      while (retries > 0 && !result) {
        result = await PrintBluetoothThermal.connect(
          macPrinterAddress: savedMac);
        if (!result) {
          retries--;
          if (retries > 0) {
            await Future.delayed(const Duration(milliseconds: 1000));
          }
        }
      }

      if (result) {
        state = state.copyWith(
          connectedDevice: BluetoothInfo(
            name: 'Saved Printer',
            macAdress: savedMac));
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Auto-connect error: $e");
      }
    }
    return false;
  }

  Future<bool> checkConnection() async {
    if (kIsWeb) {
      return state.connectedDevice != null;
    }

    if (defaultTargetPlatform == TargetPlatform.windows) {
      return state.connectedDevice != null;
    }

    final settings = ref.read(settingsProvider);
    final connectionType = settings.printerConnectionType;

    if (connectionType == 'Network') {
      final ip = settings.savedPrinterIpAddress;
      if (ip == null || ip.isEmpty) return false;
      try {
        final socket = await Socket.connect(ip, 9100, timeout: const Duration(seconds: 1));
        socket.destroy();
        return true;
      } catch (_) {
        state = state.copyWith(clearConnectedDevice: true);
        return false;
      }
    } else if (connectionType == 'USB') {
      if (!_isUsbConnected) return false;
      return state.connectedDevice?.macAdress.startsWith('USB') ?? false;
    }

    try {
      final bool permission =
          await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (!permission) return false;

      final bool isConnected = await PrintBluetoothThermal.connectionStatus
          .timeout(const Duration(seconds: 2));
      if (!isConnected && state.connectedDevice != null) {
        state = state.copyWith(clearConnectedDevice: true);
      }
      return isConnected;
    } catch (e) {
      return false;
    }
  }

  Future<void> printReceipt(List<int> bytes) async {
    final settings = ref.read(settingsProvider);

    if (kIsWeb) {
      debugPrint('Web Print Receipt Mock: printed ${bytes.length} bytes.');
      return;
    }

    // Windows Printing Bypass (Uses printing package + PDF bytes)
    if (defaultTargetPlatform == TargetPlatform.windows) {
      bool isPdf = bytes.length > 4 && bytes[0] == 37 && bytes[1] == 80 && bytes[2] == 68 && bytes[3] == 70;
      if (isPdf) {
        final savedPrinterName = settings.savedPrinterMacAddress;
        if (savedPrinterName != null && savedPrinterName.isNotEmpty) {
          final printers = await Printing.listPrinters();
          final targetPrinter = printers.firstWhere(
            (p) => p.url == savedPrinterName || p.name == savedPrinterName,
            orElse: () => printers.first,
          );
          
          if (!targetPrinter.isAvailable) {
            throw Exception('Printer "${targetPrinter.name}" is offline or out of paper. Print job skipped to prevent queue buildup.');
          }

          await Printing.directPrintPdf(
            printer: targetPrinter,
            onLayout: (format) async => Uint8List.fromList(bytes),
          );
        } else {
          // Fallback to system picker if no printer selected
          await Printing.layoutPdf(
            onLayout: (format) async => Uint8List.fromList(bytes),
          );
        }
      } else {
        throw Exception('On Windows, the receipt must be generated as a PDF image.');
      }
      return;
    }

    final connectionType = settings.printerConnectionType;

    try {
      if (connectionType == 'Network') {
        final ip = settings.savedPrinterIpAddress;
        if (ip == null || ip.isEmpty) throw Exception('No IP address configured');
        final socket = await Socket.connect(ip, 9100, timeout: const Duration(milliseconds: 1500));
        socket.add(bytes);
        await socket.flush();
        await socket.close();
      } else if (connectionType == 'USB') {
        final flutterUsbPrinter = FlutterUsbPrinter();
        
        Future<void> performWrite() async {
          await flutterUsbPrinter.write(Uint8List.fromList(bytes));
          _isUsbConnected = true;
        }

        // Extremely fast printing: if we are marked as connected, write immediately without reconnecting!
        if (_isUsbConnected) {
          try {
            await performWrite();
            return;
          } catch (writeErr) {
            // Write failed on cached connection, try to reconnect below
            _isUsbConnected = false;
            if (kDebugMode) debugPrint("Cached USB write failed: $writeErr. Retrying connection...");
          }
        }

        try {
          // Slow reconnect path: only runs if cached connection was false or write failed
          final devices = await FlutterUsbPrinter.getUSBDeviceList();
          if (devices.isEmpty) throw Exception('No USB printers found');
          
          int? targetVendorId;
          int? targetProductId;
          final savedMac = settings.savedPrinterMacAddress;
          if (savedMac != null && savedMac.startsWith('USB_')) {
            final parts = savedMac.split('_');
            if (parts.length >= 3) {
              targetVendorId = int.tryParse(parts[1]);
              targetProductId = int.tryParse(parts[2]);
            }
          }

          Map<dynamic, dynamic>? device;
          if (targetVendorId != null && targetProductId != null) {
            for (final d in devices) {
              final int vId = d['vendorId'] is int ? d['vendorId'] as int : int.parse(d['vendorId']!.toString());
              final int pId = d['productId'] is int ? d['productId'] as int : int.parse(d['productId']!.toString());
              if (vId == targetVendorId && pId == targetProductId) {
                device = d;
                break;
              }
            }
          }

          if (device == null) {
            for (final d in devices) {
              final manufacturer = (d['manufacturer'] ?? '').toString().toLowerCase();
              final productName = (d['productName'] ?? '').toString().toLowerCase();
              if (manufacturer.contains('print') || manufacturer.contains('pos') || manufacturer.contains('thermal') ||
                  productName.contains('print') || productName.contains('pos') || productName.contains('thermal')) {
                device = d;
                break;
              }
            }
          }

          device ??= devices.first;
          
          final int vendorId = device['vendorId'] is int ? device['vendorId'] as int : int.parse(device['vendorId']!.toString());
          final int productId = device['productId'] is int ? device['productId'] as int : int.parse(device['productId']!.toString());
          bool? connected = await flutterUsbPrinter.connect(vendorId, productId);
          if (connected != true) throw Exception('Failed to connect to USB printer');
          
          await Future.delayed(const Duration(milliseconds: 500)); // Give USB hardware time to initialize
          await performWrite();
        } catch (connectErr) {
          _isUsbConnected = false;
          throw Exception('USB printing failed: $connectErr');
        }
      } else {
        // Bluetooth
        Future<void> performBtWrite() async {
          final bool result = await PrintBluetoothThermal.writeBytes(bytes);
          if (!result) throw Exception('Failed to send data to the bluetooth printer.');
        }

        try {
          bool connected = await PrintBluetoothThermal.connectionStatus;
          if (!connected) {
            connected = await autoConnect();
            if (!connected) throw Exception('Bluetooth printer not connected');
          }
          await performBtWrite();
        } catch (writeErr) {
          try {
            await PrintBluetoothThermal.disconnect;
            await Future.delayed(const Duration(milliseconds: 1000));
            bool reconnected = await autoConnect();
            if (reconnected) {
              await performBtWrite();
            } else {
              throw writeErr;
            }
          } catch (_) {
            throw writeErr;
          }
        }
      }
    } catch (e) {
      throw Exception('Printing failed: $e');
    }
  }
}

final printerProvider = NotifierProvider<PrinterNotifier, PrinterState>(() {
  return PrinterNotifier();
});
