import 'package:pos/core/utils/notification_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/models/printer_profile.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../services/print_router_service.dart';

class CustomPrintersSetupWidget extends ConsumerStatefulWidget {
  const CustomPrintersSetupWidget({super.key});

  @override
  ConsumerState<CustomPrintersSetupWidget> createState() =>
      _CustomPrintersSetupWidgetState();
}

class _CustomPrintersSetupWidgetState
    extends ConsumerState<CustomPrintersSetupWidget> {
  void _openAddEditPrinterDialog({PrinterProfile? existing}) {
    showDialog(
      context: context,
      builder: (context) => _AddEditPrinterDialog(existing: existing));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final customPrinters = settings.customPrinters;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Custom KOT Printers',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: _openAddEditPrinterDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Printer')),
          ]),
        const SizedBox(height: 16),
        if (customPrinters.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300)),
            child: const Center(
              child: Text(
                'No custom printers added yet. Add one to route KOTs based on categories.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey))))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: customPrinters.length,
            itemBuilder: (context, index) {
              final p = customPrinters[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                  border: Border.all(color: Colors.grey.shade100)),
                child: Opacity(
                  opacity: p.isActive ? 1.0 : 0.5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Line 1: Name and Badge
                        Row(
                          children: [
                            Icon(
                              p.type == 'Bluetooth' ? Icons.bluetooth : (p.type == 'Network' ? Icons.wifi : Icons.usb),
                              color: theme.colorScheme.primary,
                              size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                p.name,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                            PrinterConnectionStatusBadge(printer: p),
                          ]),
                        const SizedBox(height: 8),
                        // Line 2: Actions
                        Row(
                          children: [
                            Switch(
                              value: p.isActive,
                              activeColor: theme.colorScheme.primary,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onChanged: (val) {
                                final newList = List<PrinterProfile>.from(settings.customPrinters);
                                final index = newList.indexWhere((e) => e.id == p.id);
                                if (index != -1) {
                                  newList[index] = p.copyWith(isActive: val);
                                  ref.read(settingsProvider.notifier).updateSettings(customPrinters: newList);
                                }
                              }),
                            const Text('Active', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            TextButton.icon(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Edit'),
                              onPressed: () => _openAddEditPrinterDialog(existing: p)),
                            TextButton.icon(
                              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                              label: const Text('Delete', style: TextStyle(color: Colors.red)),
                              onPressed: () {
                                final newList = List<PrinterProfile>.from(settings.customPrinters);
                                newList.removeWhere((e) => e.id == p.id);
                                ref.read(settingsProvider.notifier).updateSettings(customPrinters: newList);
                              }),
                          ]),
                        const SizedBox(height: 4),
                        // Line 3: Routing
                        if (p.categories.isNotEmpty)
                          Text(
                            'Routing: ${p.categories.join(", ")}',
                            style: TextStyle(color: theme.colorScheme.primary, fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)
                        else
                          Text(
                            'Routing: ALL (Fallback Printer)',
                            style: TextStyle(color: Colors.orange.shade700, fontSize: 13, fontWeight: FontWeight.w700)),
                      ]))));
            }),
      ]);
  }
}

class _AddEditPrinterDialog extends ConsumerStatefulWidget {
  final PrinterProfile? existing;

  const _AddEditPrinterDialog({this.existing});

  @override
  ConsumerState<_AddEditPrinterDialog> createState() =>
      _AddEditPrinterDialogState();
}

