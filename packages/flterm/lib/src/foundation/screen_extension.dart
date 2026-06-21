import 'package:libghostty/libghostty.dart'
    show CellIterator, CellWidth, GridRef, RenderState, RowIterator, Terminal;

final _defaultWordPattern = RegExp(r'\w');

/// Selection and word-boundary helpers for [Terminal].
///
/// Provides hit-testing and text navigation operations used by the gesture
/// detector to resolve click positions into selection ranges. All methods
/// operate on the terminal's current viewport and handle wide characters
/// and row wrapping transparently.
///
/// ```dart
/// final terminal = Terminal(rows: 24, cols: 80);
/// final (start, end) = terminal.wordBoundaryAt(5, 10);
/// ```
extension TerminalScreenExtension on Terminal {
  /// Returns the logical line boundaries for the given viewport [row].
  ///
  /// A logical line may span multiple viewport rows when soft-wrapped.
  /// Walks upward from [row] to find the first non-wrapped row, then
  /// downward to find the last row of the logical line.
  ///
  /// `endCol` is the column after the last non-empty cell on the final row,
  /// trimming trailing empty cells.
  ///
  /// Returns [row] clamped to the viewport when out of bounds.
  ({int startRow, int endRow, int endCol}) lineBoundaryAt(int row) {
    final rs = RenderState()..update(this);
    try {
      if (row < 0 || row >= rs.rows) {
        return (startRow: row, endRow: row, endCol: 0);
      }
      var start = row;
      while (start > 0) {
        final ref = GridRef.at(this, col: 0, row: start - 1);
        final wrap = ref.rowWrap;
        ref.dispose();
        if (!wrap) break;
        start--;
      }
      var end = row;
      while (end < rs.rows - 1) {
        final ref = GridRef.at(this, col: 0, row: end);
        final wrap = ref.rowWrap;
        ref.dispose();
        if (!wrap) break;
        end++;
      }
      var endCol = rs.cols;
      while (endCol > 0) {
        final ref = GridRef.at(this, col: endCol - 1, row: end);
        final hasContent = ref.graphemes.isNotEmpty;
        final isSpacer = ref.wide == CellWidth.spacerTail;
        ref.dispose();
        if (hasContent || isSpacer) break;
        endCol--;
      }
      return (startRow: start, endRow: end, endCol: endCol);
    } finally {
      rs.dispose();
    }
  }

  /// Snaps a column to a wide-character boundary.
  ///
  /// When [col] lands on the head of a wide character and [inclusive] is true,
  /// returns the head column. When [inclusive] is false, returns the column
  /// after the wide character (head + 2). When [col] lands on a spacer tail,
  /// returns the head column (inclusive) or the column after (exclusive).
  ///
  /// Returns [col] unchanged for single-width cells or out-of-bounds input.
  int snapColToWideBoundary(int row, int col, {required bool inclusive}) {
    final rs = RenderState()..update(this);
    try {
      if (row < 0 || row >= rs.rows || col < 0 || col >= rs.cols) return col;
      final ref = GridRef.at(this, col: col, row: row);
      final w = ref.wide;
      final isW = ref.isWide;
      ref.dispose();
      if (isW) return inclusive ? col : col + 2;
      if (w == CellWidth.spacerTail) return inclusive ? col - 1 : col + 1;
      return col;
    } finally {
      rs.dispose();
    }
  }

  /// Adjusts selection start and end columns to respect wide-character
  /// boundaries.
  ///
  /// The leading edge (closer to text start) snaps inclusively so the
  /// full wide character is selected. The trailing edge snaps exclusively
  /// so it sits just past the wide character.
  (int startCol, int endCol) snapSelectionCols(
    int startRow,
    int startCol,
    int endRow,
    int endCol,
  ) {
    final startIsTop = startRow != endRow
        ? startRow < endRow
        : startCol <= endCol;

    if (startIsTop) {
      return (
        snapColToWideBoundary(startRow, startCol, inclusive: true),
        snapColToWideBoundary(endRow, endCol, inclusive: false),
      );
    }
    return (
      snapColToWideBoundary(startRow, startCol, inclusive: false),
      snapColToWideBoundary(endRow, endCol, inclusive: true),
    );
  }

  /// Returns the column range of the word at ([row], [col]).
  ///
  /// Expands outward from the clicked cell while adjacent cells match
  /// [wordPattern] (defaults to `\w`). Wide characters and spacer tails
  /// are traversed correctly. If the cell at [col] does not match the
  /// pattern, returns a single-cell (or double-cell for wide characters)
  /// range.
  ///
  /// Used by the gesture detector for double-click word selection.
  (int start, int end) wordBoundaryAt(
    int row,
    int col, {
    Pattern? wordPattern,
  }) {
    final isWord = wordPattern ?? _defaultWordPattern;
    final rs = RenderState()..update(this);
    final rows = RowIterator();
    final cells = CellIterator();
    try {
      if (row < 0 || row >= rs.rows) return (col, col + 1);

      final maxCol = rs.cols;
      if (col < 0 || col >= maxCol) return (col, col + 1);

      rows.reset(rs);
      for (var i = 0; i <= row; i++) {
        if (!rows.next()) return (col, col + 1);
      }
      cells.reset(rows);

      cells.select(col);
      final snapped = cells.wide == .spacerTail && col > 0 ? col - 1 : col;

      cells.select(snapped);
      final content = cells.content;
      if (content.isEmpty || isWord.matchAsPrefix(content) == null) {
        final span = cells.wide == .wide ? 2 : 1;
        return (snapped, snapped + span);
      }

      var start = snapped;
      while (start > 0) {
        cells.select(start - 1);
        if (cells.wide == .spacerTail) {
          start--;
          continue;
        }
        final content = cells.content;
        if (content.isEmpty || isWord.matchAsPrefix(content) == null) break;
        start--;
      }

      var end = snapped + 1;
      while (end < maxCol) {
        cells.select(end);
        if (cells.wide == .spacerTail) {
          end++;
          continue;
        }
        final content = cells.content;
        if (content.isEmpty || isWord.matchAsPrefix(content) == null) break;
        end++;
      }

      return (start, end);
    } finally {
      cells.dispose();
      rows.dispose();
      rs.dispose();
    }
  }
}
