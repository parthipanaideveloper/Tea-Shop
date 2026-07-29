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
          print('Depth 0 at line ${i + 1}');
        }
      }
    }
  }
}
