import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    var content = file.readAsStringSync();
    var original = content;
    
    // Fix double commas before isError
    content = content.replaceAll(RegExp(r',\s*,\s*isError:'), ', isError:');
    
    // Fix trailing comma before closing paren
    content = content.replaceAll(RegExp(r',\s*\)'), ')');
    
    // Fix the specific truncation in master_admin_screen.dart
    content = content.replaceAll(
      r"NotificationHelper.showCenter(context, 'Validity extended to ${DateFormat('dd MMM yyyy', isError: false);",
      r"NotificationHelper.showCenter(context, 'Validity extended to ${DateFormat('dd MMM yyyy').format(newDate)}', isError: false);"
    );
    
    content = content.replaceAll(
      r"NotificationHelper.showCenter(context, 'Validity set to ${DateFormat('dd MMM yyyy, hh:mm a', isError: false);",
      r"NotificationHelper.showCenter(context, 'Validity set to ${DateFormat('dd MMM yyyy, hh:mm a').format(newDate)}', isError: false);"
    );

    // Fix refund_screen e.toString(,
    content = content.replaceAll(
      r"e.toString(, isError:",
      r"e.toString(), isError:"
    );

    if (content != original) {
      file.writeAsStringSync(content);
      print('Fixed ${file.path}');
    }
  }
}