class _AddEditPrinterDialogState extends ConsumerState<_AddEditPrinterDialog> {
  final _nameController = TextEditingController();
  final _identifierController = TextEditingController();
  String _type = 'Network';
  List<String> _selectedCategories = [];
  List<String> _availableCategories = [];
  bool _is80mmPaper = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameController.text = widget.existing!.name;
      _identifierController.text = widget.existing!.identifier;
      _type = widget.existing!.type;
      _selectedCategories = List.from(widget.existing!.categories);
      _is80mmPaper = widget.existing!.is80mmPaper;
    }

    // Extract unique categories from inventory
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final products = ref.read(inventoryProvider);
      final Set<String> cats = {};
      for (var p in products) {
        cats.add(p.category);
        if (p.additionalCategories != null) {
          cats.addAll(p.additionalCategories!);
        }
      }
      setState(() {
        _availableCategories = cats.toList()..sort();
      });
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    final identifier = _identifierController.text.trim();

    if (name.isEmpty || identifier.isEmpty) {
      NotificationHelper.showCenter(context, 'Please fill all required fields', isError: false);
      return;
    }

    final p = PrinterProfile(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: name,
      type: _type,
      identifier: identifier,
      categories: _selectedCategories,
      is80mmPaper: _is80mmPaper);

    final settings = ref.read(settingsProvider);
    final newList = List<PrinterProfile>.from(settings.customPrinters);

    if (widget.existing != null) {
      final idx = newList.indexWhere((e) => e.id == p.id);
      if (idx != -1) newList[idx] = p;
    } else {
      newList.add(p);
    }

    ref.read(settingsProvider.notifier).updateSettings(customPrinters: newList);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Printer' : 'Edit Printer'),
      content: SingleChildScrollView(
        child: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Printer Name (e.g., Kitchen 1)',
                  border: OutlineInputBorder())),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Connection Type',
                  border: OutlineInputBorder()),
                items: ['Network', 'Bluetooth', 'USB']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _type = val!;
                  });
                }),
              const SizedBox(height: 16),
              TextField(
                controller: _identifierController,
                decoration: InputDecoration(
                  labelText: _type == 'Network'
                      ? 'IP Address (e.g., 192.168.1.100)'
                      : (_type == 'Bluetooth'
                          ? 'Bluetooth Address / MAC (e.g., 00:11:22:33:44:55)'
                          : 'USB Device Path/Name'),
                  border: const OutlineInputBorder())),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Use 3-inch (80mm) Paper'),
                subtitle: const Text('Turn off for standard 2-inch (58mm) paper'),
                value: _is80mmPaper,
                onChanged: (val) {
                  setState(() {
                    _is80mmPaper = val;
                  });
                },
                contentPadding: EdgeInsets.zero),
              const SizedBox(height: 24),
              const Text(
                'Assigned Categories',
                style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Items from these categories will print on this KOT printer. If no categories are selected, it will print ALL parcel items as a global fallback.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              if (_availableCategories.isEmpty)
                const Text('No categories found in inventory.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableCategories.map((cat) {
                    final isSelected = _selectedCategories.contains(cat);
                    return FilterChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedCategories.add(cat);
                          } else {
                            _selectedCategories.remove(cat);
                          }
                        });
                      });
                  }).toList()),
            ]))),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save Printer')),
      ]);
  }
}

class PrinterConnectionStatusBadge extends ConsumerStatefulWidget {
  final PrinterProfile printer;

  const PrinterConnectionStatusBadge({super.key, required this.printer});

  @override
  ConsumerState<PrinterConnectionStatusBadge> createState() => _PrinterConnectionStatusBadgeState();
}

class _PrinterConnectionStatusBadgeState extends ConsumerState<PrinterConnectionStatusBadge> {
  bool _isLoading = false;
  bool? _isConnected;

  Future<void> _checkConnection() async {
    setState(() => _isLoading = true);
    final connected = await PrintRouterService.checkConnection(widget.printer);
    if (mounted) {
      setState(() {
        _isConnected = connected;
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.printer.isActive) {
      _checkConnection();
    }
  }

  @override
  void didUpdateWidget(covariant PrinterConnectionStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.printer.isActive != widget.printer.isActive ||
        oldWidget.printer.identifier != widget.printer.identifier) {
      if (widget.printer.isActive) {
        _checkConnection();
      } else {
        setState(() => _isConnected = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.printer.isActive) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _isLoading ? null : _checkConnection,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _isLoading
              ? Colors.grey.shade200
              : (_isConnected == true ? Colors.green.shade50 : Colors.red.shade50),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isLoading
                ? Colors.grey.shade400
                : (_isConnected == true ? Colors.green.shade200 : Colors.red.shade200))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(
                _isConnected == true ? Icons.check_circle : Icons.error,
                size: 14,
                color: _isConnected == true ? Colors.green : Colors.red),
            const SizedBox(width: 4),
            Text(
              _isLoading
                  ? 'Testing...'
                  : (_isConnected == true ? 'Connected' : 'Disconnected (Tap to retry)'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _isLoading
                    ? Colors.grey.shade700
                    : (_isConnected == true ? Colors.green.shade700 : Colors.red.shade700))),
          ])));
  }
}
