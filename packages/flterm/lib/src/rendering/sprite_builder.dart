import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';

import 'atlas/glyph_atlas.dart';
import 'atlas/sprite_buffer.dart';
import 'paint_state.dart';

bool _hasDecoration(Style style) {
  return style.underline != .none || style.strikethrough || style.overline;
}

/// Whether [cp] is a CJK or Hangul codepoint (rendered as tinted text).
///
/// Wide characters that are NOT CJK are assumed to be emoji and rendered
/// as full-color image sprites. Flutter doesn't expose a font-level
/// `isColorGlyph()` check, so codepoint range classification is the
/// pragmatic way to distinguish CJK text from emoji in the hot loop.
bool _isCjk(int cp) {
  return (cp >= 0x2E80 && cp <= 0x9FFF) || // CJK radicals, unified ideographs
      (cp >= 0xAC00 && cp <= 0xD7AF) || // Hangul Syllables
      (cp >= 0xF900 && cp <= 0xFAFF) || // CJK Compatibility Ideographs
      (cp >= 0xFE30 && cp <= 0xFE4F) || // CJK Compatibility Forms
      (cp >= 0xFF01 && cp <= 0xFF60) || // Fullwidth Forms
      (cp >= 0xFFE0 && cp <= 0xFFE6) || // Fullwidth Signs
      (cp >= 0x1100 && cp <= 0x11FF) || // Hangul Jamo
      (cp >= 0x3130 && cp <= 0x318F) || // Hangul Compatibility Jamo
      (cp >= 0xA960 && cp <= 0xA97F) || // Hangul Jamo Extended-A
      (cp >= 0xD7B0 && cp <= 0xD7FF) || // Hangul Jamo Extended-B
      (cp >= 0x20000 && cp <= 0x2FA1F); // CJK Supplementary
}

/// ASCII punctuation/operator: not digit, not uppercase, not lowercase.
bool _isOperator(int cp) {
  return cp < 0x30 ||
      (cp > 0x39 && cp < 0x41) ||
      (cp > 0x5A && cp < 0x61) ||
      cp > 0x7A;
}

/// Builds all sprite data for one terminal frame.
///
/// Reads terminal cells via [RenderState] (walked with pre-allocated
/// [RowIterator] and [CellIterator]) and populates [SpriteBuffer] with
/// glyph positions, background color runs, and decoration rects. After
/// [build] returns, the atlas image and sprite vertices are finalized
/// and ready for painters.
///
/// Key optimizations in the per-cell hot loop:
/// - Style cache indexed by styleId avoids redundant color resolution.
/// - ASCII operators (punctuation, symbols) are batched into multi-glyph
///   runs to reduce atlas entries and drawRawAtlas sprite count.
/// - Single-codepoint non-ASCII uses int-keyed atlas lookup to avoid
///   String allocation.
/// - Background color runs are coalesced across adjacent same-color cells.
class SpriteBuilder {
  final GlyphAtlas _atlas;
  final SpriteBuffer _sprites;
  final TerminalPaintState _state;
  final _StyleCache _styleCache;
  final _RowCursor _cursor;
  final RowIterator _rows;
  final CellIterator _cells;

  // Per-frame cached values used in the per-cell hot loop.
  late double _cellWidth;
  late double _cellHeight;
  late double _underlineThickness;
  late double _strikethroughPosition;
  late double _strikethroughThickness;
  late double _overlinePosition;
  late double _inverseDpr;
  late int _bgArgb;
  late int _cols;
  late bool _applyCellOpacity;
  late int _cellOpacityAlpha;

  SpriteBuilder(this._atlas, this._sprites, this._state)
    : _styleCache = _StyleCache(_state),
      _cursor = _RowCursor(),
      _rows = RowIterator(),
      _cells = CellIterator();

