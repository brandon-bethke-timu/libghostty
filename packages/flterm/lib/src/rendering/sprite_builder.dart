import 'dart:typed_data';
import 'dart:ui';

import 'package:libghostty/libghostty.dart';

import '../foundation/dynamic_color.dart';
import '../foundation/terminal_selection.dart';
import 'atlas/atlas.dart';
import 'atlas/sprite_buffer.dart';
import 'codepoint_classification.dart';
import 'paint_state.dart';

bool _hasDecoration(Style style) {
  return style.underline != .none || style.strikethrough || style.overline;
}

/// ASCII punctuation/operator: not digit, not uppercase, not lowercase.
bool _isOperator(int cp) {
  return cp < 0x30 ||
      (cp > 0x39 && cp < 0x41) ||
      (cp > 0x5A && cp < 0x61) ||
      cp > 0x7A;
}

/// Tracks per-row dirtiness from sources outside libghostty's own
/// row-dirty flag, such as selection changes.
///
/// [SpriteBuilder] combines this with [RowIterator.dirty] when deciding
/// whether to re-emit each row, and clears it at the end of every
/// [SpriteBuilder.build].
class RowDirtyTracker {
  var _rows = Uint8List(0);
  var _anyDirty = false;

  /// Whether any row is currently marked dirty.
  bool get anyDirty => _anyDirty;

  /// Whether [row] is marked dirty. Out-of-range rows read as clean.
  bool isDirty(int row) => row >= 0 && row < _rows.length && _rows[row] != 0;

  /// Marks every row dirty.
  void markAll() {
    if (_rows.isEmpty) return;
    _rows.fillRange(0, _rows.length, 1);
    _anyDirty = true;
  }

  /// Marks rows `[from, toExclusive)` dirty, clamped to the tracker's
  /// current row count.
  void markRange(int from, int toExclusive) {
    final start = from < 0 ? 0 : from;
    final end = toExclusive > _rows.length ? _rows.length : toExclusive;
    if (start >= end) return;
    _rows.fillRange(start, end, 1);
    _anyDirty = true;
  }

  /// Marks a single [row] dirty. Out-of-range rows are ignored.
  void markRow(int row) {
    if (row < 0 || row >= _rows.length) return;
    _rows[row] = 1;
    _anyDirty = true;
  }

  /// Resizes to track [rowCount] rows and clears all flags.
  void resize(int rowCount) {
    if (_rows.length != rowCount) {
      _rows = Uint8List(rowCount);
    } else {
      _rows.fillRange(0, rowCount, 0);
    }
    _anyDirty = false;
  }

  void _clear() {
    if (!_anyDirty) return;
    _rows.fillRange(0, _rows.length, 0);
    _anyDirty = false;
  }
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
  final Atlas _atlas;
  final SpriteBuffer _sprites;
  final TerminalPaintState _state;
  final _StyleCache _styleCache;
  final _RowCursor _cursor;
  final RowIterator _rows;
  final CellIterator _cells;
  final RowDirtyTracker _dirtyRows;

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

  // Null short-circuits the per-cell selection-membership check in the hot
  // loop; the override fields and viewport offset are read directly from
  // _state when resolving a selected cell's colors.
  TerminalSelection? _selection;

  SpriteBuilder(this._atlas, this._sprites, this._state)
    : _styleCache = _StyleCache(_state),
      _cursor = _RowCursor(),
      _rows = RowIterator(),
      _cells = CellIterator(),
      _dirtyRows = RowDirtyTracker();

  /// Per-row dirty contributions from flterm-side sources (selection,
  /// blink, theme, atlas reconfigure). Combined with libghostty's own
  /// row-dirty flag during [build].
  RowDirtyTracker get dirtyRows => _dirtyRows;

