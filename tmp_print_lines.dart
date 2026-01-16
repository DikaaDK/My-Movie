import 'dart:io';

void main() {
  final lines = File('lib/pages/explore_page.dart').readAsLinesSync();
  for (var i = 280; i < 340 && i < lines.length; i++) {
    print('${i + 1}: ${lines[i]}');
  }
}