  /// Rebuilds all sprites from [renderState].
  ///
  /// Clears existing sprite data, iterates every cell in the viewport,
  /// and populates the sprite buffer with glyph, background, and
  /// decoration entries. Finalizes the atlas image at the end.
  ///
  /// After returning, [SpriteBuffer] and [GlyphAtlas.image] are ready
  /// for painters.
  void build(RenderState renderState) {
    _sprites.clear();
    _cellWidth = _state.metrics.cellWidth;
    _cellHeight = _state.metrics.cellHeight;
    _underlineThickness = _state.metrics.underlineThickness;
    _strikethroughPosition = _state.metrics.strikethroughPosition;
    _strikethroughThickness = _state.metrics.strikethroughThickness;
    _overlinePosition = _state.metrics.overlinePosition;
    _inverseDpr = 1.0 / _atlas.devicePixelRatio;
    _bgArgb = _state.terminalBackgroundArgb;
    _cols = _state.cols;
    final theme = _state.theme;
    _applyCellOpacity =
        theme.backgroundOpacityCells && theme.backgroundOpacity < 1.0;
    _cellOpacityAlpha = theme.backgroundOpacityAlpha;
    _styleCache.beginFrame();

    _rows.reset(renderState);
    var row = 0;
    while (_rows.next()) {
      if (row >= _state.rows) break;
      _cursor.reset(row, _cellHeight, _bgArgb);
      _cells.reset(_rows);
      _buildRow(_cells);
      _rows.dirty = false;
      row++;
    }

    _atlas.ensureImage();
    _sprites.seal();
  }

  /// Releases the owned [RowIterator] and [CellIterator] handles.
  ///
  /// Must be called to free resources; the builder must not be used
  /// afterward.
  void dispose() {
    _cells.dispose();
    _rows.dispose();
  }

  /// Iterates cells in one row, emitting glyphs, backgrounds, and decorations.
  void _buildRow(CellIterator cells) {
    final cursor = _cursor;
    final cellWidth = _cellWidth;

    while (cells.next() && cursor.col < _cols) {
      final isWide = cells.wide == .wide;

      if (cells.styleId != cursor.prevStyleId) {
        _flushOperatorRun(cursor);
        final (fg, bg, style, explicitBg) = _styleCache.resolve(cells);
        cursor.prevStyleId = cells.styleId;
        cursor.foreground = fg;
        cursor.background = bg;
        cursor.backgroundInverse = style.inverse;
        cursor.backgroundExplicit = explicitBg;
        cursor.style = style;
      }

      _flushBackgroundRun(cursor, cellWidth);

      final style = cursor.style;
      if (style != null &&
          (style.invisible || (!_state.blinkVisible && style.blink))) {
        _flushOperatorRun(cursor);
        final advance = isWide ? 2 : 1;
        cursor.col += advance;
        cursor.spriteX += cellWidth * advance;
        if (isWide) cells.next();
        continue;
      }

      final decorationX = cursor.spriteX;

      if (isWide) {
        _emitWide(cells, cursor);
      } else if (cells.hasText) {
        _emitNarrow(cells, cursor);
      } else {
        _flushOperatorRun(cursor);
      }

      if (style != null && _hasDecoration(style)) {
        _emitDecoration(decorationX, isWide ? 2 : 1, cursor);
      }

      cursor.col++;
      cursor.spriteX += cellWidth;
    }

    _flushOperatorRun(cursor);

    if (cursor.bgRunExplicit) {
      _sprites.background.add(
        cursor.bgRunStart * cellWidth,
        cursor.rowY,
        _cols * cellWidth,
        cursor.rowBottom,
        _resolveBgArgb(cursor.bgRunArgb, cursor.bgRunInverse),
      );
    }
  }

  void _emitCodepoint(int codepoint, double x, Style style, _RowCursor cursor) {
    final entry = _atlas.addCodepoint(
      codepoint,
      bold: style.bold,
      italic: style.italic,
    );
    _sprites.regular.add(x, cursor.rowY, entry, _inverseDpr, cursor.foreground);
  }

  /// Emits decoration sprites (underline, strikethrough, overline).
  ///
  /// Underlines use pre-rasterized atlas sprites (one per style) so
  /// curly/dotted/dashed patterns render identically across cells.
  /// Strikethrough and overline are simple filled rects drawn directly
  /// (no atlas entry needed). Overline reuses underline thickness since
  /// both are thin horizontal lines derived from the same font metrics.
  void _emitDecoration(double x, int span, _RowCursor cursor) {
    final style = cursor.style!;
    final right = x + _cellWidth * span;

    final underlineColor = style.underlineColor;
    final color = underlineColor != null
        ? _state.theme
              .resolveColor(underlineColor, isForeground: true)
              .toARGB32()
        : cursor.foreground;

    if (style.underline != UnderlineStyle.none) {
      final entry = _atlas.addDecoration(style.underline);
      for (var i = 0; i < span; i++) {
        _sprites.underline.add(
          x + _cellWidth * i,
          cursor.rowY,
          entry,
          _inverseDpr,
          color,
        );
      }
    }
    if (style.strikethrough) {
      final strikeY = cursor.rowY + _strikethroughPosition;
      _sprites.decoration.add(
        x,
        strikeY,
        right,
        strikeY + _strikethroughThickness,
        cursor.foreground,
      );
    }
    if (style.overline) {
      final overY = cursor.rowY + _overlinePosition;
      _sprites.decoration.add(
        x,
        overY,
        right,
        overY + _underlineThickness,
        cursor.foreground,
      );
    }
  }

