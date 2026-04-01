part of 'terminal.dart';

/// A single cell in the terminal grid during render state iteration.
///
/// Access via [RenderState.cell] after calling [RenderState.nextCell].
/// Properties reflect the cell at the current iterator position and
/// become invalid after the next [RenderState.update] call.
class Cell {
  final int _handle;
  var _rawCell = 0;
  var _graphemeLen = 0;
  var _styleId = -1;
  var _prevStyleId = -1;
  var _cachedStyle = const Style();

  Cell._(this._handle);

  /// Resolved background color, or null if the cell has no explicit
  /// background. Resolves palette indices through the active palette.
  /// When null, use the terminal's default background color.
  RgbColor? get background {
    final (code, rgb) = bindings.rowCellsGetBgColor(_handle);
    return code == .success ? rgb : null;
  }

  /// The cell's primary codepoint, or 0 if the cell has no text.
  int get codepoint {
    if (_graphemeLen == 0) return 0;
    return check(bindings.cellGetCodepoint(_rawCell));
  }

  /// The cell's full grapheme cluster as a string, or empty if the cell
  /// has no text.
  String get content {
    if (_graphemeLen == 0) return '';
    final cp = check(bindings.cellGetCodepoint(_rawCell));
    if (_graphemeLen == 1 && cp < 128) return String.fromCharCode(cp);
    return String.fromCharCodes(
      check(bindings.rowCellsGetGraphemes(_handle, _graphemeLen)),
    );
  }

  /// Resolved foreground color, or null if the cell has no explicit
  /// foreground. Resolves palette indices through the active palette.
  /// Bold color handling is not applied; handle bold styling separately.
  /// When null, use the terminal's default foreground color.
  RgbColor? get foreground {
    final (code, rgb) = bindings.rowCellsGetFgColor(_handle);
    return code == .success ? rgb : null;
  }

  /// Whether the cell has a hyperlink (OSC 8).
  bool get hasHyperlink => check(bindings.cellGetHasHyperlink(_rawCell));

  /// Whether the cell has non-default styling attributes.
  bool get hasStyling => check(bindings.cellGetHasStyling(_rawCell));

  /// Whether the cell contains any text.
  bool get hasText => _graphemeLen > 0;

  /// Whether the cell is protected (DECSCA).
  bool get isProtected => check(bindings.cellGetProtected(_rawCell));

  /// The cell's semantic content type.
  SemanticContent get semanticContent {
    return check(bindings.cellGetSemanticContent(_rawCell));
  }

  /// The cell's [Style]. Cached per style ID to avoid redundant lookups
  /// across cells sharing the same style.
  Style get style {
    if (_styleId != _prevStyleId) {
      _prevStyleId = _styleId;
      _cachedStyle = check(bindings.rowCellsGetStyle(_handle));
    }
    return _cachedStyle;
  }

  /// The cell's internal style identifier. Cells with the same style ID
  /// share identical styling attributes.
  int get styleId => _styleId;

  /// The cell's width: [CellWidth.normal], [CellWidth.wide], or
  /// [CellWidth.spacerTail] (second cell of a wide character).
  CellWidth get wide => check(bindings.cellGetWide(_rawCell));

  bool _advance() {
    if (!bindings.rowCellsNext(_handle)) return false;
    _refresh();
    return true;
  }

  void _refresh() {
    _rawCell = check(bindings.rowCellsGetRawCell(_handle));
    _graphemeLen = check(bindings.rowCellsGetGraphemeLen(_handle));
    _styleId = check(bindings.cellGetStyleId(_rawCell));
  }
}
