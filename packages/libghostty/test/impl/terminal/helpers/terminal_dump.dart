import 'package:libghostty/libghostty.dart';

class TerminalDump {
  static List<String> screenContent(Terminal terminal) {
    terminal.renderState.update();
    final lines = <String>[];
    while (terminal.renderState.nextRow()) {
      final buffer = StringBuffer();
      while (terminal.renderState.nextCell()) {
        buffer.write(terminal.renderState.cell.content);
      }
      lines.add(buffer.toString());
    }
    return lines;
  }

  static List<String> nonEmptyContent(Terminal terminal) {
    return screenContent(
      terminal,
    ).map((line) => line.trimRight()).where((line) => line.isNotEmpty).toList();
  }

  static bool hasContentOverlap(Terminal terminal) {
    final lines = nonEmptyContent(terminal);
    return lines.length != lines.toSet().length;
  }
}
