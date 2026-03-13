import '../bindings/bindings.dart';
import '../color.dart';
import 'cell.dart';
import 'line.dart';
import 'screen.dart' show RawCellsExtension;

/// Readonly view of terminal scrollback history.
///
/// Only the primary screen has scrollback. On the alternate screen,
/// [length] is always zero.
abstract class Scrollback {
  /// Total number of scrollback rows available.
  int get length;

  /// Whether the row at [index] soft-wraps into the next row.
  bool isRowWrapped(int index);

  /// Returns all cells in the scrollback row at [index] as a [Line].
  ///
  /// Throws [RangeError] if [index] is out of bounds.
  Line lineAt(int index);

  /// Fetches [count] consecutive lines starting at [start].
  List<Line> linesInRange(int start, int count) {
    return [for (var i = 0; i < count; i++) lineAt(start + i)];
  }
}

/// [Scrollback] backed by the terminal's page list via the bindings
/// abstraction layer. Used on both native and WASM platforms.
class BindingsScrollback implements Scrollback {
  int cols;
  final int _handle;
  final RgbColor _defaultFg;
  final RgbColor _defaultBg;

  BindingsScrollback(
    this._handle, {
    required this.cols,
    required RgbColor defaultFg,
    required RgbColor defaultBg,
  }) : _defaultFg = defaultFg,
       _defaultBg = defaultBg;

  @override
  int get length {
    if (bindings.terminalIsAlternateScreen(_handle)) return 0;
    return bindings.terminalGetScrollbackLength(_handle);
  }

  @override
  bool isRowWrapped(int index) {
    return bindings.terminalIsScrollbackRowWrapped(_handle, index);
  }

  @override
  Line lineAt(int index) => _fetchLine(index, length, cols);

  @override
  List<Line> linesInRange(int start, int count) {
    if (count <= 0) return const [];

    final len = length;
    return [for (var i = 0; i < count; i++) _fetchLine(start + i, len, cols)];
  }

  Line _fetchLine(int index, int len, int cols) {
    if (index < 0 || index >= len) {
      throw RangeError.index(index, this, 'index', null, len);
    }

    final cells = bindings.terminalGetScrollbackLine(_handle, index, cols);
    if (cells == null) return const Line([]);

    return Line([
      for (var col = 0; col < cells.length; col++)
        _resolveCell(cells, col, index),
    ]);
  }

  Cell _resolveCell(RawCells cells, int index, int scrollbackOffset) {
    String? hyperlink;
    String? contentOverride;

    if (cells.graphemeLen(index) > 0) {
      final codepoints = bindings.terminalGetScrollbackGrapheme(
        _handle,
        scrollbackOffset,
        index,
      );
      if (codepoints.isNotEmpty) contentOverride = .fromCharCodes(codepoints);
    }

    if (cells.hasHyperlink(index) != 0) {
      hyperlink = bindings.terminalGetScrollbackHyperlink(
        _handle,
        scrollbackOffset,
        index,
      );
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