  /// Emits a single-cell glyph.
  ///
  /// Three fast paths by codepoint range:
  /// - ASCII printable: operators batch into multi-char ligature runs
  ///   (e.g., =>, !=, ===); alphanumeric go direct to atlas.
  /// - Non-ASCII single-codepoint (< U+100000): uses int-keyed atlas
  ///   lookup to avoid String allocation.
  /// - Multi-codepoint graphemes and VS16 emoji (U+FE0F): uses string
  ///   key; VS16 presence triggers the emoji sprite path (full color,
  ///   no tinting) instead of text sprite.
  void _emitNarrow(CellIterator cell, _RowCursor cursor) {
    final cp = cell.codepoint;
    final style = cursor.style!;

    // ASCII printable: operators batch into runs, alphanumeric go direct.
    if (cp > 0x20 && cp < 0x7F) {
      if (_isOperator(cp)) {
        if (cursor.operatorRun.isEmpty) cursor.operatorRunX = cursor.spriteX;
        cursor.operatorRun.add(cp);
        return;
      }
      _flushOperatorRun(cursor);
      _emitCodepoint(cp, cursor.spriteX, style, cursor);
      return;
    }

    // Non-ASCII: single codepoints use int-key path to avoid String
    // allocation; multi-codepoint graphemes and VS16 emoji use string key.
    if (cp > 0x7F) {
      _flushOperatorRun(cursor);

      if (cell.graphemeLength == 1 && cp < 0x100000) {
        // Single codepoints below the supplementary private use area
        // use the int-keyed atlas path. Above that threshold, some
        // codepoints encode emoji or variation sequences that need
        // the full string-keyed path.
        _emitCodepoint(cp, cursor.spriteX, style, cursor);
      } else {
        final content = cell.content;
        if (content.isNotEmpty && content != ' ') {
          final key = (text: content, bold: style.bold, italic: style.italic);
          // VS16 (U+FE0F) forces text-presentation codepoints into emoji
          // presentation. These go to the emoji sprite path (full color,
          // no foreground tinting) rather than the regular text path.
          if (content.contains('\uFE0F')) {
            _sprites.emoji.add(
              cursor.spriteX,
              cursor.rowY,
              _atlas.add(key, emoji: true),
              _inverseDpr,
            );
          } else {
            _sprites.regular.add(
              cursor.spriteX,
              cursor.rowY,
              _atlas.add(key),
              _inverseDpr,
              cursor.foreground,
            );
          }
        }
      }
      return;
    }

    // Control characters and space: no glyph, just flush pending operators.
    _flushOperatorRun(cursor);
  }

  /// Emits a wide (2-cell) glyph as either CJK text or emoji.
  ///
  /// The distinction matters for rendering: CJK text gets foreground
  /// color tinting (BlendMode.modulate) and bearingX centering via
  /// rasterize(), while emoji get full-color rendering (no tinting)
  /// and are scaled/centered via _compositeEmoji. Misclassifying a
  /// CJK character as emoji would lose its foreground color; misclassifying
  /// an emoji as CJK would tint away its colors.
  void _emitWide(CellIterator cell, _RowCursor cursor) {
    _flushOperatorRun(cursor);
    final content = cell.content;
    if (content.isNotEmpty && content != ' ') {
      final cp = cell.codepoint;
      final isEmoji = !_isCjk(cp);
      final style = cursor.style!;
      final key = (text: content, bold: style.bold, italic: style.italic);
      final entry = _atlas.add(key, span: 2, emoji: isEmoji);
      if (isEmoji) {
        _sprites.emoji.add(cursor.spriteX, cursor.rowY, entry, _inverseDpr);
      } else {
        _sprites.wide.add(
          cursor.spriteX,
          cursor.rowY,
          entry,
          _inverseDpr,
          cursor.foreground,
        );
      }
    }
    // Advance past the spacer tail. Flush the background run through
    // both columns, then restart after the tail.
    cursor.col++;
    cursor.spriteX += _cellWidth;
    if (cursor.col < _cols) {
      if (cursor.bgRunExplicit) {
        _sprites.background.add(
          cursor.bgRunStart * _cellWidth,
          cursor.rowY,
          (cursor.col + 1) * _cellWidth,
          cursor.rowBottom,
          _resolveBgArgb(cursor.bgRunArgb, cursor.bgRunInverse),
        );
      }
      cursor.bgRunStart = cursor.col + 1;
      cursor.bgRunArgb = _bgArgb;
      cursor.bgRunInverse = false;
      cursor.bgRunExplicit = false;
    }
    cell.next();
  }

