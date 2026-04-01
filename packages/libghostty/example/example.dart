import 'dart:convert';
import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';

void main() {
  final terminal = Terminal(cols: 80, rows: 24);

  // Register effect callbacks (invoked synchronously during write).
  terminal.onWritePty = (data) => print('PTY: ${data.length} bytes');
  terminal.onBell = () => print('Bell!');
  terminal.onTitleChanged = () => print('Title: ${terminal.title}');

  // Write styled text and a title change.
  terminal.write(
    Uint8List.fromList(
      '\x1b]2;My Terminal\x07\x1b[1;34mHello\x1b[0m, World!\r\n'.codeUnits,
    ),
  );

  // Read screen content via render state.
  terminal.renderState.update();
  while (terminal.renderState.nextRow()) {
    final buf = StringBuffer();
    while (terminal.renderState.nextCell()) {
      if (terminal.renderState.cell.hasText) {
        buf.write(terminal.renderState.cell.content);
      }
    }
    final line = buf.toString().trimRight();
    if (line.isNotEmpty) print(line);
  }
  terminal.renderState.markClean();

  // Encode a Ctrl+C key press.
  final event = KeyEvent()
    ..mods = const .ctrl()
    ..action = .press
    ..key = .c;
  final seq = terminal.keyEncoder.encode(event);
  if (seq.isNotEmpty) print('Key sequence: ${utf8.encode(seq)}');
  event.dispose();

  terminal.dispose();
}
