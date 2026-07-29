import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    var content = file.readAsStringSync();
    var original = content;
    
    // Fix any double commas with whitespace/newlines between them
    content = content.replaceAll(RegExp(r',\s*,'), ',');
    
    // Specific fixes
    if (file.path.contains('master_admin_screen.dart')) {
      content = content.replaceAll('format(newDate)', 'format(finalDateTime)');
    }
    if (file.path.contains('global_inventory_screen.dart')) {
      content = content.replaceAll('displayedProducts.length', 'filteredItems.length');
      content = content.replaceAll('displayedProducts[index]', 'filteredItems[index]');
    }
    if (file.path.contains('settings_screen.dart')) {
      content = content.replaceAll('UserRole.host_admin', 'UserRole.hostAdmin');
    }
    if (file.path.contains('printer_service.dart')) {
      content = content.replaceAll('item.product.tamilName', 'item.product.name'); // Revert or fix tamilName error
    }
    if (file.path.contains('register_screen.dart')) {
      content = content.replaceAll('_keyGenerated ? _submitAdminRegister : null', '_keyGenerated ? () => _submitAdminRegister() : null');
    }

    if (content != original) {
      file.writeAsStringSync(content);
      print('Fixed ${file.path}');
    }
  }
}