  /// Flushes a background color run when the current cell's background
  /// differs from the run's color. Only emits if the run isn't the
  /// terminal default background (transparent cells need no rect).
  void _flushBackgroundRun(_RowCursor cursor, double cellWidth) {
    // The run ends when any of the three properties (color, inverse
    // flag, explicit flag) changes, since all three affect whether and
    // how a rect must be emitted.
    final sameRun =
        cursor.background == cursor.bgRunArgb &&
        cursor.backgroundExplicit == cursor.bgRunExplicit &&
        cursor.backgroundInverse == cursor.bgRunInverse;
    if (sameRun) return;

    if (cursor.bgRunExplicit) {
      _sprites.background.add(
        cursor.bgRunStart * cellWidth,
        cursor.rowY,
        cursor.col * cellWidth,
        cursor.rowBottom,
        _resolveBgArgb(cursor.bgRunArgb, cursor.bgRunInverse),
      );
    }
    cursor.bgRunArgb = cursor.background;
    cursor.bgRunStart = cursor.col;
    cursor.bgRunInverse = cursor.backgroundInverse;
    cursor.bgRunExplicit = cursor.backgroundExplicit;
  }

  /// Flushes a consecutive run of ASCII operators into a single atlas entry.
  ///
  /// Batching operators (e.g., `=>`, `!=`, `===`) into one multi-glyph
  /// sprite allows the font's ligature tables to activate, and reduces
  /// the total sprite count in drawRawAtlas. Single-operator runs fall
  /// back to the int-keyed codepoint path for efficiency.
  void _flushOperatorRun(_RowCursor cursor) {
    if (cursor.operatorRun.isEmpty) return;
    final style = cursor.style!;

    if (cursor.operatorRun.length == 1) {
      _emitCodepoint(
        cursor.operatorRun.first,
        cursor.operatorRunX,
        style,
        cursor,
      );
    } else {
      final text = String.fromCharCodes(cursor.operatorRun);
      final span = cursor.operatorRun.length;
      final key = (text: text, bold: style.bold, italic: style.italic);
      _sprites.regular.add(
        cursor.operatorRunX,
        cursor.rowY,
        _atlas.add(key, span: span),
        _inverseDpr,
        cursor.foreground,
      );
    }
    cursor.operatorRun.clear();
  }

  /// Applies [_cellOpacityAlpha] to [argb] when cell-level opacity is
  /// enabled and the run is not inverse. Inverse runs stay opaque so
  /// swapped fg/bg cells remain readable.
  int _resolveBgArgb(int argb, bool inverse) {
    if (!_applyCellOpacity || inverse) return argb;
    final currentAlpha = (argb >>> 24) & 0xFF;
    final newAlpha = (currentAlpha * _cellOpacityAlpha + 127) ~/ 255;
    return (newAlpha << 24) | (argb & 0x00FFFFFF);
  }
}

/// Mutable position and style state within a single row.
///
/// Allocated once by [SpriteBuilder] and reused across rows via [reset].
class _RowCursor {
  var col = 0;
  var spriteX = 0.0;
  var rowY = 0.0;

  // Bottom of the cell (used for per-cell background runs).
  var rowBottom = 0.0;

  var prevStyleId = -1;
  var foreground = 0xFFFFFFFF;
  var background = 0;

