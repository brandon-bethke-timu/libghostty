part of 'terminal.dart';

/// A resolved reference to a specific cell position in the terminal grid.
///
/// Created via [GridRef.at]. Read cell data immediately and call [dispose]
/// when done. A grid reference is only valid until the next operation on
/// the terminal instance (including seemingly unrelated operations), so
/// cache any needed information right after creation.
///
/// Not intended for render loops. Use [RenderState] with [RowIterator] and
/// [CellIterator] for performance-critical rendering.
///
/// ```dart
/// final ref = GridRef.at(terminal, col: 0, row: 0);
/// print(ref.content);
/// print(ref.style);
/// ref.dispose();
/// ```
@immutable
final class GridRef {
  static final _finalizer = Finalizer<int>(bindings.gridRefFree);

  final int _handle;
  final Terminal _terminal;

  /// Resolves the grid cell at ([col], [row]) in the coordinate space
  /// identified by [pointTag].
  ///
  /// [PointTag.active] and [PointTag.viewport] are fast lookups;
  /// [PointTag.screen] and [PointTag.history] may be expensive for large
  /// scrollback buffers because they traverse the full scrollback page
  /// list.
  ///
  /// Throws [InvalidValueException] if the coordinates are out of range.
  factory GridRef.at(
    Terminal terminal, {
    required int col,
    required int row,
    PointTag pointTag = .active,
  }) => GridRef._(terminal, col: col, row: row, pointTag: pointTag);

  GridRef._(
    Terminal terminal, {
    required int col,
    required int row,
    PointTag pointTag = .active,
  }) : this._fromHandle(
         terminal,
         check(bindings.terminalGridRef(terminal._handle, pointTag, col, row)),
       );

  GridRef._fromHandle(this._terminal, this._handle) {
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

  /// The hyperlink URI at this position, or null if the cell has no
  /// hyperlink.
  String? get hyperlinkUri {
    final (code, uri) = bindings.gridRefHyperlinkUri(_handle);
    if (code == Result.noValue) return null;
    checkCode(code);
    return uri.isEmpty ? null : uri;
  }

  /// Whether the cell is the first cell of a wide character.
  bool get isWide => wide == CellWidth.wide;

  /// The raw row handle at this position.
  int get row => check(bindings.gridRefRow(_handle));

  /// Whether this row is soft-wrapped to the next row.
  bool get rowWrap => check(bindings.rowGetWrap(row));

  /// The [Style] of the cell at this position.
  Style get style => check(bindings.gridRefStyle(_handle));

  /// The cell's width: [CellWidth.narrow], [CellWidth.wide], or
  /// [CellWidth.spacerTail].
  CellWidth get wide => check(bindings.cellGetWide(cell));

  /// Releases the native grid reference handle.
  ///
  /// Must be called to free resources; the reference must not be used
  /// afterward.
  void dispose() {
    _finalizer.detach(this);
    bindings.gridRefFree(_handle);
  }

  /// Converts this grid reference to coordinates in the given coordinate
  /// space. Returns null if the reference falls outside the requested
  /// system (e.g. a scrollback row cannot be expressed in active
  /// coordinates).
  ({int col, int row})? pointIn(PointTag pointTag) {
    final (code, point) = bindings.terminalPointFromGridRef(
      _terminal._handle,
      _handle,
      pointTag,
    );
    if (code == Result.noValue) return null;
    checkCode(code);
    return point;
  }
}
