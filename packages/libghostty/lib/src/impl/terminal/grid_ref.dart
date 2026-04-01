part of 'terminal.dart';

/// A resolved reference to a specific cell position in the terminal grid.
///
/// Obtain via [Terminal.gridRefAt]. Read cell data immediately and call
/// [dispose] when done. A grid reference is only valid until the next
/// operation on the terminal instance (including seemingly unrelated
/// operations), so cache any needed information right after creation.
///
/// Not intended for render loops. Use [RenderState] for
/// performance-critical rendering.
///
/// ```dart
/// final ref = terminal.gridRefAt(col: 0, row: 0);
/// print(ref.content);
/// print(ref.style);
/// ref.dispose();
/// ```
class GridRef {
  static final _finalizer = Finalizer<int>(bindings.gridRefFree);

  final int _handle;
  var _disposed = false;

  GridRef._(
    int terminalHandle, {
    required int col,
    required int row,
    PointTag pointTag = PointTag.active,
  }) : _handle = check(
         bindings.terminalGridRef(terminalHandle, pointTag, col, row),
       ) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// The raw cell handle at this position.
  int get cell => check(bindings.gridRefCell(_handle));

  /// The cell's full grapheme cluster as a string, or empty if the cell
  /// has no text.
  String get content {
    final codepoints = graphemes;
    return codepoints.isEmpty ? '' : String.fromCharCodes(codepoints);
  }

  /// The cell's grapheme cluster as a list of Unicode codepoints. The
  /// primary codepoint is first, followed by any combining codepoints.
  /// Empty if the cell has no text.
  List<int> get graphemes => check(bindings.gridRefGraphemes(_handle));

  /// Whether the cell is the first cell of a wide character.
  bool get isWide => wide == CellWidth.wide;

  /// The raw row handle at this position.
  int get row => check(bindings.gridRefRow(_handle));

  /// Whether this row is soft-wrapped to the next row.
  bool get rowWrap => check(bindings.rowGetWrap(row));

  /// The [Style] of the cell at this position.
  Style get style => check(bindings.gridRefStyle(_handle));

  /// The cell's width: [CellWidth.normal], [CellWidth.wide], or
  /// [CellWidth.spacerTail].
  CellWidth get wide => check(bindings.cellGetWide(cell));

  /// Releases this grid reference.
  ///
  /// The reference must not be used after this call. Safe to call multiple
  /// times; subsequent calls are no-ops.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _finalizer.detach(this);
    bindings.gridRefFree(_handle);
  }
}
