import '../bindings/bindings.dart';
import '../color.dart';
import '../enums/underline_style.dart';
import 'cell.dart';
import 'line.dart';

CellStyle _styleFromFlags(int flags, int underlineStyle) {
  if (flags == 0 && underlineStyle == 0) return const CellStyle();

  return CellStyle(
    bold: flags & CellFlags.bold != 0,
    italic: flags & CellFlags.italic != 0,
    faint: flags & CellFlags.faint != 0,
    strikethrough: flags & CellFlags.strikethrough != 0,
    blink: flags & CellFlags.blink != 0,
    inverse: flags & CellFlags.inverse != 0,
    invisible: flags & CellFlags.invisible != 0,
    overline: flags & CellFlags.overline != 0,
    underline: UnderlineStyleNative.fromNative(underlineStyle),
  );
}

/// Live view of a terminal screen buffer.
///
/// ```dart
/// for (var row = 0; row < screen.rows; row++) {
///   for (var col = 0; col < screen.cols; col++) {
///     final cell = screen.cellAt(row, col);
///   }
/// }
/// ```
abstract class Screen {
  /// Number of columns in the terminal grid.
  int get cols;

  /// Dirty state from the most recent render state update.
  DirtyState get dirtyState;

  /// Number of rows in the terminal grid.
  int get rows;

  /// Returns the cell at the given [row] and [col], or [Cell.empty] if
  /// out of bounds.
  Cell cellAt(int row, int col);

  /// Whether [row] has changed since the last render state update.
  bool isRowDirty(int row);

  /// Whether [row] soft-wraps into the next row.
  bool isRowWrapped(int row);

  /// Returns all cells in [row] as a [Line].
  Line lineAt(int row);
}

/// [Screen] backed by the terminal's render state via the bindings
/// abstraction layer. Used on both native and WASM platforms.
///
/// Lazily fetches the viewport grid on first access and caches lines
/// until [invalidate] is called.
class BindingsScreen implements Screen {
  final int _handle;
  final RgbColor _defaultFg;
  final RgbColor _defaultBg;

  var _cachedCols = 0;
  var _cachedRows = 0;
  var _dirtyState = DirtyState.clean;
  RawCells? _cells;
  List<Line?>? _cachedLines;

  BindingsScreen(
    this._handle, {
    required RgbColor defaultFg,
    required RgbColor defaultBg,
  }) : _defaultFg = defaultFg,
       _defaultBg = defaultBg;

  @override
  int get cols => _cells != null ? _cachedCols : _freshCols();

  @override
  DirtyState get dirtyState => _dirtyState;

  set dirtyState(DirtyState value) => _dirtyState = value;

  @override
  int get rows => _cells != null ? _cachedRows : _freshRows();

  @override
  Cell cellAt(int row, int col) {
    _ensureViewport();

    if (_cachedLines case final lines? when row >= 0 && row < _cachedRows) {
      final cached = lines[row];
      if (cached != null) return cached.cellAt(col);
    }

    final idx = row * _cachedCols + col;
    if (idx < 0 || idx >= _cells!.length) return Cell.empty;

    return _resolveCell(idx, row, col);
  }

  void invalidate() {
    _cells = null;
    _cachedLines = null;
  }

  @override
  bool isRowDirty(int row) => bindings.renderStateIsRowDirty(_handle, row);

  @override
  bool isRowWrapped(int row) => bindings.renderStateIsRowWrapped(_handle, row);

  @override
  Line lineAt(int row) {
    _ensureViewport();

    if (row < 0 || row >= _cachedRows) return const Line([]);

    final lines = _cachedLines ??= List<Line?>.filled(_cachedRows, null);
    final cached = lines[row];
    if (cached != null) return cached;

    final start = row * _cachedCols;
    if (start >= _cells!.length) return const Line([]);

    final end = start + _cachedCols;
    final line = Line([
      for (var i = start; i < end && i < _cells!.length; i++)
        _resolveCell(i, row, i - start),
    ]);

    lines[row] = line;
    return line;
  }

  void _ensureViewport() {
    if (_cells != null) return;

    _cachedCols = _freshCols();
    _cachedRows = _freshRows();
    _cells = bindings.renderStateGetViewport(_handle, _cachedCols, _cachedRows);
  }

  int _freshCols() => bindings.renderStateGetCols(_handle);

  int _freshRows() => bindings.renderStateGetRows(_handle);

  Cell _resolveCell(int index, int row, int col) {
    String? hyperlink;
    String? contentOverride;

    final cells = _cells!;
    if (cells.graphemeLen(index) > 0) {
      final codepoints = bindings.renderStateGetGrapheme(_handle, row, col);
      if (codepoints.isNotEmpty) contentOverride = .fromCharCodes(codepoints);
    }

    if (cells.hasHyperlink(index) != 0) {
      hyperlink = bindings.renderStateGetHyperlink(_handle, row, col);
    }

    return cells.cellAt(
      index,
      hyperlink: hyperlink,
      defaultFg: _defaultFg,
      defaultBg: _defaultBg,
      contentOverride: contentOverride,
    );
  }
}

/// Result of [Terminal]'s render state update.
enum DirtyState {
  /// Nothing changed since the last update.
  clean,

  /// Some rows changed — check [Screen.isRowDirty] per row.
  partial,

  /// Everything changed — skip per-row checks, rebuild all rows.
  full;

  factory DirtyState.fromNative(int value) => switch (value) {
    0 => DirtyState.clean,
    1 => DirtyState.partial,
    _ => DirtyState.full,
  };
}

extension RawCellsExtension on RawCells {
  Cell cellAt(
    int index, {
    required RgbColor defaultFg,
    required RgbColor defaultBg,
    String? contentOverride,
    String? hyperlink,
  }) {
    final cp = codepoint(index);
    if (cp == 0) return Cell.empty;

    final fr = fgR(index);
    final fg = fgG(index);
    final fb = fgB(index);
    final br = bgR(index);
    final bg = bgG(index);
    final bb = bgB(index);

    final fgColor = fr == defaultFg.r && fg == defaultFg.g && fb == defaultFg.b
        ? const DefaultColor()
        : RgbColor(fr, fg, fb);
    final bgColor = br == defaultBg.r && bg == defaultBg.g && bb == defaultBg.b
        ? const DefaultColor()
        : RgbColor(br, bg, bb);

    final CellColor? ulColor = ulSet(index) != 0
        ? RgbColor(ulR(index), ulG(index), ulB(index))
        : null;

    return Cell(
      content: contentOverride ?? String.fromCharCode(cp),
      foreground: fgColor,
      background: bgColor,
      underlineColor: ulColor,
      hyperlink: hyperlink,
      wide: CellWidthNative.fromNative(wide(index)),
      style: _styleFromFlags(flags(index), underlineStyle(index)),
      semanticContent: SemanticContentNative.fromNative(semanticContent(index)),
    );
  }
}
