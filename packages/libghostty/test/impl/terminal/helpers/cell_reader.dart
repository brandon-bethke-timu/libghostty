import 'package:libghostty/libghostty.dart';

class CellSnapshot {
  final String content;
  final bool hasText;
  final CellWidth wide;
  final Style style;
  final CellColor foreground;
  final CellColor background;
  final UnderlineStyle underlineStyle;
  final bool hasHyperlink;

  const CellSnapshot({
    this.content = '',
    this.hasText = false,
    this.wide = CellWidth.narrow,
    this.style = const Style(),
    this.foreground = const DefaultColor(),
    this.background = const DefaultColor(),
    this.underlineStyle = UnderlineStyle.none,
    this.hasHyperlink = false,
  });

  bool get isEmpty => !hasText;
}

CellSnapshot readCellAt(Terminal terminal, int row, int col) {
  terminal.renderState.update();
  var currentRow = 0;
  while (terminal.renderState.nextRow()) {
    if (currentRow == row) {
      var currentCol = 0;
      while (terminal.renderState.nextCell()) {
        if (currentCol == col) {
          final cell = terminal.renderState.cell;
          return CellSnapshot(
            content: cell.content,
            hasText: cell.hasText,
            wide: cell.wide,
            style: cell.style,
            foreground: cell.style.foreground,
            background: cell.style.background,
            underlineStyle: cell.style.underline,
            hasHyperlink: cell.hasHyperlink,
          );
        }
        currentCol++;
      }
    }
    currentRow++;
  }
  return const CellSnapshot();
}

bool isRowDirty(Terminal terminal, int row) {
  terminal.renderState.update();
  var i = 0;
  while (terminal.renderState.nextRow()) {
    if (i == row) return terminal.renderState.row.dirty;
    i++;
  }
  return false;
}

bool isRowWrapped(Terminal terminal, int row) {
  terminal.renderState.update();
  var i = 0;
  while (terminal.renderState.nextRow()) {
    if (i == row) return terminal.renderState.row.wrap;
    i++;
  }
  return false;
}

String readRowText(Terminal terminal, int row) {
  terminal.renderState.update();
  var currentRow = 0;
  while (terminal.renderState.nextRow()) {
    if (currentRow == row) {
      final buffer = StringBuffer();
      while (terminal.renderState.nextCell()) {
        buffer.write(terminal.renderState.cell.content);
      }
      return buffer.toString();
    }
    currentRow++;
  }
  return '';
}