  /// Whether [background] came from an inverse cell.
  ///
  /// Tracked separately from [Style.inverse] on [style] because the bg
  /// run may outlive the style context: when emitted, we need to know if
  /// the run (not the current style) was inverse so we skip opacity.
  var backgroundInverse = false;

  /// Whether [background] came from a cell with an explicit
  /// (non-default) background color, or from an inverse cell.
  ///
  /// Default background cells skip rect emission and let the backdrop
  /// show through. Explicit background cells always emit a rect, even
  /// when the color happens to equal the theme default: this keeps the
  /// region opaque so apps like Neovim and tmux that repaint the grid
  /// with the default color don't leak the backdrop through their chrome.
  var backgroundExplicit = false;
  Style? style;

  var bgRunStart = 0;
  var bgRunArgb = 0;
  var bgRunInverse = false;
  var bgRunExplicit = false;

  var operatorRunX = 0.0;
  final List<int> operatorRun;

  _RowCursor() : operatorRun = <int>[];

  void reset(int row, double cellHeight, int defaultBg) {
    rowY = row * cellHeight;
    rowBottom = rowY + cellHeight;
    col = 0;
    spriteX = 0.0;
    prevStyleId = -1;
    foreground = 0xFFFFFFFF;
    background = defaultBg;
    backgroundInverse = false;
    backgroundExplicit = false;
    style = null;
    bgRunStart = 0;
    bgRunArgb = defaultBg;
    bgRunInverse = false;
    bgRunExplicit = false;
    operatorRunX = 0.0;
    operatorRun.clear();
  }
}

/// Per-frame style cache indexed by styleId (0-255).
///
/// Avoids redundant color resolution in the per-cell hot loop. A
/// generation counter marks entries from previous frames as stale,
/// which is cheaper than clearing 256 entries every frame. Resolves
/// fg/bg ARGB with bold-is-bright, inverse, and faint transformations
/// applied in the correct order.
class _StyleCache {
  static const _maxEntries = 256;

  final TerminalPaintState _state;
  final Int32List _gen;
  final Int32List _foreground;
  final Int32List _background;
  final Uint8List _explicitBg;
  final List<Style?> _styles;
  var _generation = 0;

  // Cached per-frame defaults for hot-path access.
  var _defaultFg = 0;
  var _defaultBg = 0;

  _StyleCache(this._state)
    : _gen = Int32List(_maxEntries),
      _foreground = Int32List(_maxEntries),
      _background = Int32List(_maxEntries),
      _explicitBg = Uint8List(_maxEntries),
      _styles = List<Style?>.filled(_maxEntries, null);

  void beginFrame() {
    _generation++;
    _defaultFg = _state.terminalForegroundArgb;
    _defaultBg = _state.terminalBackgroundArgb;
  }

  /// Returns cached or freshly resolved (fg, bg, style, explicitBg) for
  /// [cell].
  ///
  /// `explicitBg` is true when the cell's style carries a non-default
  /// background color or when the cell is inverse. Inverse always
  /// produces an opaque rect so swapped fg/bg cells stay readable.
  (int foreground, int background, Style style, bool explicitBg) resolve(
    CellIterator cell,
  ) {
    final id = cell.styleId;

    if (id < _maxEntries && _gen[id] == _generation) {
      return (
        _foreground[id],
        _background[id],
        _styles[id]!,
        _explicitBg[id] != 0,
      );
    }

    final style = cell.style;
    var foreground = cell.foregroundArgb ?? _defaultFg;
    var background = cell.backgroundArgb ?? _defaultBg;
    var explicitBg = style.background is! DefaultColor;

    if (style.bold && _state.theme.boldIsBright) {
      final raw = style.foreground;
      if (raw is PaletteColor && raw.index < 8) {
        foreground = _state.theme.palette[raw.index + 8].toARGB32();
      }
    }

    if (style.inverse) {
      (foreground, background) = (background, foreground);
      // Post-swap bg is the cell's foreground, which always needs a
      // rect even if the pre-swap bg was default.
      explicitBg = true;
    }

    if (style.faint) {
      foreground = (_state.faintAlpha << 24) | (foreground & 0x00FFFFFF);
    }

    if (id < _maxEntries) {
      _gen[id] = _generation;
      _foreground[id] = foreground;
      _background[id] = background;
      _explicitBg[id] = explicitBg ? 1 : 0;
      _styles[id] = style;
    }

    return (foreground, background, style, explicitBg);
  }
}
