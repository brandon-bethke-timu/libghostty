import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';

void main() {
  final terminal = Terminal(cols: 40, rows: 5);
  terminal.write(Uint8List.fromList('Hello, World!'.codeUnits));

  for (var col = 0; col < 13; col++) {
    final ref = terminal.gridRefAt(col: col, row: 0);
    print('($col, 0): "${ref.content}"');
    ref.dispose();
  }

  terminal.dispose();
}
