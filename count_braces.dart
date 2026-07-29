import 'dart:io';

void main() {
  final content = File('lib/presentation/auth/register_screen.dart').readAsStringSync();
  int depth = 0;
  var lines = content.split('\n');
  for (int i = 0; i < lines.length; i++) {
    for (int j = 0; j < lines[i].length; j++) {
      if (lines[i][j] == '{') depth++;
      if (lines[i][j] == '}') {
        depth--;
        if (depth == 0) {
          print('Class or top-level block closed at line ${i + 1}');
        }
        if (depth < 0) {
          print('Unmatched } at line ${i + 1}');
          return;
        }
      }
    }
  }
  print('Final depth: $depth');
}
