import 'package:pos/core/utils/notification_helper.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter_usb_printer/flutter_usb_printer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/printer_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'widgets/custom_printers_setup.dart';
import 'widgets/premium_selection_card.dart';
import 'widgets/premium_switch_card.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  late String _connectionType;
  int _previewItemCount = 3;
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _connectionType = settings.printerConnectionType;
    if (Platform.isWindows && _connectionType == 'USB') {
      _connectionType = 'Bluetooth';
    }
    _ipController.text = settings.savedPrinterIpAddress ?? '192.168.1.100';

    // Check connection and scan when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(printerProvider.notifier).checkConnection();
      ref.read(printerProvider.notifier).startScan();
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final printerState = ref.watch(printerProvider);
    final authState = ref.watch(authProvider);
    final settings = ref.watch(settingsProvider);
    final isStaff = authState?.role == UserRole.staff;

    final width = MediaQuery.of(context).size.width;
    final isWide =
        width >= 768 &&
        !kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    if (isWide) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: null,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button for Staff on Desktop
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0, right: 16.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.arrow_back, color: Color(0xFF475569)),
                      SizedBox(width: 8),
                      Text('Back to Dashboard', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Left Column: Hardware Connection & Device Selection
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDesktopCard(
                      title: 'Connection Type',
                      subtitle:
                          'Select how your thermal printer is connected to this device.',
                      icon: Icons.settings_input_hdmi,
                      iconColor: theme.colorScheme.primary,
                      child: Column(
                        children: [
                          if (Platform.isWindows) ...[
                            PremiumSelectionCard(
                              title: 'Windows System Printers',
                              subtitle:
                                  'Select any installed printer from Windows (USB, Bluetooth, Wi-Fi). Note: You must add the printer in Windows Settings first.',
                              icon: Icons.print,
                              isSelected: _connectionType == 'Bluetooth',
                              activeColor: Colors.blue,
                              onTap: () {
                                setState(() => _connectionType = 'Bluetooth');
                                ref
                                    .read(settingsProvider.notifier)
                                    .updateSettings(
                                      printerConnectionType: 'Bluetooth',
                                    );
                              },
                            ),
                            const SizedBox(height: 12),
                            PremiumSelectionCard(
                              title: 'Network / LAN (Wi-Fi)',
                              subtitle: 'Connect via local Network IP address.',
                              icon: Icons.wifi,
                              isSelected: _connectionType == 'Network',
                              activeColor: Colors.green,
                              onTap: () {
                                setState(() => _connectionType = 'Network');
                                ref
                                    .read(settingsProvider.notifier)
                                    .updateSettings(
                                      printerConnectionType: 'Network',
                                    );
                              },
                            ),
                          ] else ...[
                            PremiumSelectionCard(
                              title: 'Bluetooth (Wireless Classic/BLE)',
                              subtitle:
                                  'Connect to paired Bluetooth thermal receipt printers.',
                              icon: Icons.bluetooth,
                              isSelected: _connectionType == 'Bluetooth',
                              activeColor: Colors.blue,
                              onTap: () {
                                setState(() => _connectionType = 'Bluetooth');
                                ref
                                    .read(settingsProvider.notifier)
                                    .updateSettings(
                                      printerConnectionType: 'Bluetooth',
                                    );
                              },
                            ),
                            const SizedBox(height: 12),
                            PremiumSelectionCard(
                              title: 'USB / OTG Cable Connection',
                              subtitle:
                                  'Direct physical cable connection to USB printer.',
                              icon: Icons.usb,
                              isSelected: _connectionType == 'USB',
                              activeColor: Colors.orange,
                              onTap: () {
                                setState(() => _connectionType = 'USB');
                                ref
                                    .read(settingsProvider.notifier)
                                    .updateSettings(
                                      printerConnectionType: 'USB',
                                    );
                              },
                            ),
                            const SizedBox(height: 12),
                            PremiumSelectionCard(
                              title: 'Network / LAN (Wi-Fi)',
                              subtitle: 'Connect via local Network IP address.',
                              icon: Icons.wifi,
                              isSelected: _connectionType == 'Network',
                              activeColor: Colors.green,
                              onTap: () {
                                setState(() => _connectionType = 'Network');
                                ref
                                    .read(settingsProvider.notifier)
                                    .updateSettings(
                                      printerConnectionType: 'Network',
                                    );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildDesktopCard(
                      title: 'Device Selection',
                      subtitle: _connectionType == 'Network'
                          ? 'Enter printer IP address.'
                          : (_connectionType == 'Bluetooth'
                                ? 'Choose printer from scanned list.'
                                : 'Detect plugged in USB device.'),
                      icon: Icons.print_rounded,
                      iconColor: theme.colorScheme.secondary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_connectionType == 'Bluetooth') ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  Platform.isWindows
                                      ? 'Windows System Printers:'
                                      : 'Scanned Printers:',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: printerState.isScanning
                                      ? null
                                      : () => ref
                                            .read(printerProvider.notifier)
                                            .startScan(),
                                  icon: printerState.isScanning
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.refresh),
                                  label: Text(
                                    printerState.isScanning
                                        ? 'Scanning...'
                                        : 'Scan / Refresh',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (printerState.devices.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16.0,
                                ),
                                child: Center(
                                  child: Text(
                                    printerState.isScanning
                                        ? 'Searching for devices...'
                                        : (Platform.isWindows
                                              ? 'No system printers found. Add one in Windows Settings.'
                                              : 'No paired Bluetooth devices found.'),
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: printerState.devices.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final device = printerState.devices[index];
                                  final isConnected =
                                      printerState.connectedDevice?.macAdress ==
                                      device.macAdress;
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      device.name.isEmpty
                                          ? 'Unnamed Printer'
                                          : device.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(device.macAdress),
                                     trailing: IgnorePointer(
                                       child: isConnected
                                           ? ElevatedButton(
                                               style: ElevatedButton.styleFrom(
                                                 backgroundColor: Colors.green.shade100,
                                                 foregroundColor: Colors.green.shade800,
                                                 elevation: 0,
                                                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                 minimumSize: Size.zero,
                                                 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                 shape: RoundedRectangleBorder(
                                                   borderRadius: BorderRadius.circular(6),
                                                 ),
                                               ),
                                               onPressed: () {},
                                               child: const Text('CONNECTED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                             )
                                           : ElevatedButton(
                                               style: ElevatedButton.styleFrom(
                                                 backgroundColor: theme.colorScheme.primary,
                                                 foregroundColor: Colors.white,
                                                 elevation: 0,
                                                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                 minimumSize: Size.zero,
                                                 tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                 shape: RoundedRectangleBorder(
                                                   borderRadius: BorderRadius.circular(6),
                                                 ),
                                               ),
                                               onPressed: () {},
                                               child: const Text('CONNECT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                             ),
                                     ),
                                    onTap: () async {
                                      if (isConnected) {
                                        await ref
                                            .read(printerProvider.notifier)
                                            .disconnectFromPrinter();
                                        if (mounted) {
                                          NotificationHelper.showCenter(
                                            context,
                                            'Disconnected from ${device.name}',
                                            isError: false,
                                          );
                                        }
                                        return;
                                      }

                                      if (printerState.connectedDevice !=
                                              null &&
                                          !isConnected) {
                                        await ref
                                            .read(printerProvider.notifier)
                                            .disconnectFromPrinter();
                                      }

                                      final res = await ref
                                          .read(printerProvider.notifier)
                                          .connectToPrinter(device);
                                      if (mounted) {
                                        if (res) {
                                          NotificationHelper.showCenter(
                                            context,
                                            'Connected to ${device.name} successfully!',
                                            isError: false,
                                          );
                                        } else {
                                          NotificationHelper.showCenter(
                                            context,
                                            'Connection failed. Please ensure the printer is turned on and paired first.',
                                            isError: true,
                                          );
                                        }
                                      }
                                    },
                                  );
                                },
                              ),
                          ] else if (_connectionType == 'Network') ...[
                            TextField(
                              controller: _ipController,
                              decoration: const InputDecoration(
                                labelText: 'Printer Network IP Address',
                                hintText: '192.168.1.100',
                                prefixIcon: Icon(Icons.lan),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final ip = _ipController.text.trim();
                                if (ip.isEmpty) {
                                  NotificationHelper.showCenter(
                                    context,
                                    'Please enter a valid IP address',
                                    isError: true,
                                  );
                                  return;
                                }
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );

                                bool success = false;
                                String errorMsg = '';
                                try {
                                  final socket = await Socket.connect(
                                    ip,
                                    9100,
                                    timeout: const Duration(milliseconds: 1500),
                                  );
                                  socket.destroy();
                                  success = true;
                                } catch (e) {
                                  errorMsg = e.toString();
                                }

                                if (mounted) {
                                  Navigator.of(context).pop();
                                  if (success) {
                                    ref
                                        .read(settingsProvider.notifier)
                                        .updateSettings(
                                          savedPrinterIpAddress: ip,
                                          printerConnectionType: 'Network',
                                        );
                                    await ref
                                        .read(printerProvider.notifier)
                                        .autoConnect();
                                    NotificationHelper.showCenter(
                                      context,
                                      'Network Printer connected successfully!',
                                      isError: false,
                                    );
                                  } else {
                                    NotificationHelper.showCenter(
                                      context,
                                      'Failed to connect: $errorMsg',
                                      isError: true,
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.link),
                              label: const Text('Connect via IP & Save'),
                            ),
                          ] else ...[
                            const Text(
                              'Please ensure your printer is plugged in via USB/OTG and powered ON.',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );

                                List<Map<dynamic, dynamic>> devices = [];
                                String errorMsg = '';
                                bool success = false;
                                try {
                                  devices =
                                      await FlutterUsbPrinter.getUSBDeviceList();
                                  if (devices.isNotEmpty) {
                                    Map<dynamic, dynamic>? device;
                                    for (final d in devices) {
                                      final manufacturer =
                                          (d['manufacturer'] ?? '')
                                              .toString()
                                              .toLowerCase();
                                      final productName =
                                          (d['productName'] ?? '')
                                              .toString()
                                              .toLowerCase();
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
                                    device ??= devices.first;

                                    final flutterUsbPrinter =
                                        FlutterUsbPrinter();
                                    final int vendorId =
                                        device['vendorId'] is int
                                        ? device['vendorId'] as int
                                        : int.parse(
                                            device['vendorId']!.toString(),
                                          );
                                    final int productId =
                                        device['productId'] is int
                                        ? device['productId'] as int
                                        : int.parse(
                                            device['productId']!.toString(),
                                          );
                                    final connected = await flutterUsbPrinter
                                        .connect(vendorId, productId);
                                    if (connected == true) {
                                      success = true;
                                      ref
                                          .read(settingsProvider.notifier)
                                          .updateSettings(
                                            printerConnectionType: 'USB',
                                            savedPrinterMacAddress:
                                                'USB_${vendorId}_$productId',
                                          );
                                      await ref
                                          .read(printerProvider.notifier)
                                          .autoConnect();
                                    } else {
                                      errorMsg =
                                          'Failed to connect to USB device: ${device['manufacturer'] ?? 'Unknown'}';
                                    }
                                  } else {
                                    errorMsg =
                                        'No USB devices detected. Please check permissions and connections.';
                                  }
                                } catch (e) {
                                  errorMsg = e.toString();
                                }

                                if (mounted) {
                                  Navigator.of(context).pop();
                                  if (success) {
                                    NotificationHelper.showCenter(
                                      context,
                                      'USB Printer detected & connected successfully!',
                                      isError: false,
                                    );
                                  } else {
                                    NotificationHelper.showCenter(
                                      context,
                                      errorMsg,
                                      isError: true,
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.cable),
                              label: const Text('Detect USB Printer'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Right Column: Multiple Printers & Style settings
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDesktopCard(
                      title: 'Custom Printers',
                      subtitle: 'Setup multiple printers for dynamic routing.',
                      icon: Icons.print_outlined,
                      iconColor: theme.colorScheme.primary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PremiumSwitchCard(
                            title: 'Enable Multiple Custom Printers',
                            subtitle:
                                'Setup dynamic printers for different categories and routes.',
                            icon: Icons.print_outlined,
                            value: settings.enableMultiplePrinters,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (val) {
                              ref
                                  .read(settingsProvider.notifier)
                                  .updateSettings(enableMultiplePrinters: val);
                            },
                          ),
                          if (settings.enableMultiplePrinters) ...[
                            const SizedBox(height: 16),
                            const CustomPrintersSetupWidget(),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildDesktopCard(
                      title: 'Printing Style',
                      subtitle:
                          'Configure size and regional language layout options.',
                      icon: Icons.style_rounded,
                      iconColor: Colors.deepPurple,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PremiumSwitchCard(
                            title: 'Print as Image (Tamil Font Support)',
                            subtitle:
                                'Renders the receipt as an image for perfect regional fonts.',
                            icon: Icons.image,
                            value: settings.printAsImage,
                            activeColor: Colors.deepPurple,
                            onChanged: (val) {
                              ref
                                  .read(settingsProvider.notifier)
                                  .updateSettings(printAsImage: val);
                            },
                          ),
                          const SizedBox(height: 8),
                          PremiumSwitchCard(
                            title: 'Use 3-inch (80mm) Paper Size',
                            subtitle:
                                'Turn ON for larger 3-inch printers. Turn OFF for standard 2-inch.',
                            icon: Icons.aspect_ratio,
                            value: settings.is80mmPaper,
                            activeColor: Colors.deepPurple,
                            onChanged: (val) {
                              ref
                                  .read(settingsProvider.notifier)
                                  .updateSettings(is80mmPaper: val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey.shade50],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AppBar(
            title: const Text(
              'Printer Setup',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8),
            ),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.black87,
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
            automaticallyImplyLeading: Navigator.canPop(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PremiumSwitchCard(
                  title: 'Enable Multiple Custom Printers',
                  subtitle:
                      'Setup dynamic printers for different categories and routes (e.g., Kitchen, Bar).',
                  icon: Icons.print_outlined,
                  value: settings.enableMultiplePrinters,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) {
                    ref
                        .read(settingsProvider.notifier)
                        .updateSettings(enableMultiplePrinters: val);
                  },
                ),
                const SizedBox(height: 16),
                if (settings.enableMultiplePrinters) ...[
                  const CustomPrintersSetupWidget(),
                  const SizedBox(height: 20),
                ],
                Text(
                  settings.enableMultiplePrinters
                      ? 'Main Printer Setup'
                      : 'Printer Configuration',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.settings_input_hdmi,
                                color: theme.colorScheme.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Connection Type',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select how your thermal printer is connected to this device.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 20),
                        if (Platform.isWindows) ...[
                          PremiumSelectionCard(
                            title: 'Windows System Printers',
                            subtitle:
                                'Select any installed printer from Windows (USB, Bluetooth, Wi-Fi). Note: You must add the printer in Windows Settings first.',
                            icon: Icons.print,
                            isSelected: _connectionType == 'Bluetooth',
                            activeColor: Colors.blue,
                            onTap: () {
                              setState(() => _connectionType = 'Bluetooth');
                              ref
                                  .read(settingsProvider.notifier)
                                  .updateSettings(
                                    printerConnectionType: 'Bluetooth',
                                  );
                            },
                          ),
                          PremiumSelectionCard(
                            title: 'Network / LAN (Wi-Fi)',
                            subtitle: 'Connect via local Network IP address.',
                            icon: Icons.wifi,
                            isSelected: _connectionType == 'Network',
                            activeColor: Colors.green,
                            onTap: () {
                              setState(() => _connectionType = 'Network');
                              ref
                                  .read(settingsProvider.notifier)
                                  .updateSettings(
                                    printerConnectionType: 'Network',
                                  );
                            },
                          ),
                        ] else ...[
                          PremiumSelectionCard(
                            title: 'Bluetooth (Wireless Classic/BLE)',
                            subtitle:
                                'Connect to paired Bluetooth thermal receipt printers.',
                            icon: Icons.bluetooth,
                            isSelected: _connectionType == 'Bluetooth',
                            activeColor: Colors.blue,
                            onTap: () {
                              setState(() => _connectionType = 'Bluetooth');
                              ref
                                  .read(settingsProvider.notifier)
                                  .updateSettings(
                                    printerConnectionType: 'Bluetooth',
                                  );
                            },
                          ),
                          PremiumSelectionCard(
                            title: 'USB / OTG Cable Connection',
                            subtitle:
                                'Direct physical cable connection to USB printer.',
                            icon: Icons.usb,
                            isSelected: _connectionType == 'USB',
                            activeColor: Colors.orange,
                            onTap: () {
                              setState(() => _connectionType = 'USB');
                              ref
                                  .read(settingsProvider.notifier)
                                  .updateSettings(printerConnectionType: 'USB');
                            },
                          ),
                          PremiumSelectionCard(
                            title: 'Network / LAN (Wi-Fi)',
                            subtitle: 'Connect via local Network IP address.',
                            icon: Icons.wifi,
                            isSelected: _connectionType == 'Network',
                            activeColor: Colors.green,
                            onTap: () {
                              setState(() => _connectionType = 'Network');
                              ref
                                  .read(settingsProvider.notifier)
                                  .updateSettings(
                                    printerConnectionType: 'Network',
                                  );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary.withOpacity(
                                  0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.print_rounded,
                                color: theme.colorScheme.secondary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Device Selection',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_connectionType == 'Bluetooth') ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                Platform.isWindows
                                    ? 'Windows System Printers:'
                                    : 'Scanned Printers:',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: printerState.isScanning
                                    ? null
                                    : () => ref
                                          .read(printerProvider.notifier)
                                          .startScan(),
                                icon: printerState.isScanning
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh),
                                label: Text(
                                  printerState.isScanning
                                      ? 'Scanning...'
                                      : 'Scan / Refresh',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (printerState.devices.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16.0,
                              ),
                              child: Center(
                                child: Text(
                                  printerState.isScanning
                                      ? 'Searching for devices...'
                                      : (Platform.isWindows
                                            ? 'No system printers found. Add one in Windows Settings.'
                                            : 'No paired Bluetooth devices found.'),
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: printerState.devices.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final device = printerState.devices[index];
                                final isConnected =
                                    printerState.connectedDevice?.macAdress ==
                                    device.macAdress;
                                return ListTile(
                                  title: Text(
                                    device.name.isEmpty
                                        ? 'Unnamed Printer'
                                        : device.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(device.macAdress),
                                  trailing: IgnorePointer(
                                    child: isConnected
                                        ? ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green.shade100,
                                              foregroundColor: Colors.green.shade800,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                            ),
                                            onPressed: () {},
                                            child: const Text('CONNECTED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                          )
                                        : ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: theme.colorScheme.primary,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                            ),
                                            onPressed: () {},
                                            child: const Text('CONNECT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                          ),
                                  ),
                                  onTap: () async {
                                    if (isConnected) {
                                      await ref
                                          .read(printerProvider.notifier)
                                          .disconnectFromPrinter();
                                      if (mounted) {
                                        NotificationHelper.showCenter(
                                          context,
                                          'Disconnected from ${device.name}',
                                          isError: false,
                                        );
                                      }
                                      return;
                                    }

                                    if (printerState.connectedDevice != null &&
                                        !isConnected) {
                                      await ref
                                          .read(printerProvider.notifier)
                                          .disconnectFromPrinter();
                                    }

                                    final res = await ref
                                        .read(printerProvider.notifier)
                                        .connectToPrinter(device);
                                    if (mounted) {
                                      if (res) {
                                        NotificationHelper.showCenter(
                                          context,
                                          'Connected to ${device.name} successfully!',
                                          isError: false,
                                        );
                                      } else {
                                        NotificationHelper.showCenter(
                                          context,
                                          'Connection failed. Please ensure the printer is turned on and paired in Android settings first.',
                                          isError: true,
                                        );
                                      }
                                    }
                                  },
                                );
                              },
                            ),
                        ] else if (_connectionType == 'Network') ...[
                          TextField(
                            controller: _ipController,
                            decoration: const InputDecoration(
                              labelText: 'Printer Network IP Address',
                              hintText: '192.168.1.100',
                              prefixIcon: Icon(Icons.lan),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final ip = _ipController.text.trim();
                              if (ip.isEmpty) {
                                NotificationHelper.showCenter(
                                  context,
                                  'Please enter a valid IP address',
                                  isError: true,
                                );
                                return;
                              }
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );

                              bool success = false;
                              String errorMsg = '';
                              try {
                                final socket = await Socket.connect(
                                  ip,
                                  9100,
                                  timeout: const Duration(milliseconds: 1500),
                                );
                                socket.destroy();
                                success = true;
                              } catch (e) {
                                errorMsg = e.toString();
                              }

                              if (mounted) {
                                Navigator.of(context).pop();
                                if (success) {
                                  ref
                                      .read(settingsProvider.notifier)
                                      .updateSettings(
                                        savedPrinterIpAddress: ip,
                                        printerConnectionType: 'Network',
                                      );
                                  await ref
                                      .read(printerProvider.notifier)
                                      .autoConnect();
                                  NotificationHelper.showCenter(
                                    context,
                                    'Network Printer connected successfully!',
                                    isError: false,
                                  );
                                } else {
                                  NotificationHelper.showCenter(
                                    context,
                                    'Failed to connect: $errorMsg',
                                    isError: true,
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.link),
                            label: const Text('Connect via IP & Save'),
                          ),
                        ] else ...[
                          const Text(
                            'Please ensure your printer is plugged in via USB/OTG and powered ON.',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () async {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );

                              List<Map<dynamic, dynamic>> devices = [];
                              String errorMsg = '';
                              bool success = false;
                              try {
                                devices =
                                    await FlutterUsbPrinter.getUSBDeviceList();
                                if (devices.isNotEmpty) {
                                  Map<dynamic, dynamic>? device;
                                  // Look for printer-like devices first
                                  for (final d in devices) {
                                    final manufacturer =
                                        (d['manufacturer'] ?? '')
                                            .toString()
                                            .toLowerCase();
                                    final productName = (d['productName'] ?? '')
                                        .toString()
                                        .toLowerCase();
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
                                  // Fallback to first
                                  device ??= devices.first;

                                  final flutterUsbPrinter = FlutterUsbPrinter();
                                  final int vendorId = device['vendorId'] is int
                                      ? device['vendorId'] as int
                                      : int.parse(
                                          device['vendorId']!.toString(),
                                        );
                                  final int productId =
                                      device['productId'] is int
                                      ? device['productId'] as int
                                      : int.parse(
                                          device['productId']!.toString(),
                                        );
                                  final connected = await flutterUsbPrinter
                                      .connect(vendorId, productId);
                                  if (connected == true) {
                                    success = true;
                                    ref
                                        .read(settingsProvider.notifier)
                                        .updateSettings(
                                          printerConnectionType: 'USB',
                                          savedPrinterMacAddress:
                                              'USB_${vendorId}_$productId',
                                        );
                                    await ref
                                        .read(printerProvider.notifier)
                                        .autoConnect();
                                  } else {
                                    errorMsg =
                                        'Failed to connect to USB device: ${device['manufacturer'] ?? 'Unknown'}';
                                  }
                                } else {
                                  errorMsg =
                                      'No USB devices detected. Please check permissions and connections.';
                                }
                              } catch (e) {
                                errorMsg = e.toString();
                              }

                              if (mounted) {
                                Navigator.of(context).pop();
                                if (success) {
                                  NotificationHelper.showCenter(
                                    context,
                                    'USB Printer detected & connected successfully!',
                                    isError: false,
                                  );
                                } else {
                                  NotificationHelper.showCenter(
                                    context,
                                    errorMsg,
                                    isError: true,
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.cable),
                            label: const Text('Detect USB Printer'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Consumer(
                  builder: (context, ref, child) {
                    final settingsState = ref.watch(settingsProvider);
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.style_rounded,
                                    color: Colors.deepPurple,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Printing Style',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            PremiumSwitchCard(
                              title: 'Print as Image (Tamil Font Support)',
                              subtitle:
                                  'Renders the receipt as an image for perfect regional language fonts. Turn OFF for standard fast text printing.',
                              icon: Icons.image,
                              value: settingsState.printAsImage,
                              activeColor: Colors.deepPurple,
                              onChanged: (val) {
                                ref
                                    .read(settingsProvider.notifier)
                                    .updateSettings(printAsImage: val);
                              },
                            ),
                            PremiumSwitchCard(
                              title: 'Use 3-inch (80mm) Paper Size',
                              subtitle:
                                  'Turn ON for larger 3-inch (80mm) printers. Turn OFF for standard 2-inch (58mm) portable printers.',
                              icon: Icons.aspect_ratio,
                              value: settingsState.is80mmPaper,
                              activeColor: Colors.deepPurple,
                              onChanged: (val) {
                                ref
                                    .read(settingsProvider.notifier)
                                    .updateSettings(is80mmPaper: val);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Divider(color: Color(0xFFE2E8F0)),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
