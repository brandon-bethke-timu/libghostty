import 'package:libghostty/libghostty.dart';

void main() {
  final terminal = Terminal(cols: 80, rows: 24);

  terminal.write(
    .fromList('\x1b[1;34mHello\x1b[0m, \x1b[32mWorld\x1b[0m!\r\n'.codeUnits),
  );

  terminal.renderState.update();
  while (terminal.renderState.nextRow()) {
    final buf = StringBuffer();
    while (terminal.renderState.nextCell()) {
      if (terminal.renderState.cell.hasText) {
        buf.write(terminal.renderState.cell.content);
      }
    }
    final text = buf.toString().trimRight();
    if (text.isNotEmpty) print('Row: $text');
  }

  terminal.dispose();
}
