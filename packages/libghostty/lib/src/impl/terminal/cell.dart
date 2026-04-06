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
  var _codepoint = 0;
  var _styleId = -1;
  var _prevStyleId = -1;
  var _cachedStyle = const Style();
  var _wide = CellWide.narrow;

  Cell._(this._handle);

  /// Resolved background color, or null if the cell has no explicit
  /// background. Resolves palette indices through the active palette.
  /// When null, use the terminal's default background color.
  RgbColor? get background {
    final (code, rgb) = bindings.rowCellsGetBgColor(_handle);
    return code == .success ? rgb : null;
  }

  /// Resolved background as packed ARGB int, or null if unset.
  int? get backgroundArgb {
    final (code, argb) = bindings.rowCellsGetBgColorArgb(_handle);
    return code == .success ? argb : null;
  }

  /// The cell's primary codepoint, or 0 if the cell has no text.
  /// Cached during [_refresh] to avoid redundant FFI calls. Accessed
  /// by both the renderer hot loop and [content].
  int get codepoint => _codepoint;

  /// The cell's full grapheme cluster as a string, or empty if the cell
  /// has no text.
  String get content {
    if (_graphemeLen == 0) return '';
    if (_graphemeLen == 1) return String.fromCharCode(_codepoint);
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

  /// Resolved foreground as packed ARGB int, or null if unset.
  int? get foregroundArgb {
    final (code, argb) = bindings.rowCellsGetFgColorArgb(_handle);
    return code == .success ? argb : null;
  }

  /// Number of codepoints in this cell's grapheme cluster (0 = empty).
  int get graphemeLength => _graphemeLen;

  /// Whether the cell has a hyperlink (OSC 8).
  bool get hasHyperlink => bindings.cellGetHasHyperlink(_rawCell).$2;

  /// Whether the cell has non-default styling attributes.
  bool get hasStyling => bindings.cellGetHasStyling(_rawCell).$2;

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

  /// The cell's width: [CellWide.narrow], [CellWide.wide], or
  /// [CellWide.spacerTail] (second cell of a wide character).
  /// Cached during [_refresh] to avoid per-access FFI calls.
  CellWide get wide => _wide;

  bool _advance() {
    if (!bindings.rowCellsNext(_handle)) return false;
    _refresh();
    return true;
  }

  void _refresh() {
    _rawCell = check(bindings.rowCellsGetRawCell(_handle));
    _graphemeLen = check(bindings.rowCellsGetGraphemeLen(_handle));
    _styleId = check(bindings.cellGetStyleId(_rawCell));
    _codepoint = _graphemeLen > 0
        ? check(bindings.cellGetCodepoint(_rawCell))
        : 0;
    // Fast path: single-codepoint cells in narrow Unicode ranges are always
    // narrow. All others need FFI: empty cells can be spacer tails, and
    // multi-codepoint graphemes can be widened by VS16 (mode 2027).
    _wide = _graphemeLen == 1 && !_couldBeWide(_codepoint)
        ? .narrow
        : bindings.cellGetWide(_rawCell).$2;
  }

  /// Fast heuristic: returns false for codepoints that are definitively
  /// narrow (< U+1100), avoiding the FFI call to [cellGetWide].
  static bool _couldBeWide(int codepoint) {
    if (codepoint < 0x1100) return false;
    if (codepoint < 0x1160) return true;
    if (codepoint < 0x2329) return false;
    if (codepoint <= 0x232A) return true;
    if (codepoint < 0x2E80) return false;
    if (codepoint <= 0x9FFF) return true;
    if (codepoint < 0xA960) return false;
    if (codepoint <= 0xA97F) return true;
    if (codepoint < 0xAC00) return false;
    if (codepoint <= 0xD7FF) return true;
    if (codepoint < 0xF900) return false;
    if (codepoint <= 0xFAFF) return true;
    if (codepoint < 0xFE10) return false;
    if (codepoint <= 0xFE6F) return true;
    if (codepoint < 0xFF01) return false;
    if (codepoint <= 0xFF60) return true;
    if (codepoint < 0xFFE0) return false;
    if (codepoint <= 0xFFE6) return true;
    if (codepoint < 0x1F000) return false;
    return true;
  }
}