  /// Updates sprites for the current frame.
  ///
  /// A row is re-emitted when [dirty] is not [DirtyState.partial], when
  /// libghostty flags it via [RowIterator.dirty], or when any
  /// flterm-side source has marked it via [dirtyRows]. Callers must not
  /// invoke [build] when the snapshot is [DirtyState.clean] and
  /// [dirtyRows] is empty; that case is handled one level up by
  /// skipping the build entirely.
  void build(RenderState renderState, {required DirtyState dirty}) {
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
    _selection = _state.selection;
    _styleCache.beginFrame();

    final rebuildAll = dirty != DirtyState.partial;

    _rows.reset(renderState);
    var row = 0;
    while (_rows.next()) {
      if (row >= _state.rows) break;
      if (rebuildAll || _rows.dirty || _dirtyRows.isDirty(row)) {
        _sprites.beginRow(row);
        _cursor.reset(row, _cellHeight, _bgArgb);
        _cells.reset(_rows);
        _buildRow(_cells);
        _sprites.endRow();
        _rows.dirty = false;
      }
      row++;
    }
    _dirtyRows._clear();

    _atlas.ensureImage();
    _sprites.seal();
  }

  /// Reconfigures sprite storage for the current grid size.
  ///
  /// Called by the render object when the grid dimensions change. The
  /// caller is responsible for triggering a [DirtyState.full] build on
  /// the next paint so every row is re-emitted into the fresh layout.
  void configure(int rows, int cols) {
    _sprites.configure(rows, cols);
    _dirtyRows.resize(rows);
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
      final selected = _isCellSelected(cursor.row, cursor.col);
      final styleChanged = cells.styleId != cursor.prevStyleId;
      final stateChanged = styleChanged || selected != cursor.prevSelected;

      if (stateChanged) {
        _flushOperatorRun(cursor);
        if (styleChanged) {
          final (fg, bg, style, explicitBg) = _styleCache.resolve(cells);
          cursor.prevStyleId = cells.styleId;
          cursor.baseForeground = fg;
          cursor.baseBackground = bg;
          cursor.baseBackgroundExplicit = explicitBg;
          cursor.backgroundInverse = style.inverse;
          cursor.style = style;
        }
        if (selected) {
          final sel = _state.theme.selection;
          cursor.foreground = _resolveSelectionColor(
            cursor,
            sel.foreground,
            _state.terminalBackgroundArgb,
          );
          cursor.background = _resolveSelectionColor(
            cursor,
            sel.background,
            _state.terminalForegroundArgb,
          );
          cursor.backgroundExplicit = true;
        } else {
          cursor.foreground = cursor.baseForeground;
          cursor.background = cursor.baseBackground;
          cursor.backgroundExplicit = cursor.baseBackgroundExplicit;
        }
        cursor.prevSelected = selected;
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
    final sprites = switch (entry.lane) {
      .sprite => _sprites.sprite,
      _ => _sprites.regular,
    };
    sprites.add(x, cursor.rowY, entry, _inverseDpr, cursor.foreground);
  }

  void _emitText(
    String text,
    double x,
    _RowCursor cursor, {
    required bool emoji,
    int span = 1,
    AtlasSprites? textSprites,
  }) {
    final style = cursor.style!;
    final entry = _atlas.add(
      (text: text, bold: style.bold, italic: style.italic),
      span: span,
      emoji: emoji,
    );

    if (emoji) {
      _sprites.emoji.add(x, cursor.rowY, entry, _inverseDpr);
      return;
    }

    (textSprites ?? _sprites.regular).add(
      x,
      cursor.rowY,
      entry,
      _inverseDpr,
      cursor.foreground,
    );
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
          // VS16 (U+FE0F) forces text-presentation codepoints into emoji
          // presentation. These go to the emoji sprite path (full color,
          // no foreground tinting) rather than the regular text path.
          _emitText(
            content,
            cursor.spriteX,
            cursor,
            emoji: content.contains('\uFE0F'),
          );
        }
      }
      return;
    }

    // Control characters and space: no glyph, just flush pending operators.
    _flushOperatorRun(cursor);
  }

  /// Emits a wide (2-cell) glyph as a built-in sprite, CJK text, or emoji.
  ///
  /// Routing rules, in priority order:
  /// 1. Single-codepoint cells whose codepoint is in the sprite face
  ///    (e.g. legacy computing supplement) render as tinted geometry
  ///    sprites.
  /// 2. CJK-range codepoints render as foreground-tinted text.
  /// 3. Everything else renders as full-color emoji (no tinting,
  ///    scaled and centered to the cell).
  ///
  /// Misclassifying CJK as emoji would lose foreground color;
  /// misclassifying emoji as CJK would tint away the emoji colors.
  void _emitWide(CellIterator cell, _RowCursor cursor) {
    _flushOperatorRun(cursor);
    final content = cell.content;
    if (content.isNotEmpty && content != ' ') {
      final cp = cell.codepoint;
      final style = cursor.style!;
      if (cell.graphemeLength == 1 && _atlas.hasSprite(cp)) {
        final entry = _atlas.addCodepoint(
          cp,
          bold: style.bold,
          italic: style.italic,
          span: 2,
        );
        _sprites.sprite.add(
          cursor.spriteX,
          cursor.rowY,
          entry,
          _inverseDpr,
          cursor.foreground,
        );
      } else {
        final renderAsEmoji = !isCjkCodepoint(cp);
        _emitText(
          content,
          cursor.spriteX,
          cursor,
          emoji: renderAsEmoji,
          span: 2,
          textSprites: _sprites.wide,
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
      _emitText(
        text,
        cursor.operatorRunX,
        cursor,
        emoji: false,
        span: cursor.operatorRun.length,
      );
    }
    cursor.operatorRun.clear();
  }

  bool _isCellSelected(int row, int col) {
    final selection = _selection;
    if (selection == null) return false;
    return selection.contains(row + _state.viewportOffset, col);
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

  // Resolves a selection override (foreground or background) against the
  // current cell. Defaults let selection invert the cell visually: when no
  // override is set, selection fg falls back to the terminal background and
  // selection bg to the terminal foreground.
  int _resolveSelectionColor(
    _RowCursor cursor,
    DynamicColor? override,
    int fallbackArgb,
  ) {
    if (override == null) return fallbackArgb;
    return override
        .resolve(
          cellForeground: Color(cursor.baseForeground),
          cellBackground: Color(cursor.baseBackground),
        )
        .toARGB32();
  }
}

/// Mutable position and style state within a single row.
///
/// Allocated once by [SpriteBuilder] and reused across rows via [reset].
class _RowCursor {
  var row = 0;
  var col = 0;
  var spriteX = 0.0;
  var rowY = 0.0;

  // Bottom of the cell (used for per-cell background runs).
  var rowBottom = 0.0;

  var prevStyleId = -1;

  /// Style-resolved foreground and background before any per-cell overrides.
  ///
  /// Distinct from [foreground]/[background] because a run of cells may
  /// share a styleId (skipping the style cache) while alternating selection
  /// membership, which overrides both the emitted foreground and background
  /// per cell.
  var baseForeground = 0xFFFFFFFF;
  var baseBackground = 0;
  var baseBackgroundExplicit = false;
  var foreground = 0xFFFFFFFF;
  var background = 0;

  /// Whether the previous cell was inside the selection. Flips trigger a
  /// flush and recompute of [foreground]/[background] at cell boundaries.
  var prevSelected = false;

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
    this.row = row;
    rowY = row * cellHeight;
    rowBottom = rowY + cellHeight;
    col = 0;
    spriteX = 0.0;
    prevStyleId = -1;
    baseForeground = 0xFFFFFFFF;
    baseBackground = defaultBg;
    baseBackgroundExplicit = false;
    foreground = 0xFFFFFFFF;
    background = defaultBg;
    backgroundInverse = false;
    backgroundExplicit = false;
    prevSelected = false;
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

    if (style.bold) {
      final boldColor = _state.theme.boldColor;
      if (boldColor != null) {
        foreground = boldColor.toARGB32();
      } else if (_state.theme.boldIsBright) {
        final raw = style.foreground;
        if (raw is PaletteColor && raw.index < 8) {
          foreground = _state.theme.palette[raw.index + 8].toARGB32();
        }
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
