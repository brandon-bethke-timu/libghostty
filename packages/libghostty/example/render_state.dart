import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';

void main() {
  final terminal = Terminal(cols: 40, rows: 5);

  terminal.write(
    Uint8List.fromList(
      'Hello, \x1b[1;32mworld\x1b[0m!\r\n'
              '\x1b[4munderlined\x1b[0m text\r\n'
              '\x1b[38;2;255;128;0morange\x1b[0m\r\n'
          .codeUnits,
    ),
  );

  terminal.renderState.update();

  switch (terminal.renderState.dirty) {
    case .clean:
      print('Frame is clean, nothing to draw.');
    case .partial:
      print('Partial redraw needed.');
    case .full:
      print('Full redraw needed.');
  }

  final colors = terminal.renderState.colors;
  final fg = colors.foreground;
  final bg = colors.background;
  print('Default fg: RGB(${fg.r}, ${fg.g}, ${fg.b})');
  print('Default bg: RGB(${bg.r}, ${bg.g}, ${bg.b})');
  print('Palette entries: ${colors.palette.length}');

  while (terminal.renderState.nextRow()) {
    if (!terminal.renderState.row.dirty) continue;

    final buf = StringBuffer();
    while (terminal.renderState.nextCell()) {
      final cell = terminal.renderState.cell;
      if (!cell.hasText) continue;
      buf.write(cell.content);
    }
    final text = buf.toString().trimRight();
    if (text.isNotEmpty) print('  $text');
  }

  terminal.renderState.markClean();
  print('After markClean: ${terminal.renderState.dirty}');

  terminal.dispose();
}
