import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:libghostty/libghostty.dart';

import '../foundation/dynamic_color.dart';
import '../foundation/terminal_selection.dart';
import 'atlas/atlas.dart';
import 'atlas/sprite_buffer.dart';
import 'cell_content_resolver.dart';
import 'paint_state.dart';

/// ASCII punctuation/operator: not digit, not uppercase, not lowercase.
bool _isOperator(int cp) {
  return cp < 0x30 ||
      (cp > 0x39 && cp < 0x41) ||
      (cp > 0x5A && cp < 0x61) ||
      cp > 0x7A;
}

/// Tracks per-row dirtiness from sources outside libghostty's own row-dirty
/// flag, such as selection, blink, layout, or atlas changes.
///
/// [TerminalFrameBuilder] combines this with [RowIterator.dirty] when deciding
/// whether to re-emit each row, and clears it at the end of every build.
class RowDirtyTracker {
  var _rows = Uint8List(0);
  var _anyDirty = false;

  bool get anyDirty => _anyDirty;

  /// Whether [row] is marked dirty. Out-of-range rows read as clean.
  bool isDirty(int row) => row >= 0 && row < _rows.length && _rows[row] != 0;

  void markAll() {
    if (_rows.isEmpty) return;
    _rows.fillRange(0, _rows.length, 1);
    _anyDirty = true;
  }

  /// Marks rows `[from, toExclusive)` dirty, clamped to the current row count.
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

/// Builds terminal visual layers for the current frame.
///
/// Reads terminal cells and writes [SpriteBuffer] channels for text, emoji,
/// built-in sprites, backgrounds, and decorations. The render object owns
/// lifecycle/layout/paint ordering; this class owns frame state sync, dirty-row
/// buffer generation, cursor visual resolution, and cell-content routing.
class TerminalFrameBuilder {
  final Atlas _atlas;
  final RowIterator _rows;
  final CellIterator _cells;
  final SpriteBuffer _sprites;
  final RenderState _renderState;
  final TerminalPaintState _state;
  final RowDirtyTracker _dirtyRows;
  final CellContentResolver _content;

  late final _TerminalRowBuilder _rowBuilder;
  late final _CursorFrameBuilder _cursorBuilder;

  TerminalFrameBuilder(this._atlas, this._sprites, this._state)
    : _content = CellContentResolver(_atlas),
      _renderState = RenderState(),
      _rows = RowIterator(),
      _cells = CellIterator(),
      _dirtyRows = RowDirtyTracker() {
    _rowBuilder = _TerminalRowBuilder(
      atlas: _atlas,
      sprites: _sprites,
      state: _state,
      content: _content,
    );
    _cursorBuilder = _CursorFrameBuilder(_state, _content);
  }

  /// Reconfigures sprite storage for the current grid size.
  void configure(int rows, int cols) {
    _sprites.configure(rows, cols);
    _dirtyRows.resize(rows);
  }

  /// Releases the owned libghostty iterators.
  void dispose() {
    _cells.dispose();
    _rows.dispose();
    _renderState.dispose();
  }

  /// Rebuilds every visible row on the next sync.
  void markAllRowsDirty() => _dirtyRows.markAll();

  /// Rebuilds rows `[from, toExclusive)` on the next sync.
  void markRowsDirty(int from, int toExclusive) {
    _dirtyRows.markRange(from, toExclusive);
  }

  /// Re-resolves the cursor glyph from the last cursor cell snapshot.
  ///
  /// Used when flterm-side state changes, such as focus or blink visibility,
  /// without a new terminal render state.
  void refreshCursorGlyph() => _cursorBuilder.refreshGlyph();

  /// Syncs terminal state into paint-ready buffers.
  void sync(Terminal terminal, {required bool terminalDirty}) {
    final hasDirtyRows = _dirtyRows.anyDirty;

    if (terminalDirty) {
      final dirty = _renderState.update(terminal);
      final scrollbar = terminal.scrollbar;

      _state.viewportOffset = scrollbar.offset;
      _state.terminalForegroundArgb =
          terminal.foreground?.toArgb32 ?? _state.theme.foreground.toARGB32();
      _state.terminalBackgroundArgb =
          terminal.background?.toArgb32 ?? _state.theme.background.toARGB32();

      if (dirty != .clean || hasDirtyRows) {
        _build(dirty);
        _renderState.dirty = .clean;
      }

      _cursorBuilder.sync(
        terminal: terminal,
        renderState: _renderState,
        scrollbar: scrollbar,
      );
    } else if (hasDirtyRows) {
      _build(.partial);
    }
  }

  void _build(DirtyState dirty) {
    _rowBuilder.beginFrame();

    final rebuildAll = dirty != DirtyState.partial;
    _rows.reset(_renderState);

    var row = 0;
    while (_rows.next()) {
      if (row >= _state.rows) break;
      if (rebuildAll || _rows.dirty || _dirtyRows.isDirty(row)) {
        _rowBuilder.rebuildRow(row, _rows, _cells);
        _rows.dirty = false;
      }
      row++;
    }

    _dirtyRows._clear();
    _atlas.ensureImage();
    _sprites.seal();
  }
}

/// Batches consecutive ASCII operators so font ligatures can apply.
final class _AsciiOperatorRun {
  final _codepoints = <int>[];
  var x = 0.0;

  int get first => _codepoints.first;

  bool get isEmpty => _codepoints.isEmpty;

  int get length => _codepoints.length;

  String get text => String.fromCharCodes(_codepoints);

  void add(int codepoint, double cellX) {
    if (_codepoints.isEmpty) x = cellX;
    _codepoints.add(codepoint);
  }

  void clear() => _codepoints.clear();
}

/// Snapshot of the cell under the cursor.
///
/// Captured during state sync so cursor painting can render the character
/// under a block cursor without touching terminal state during paint.
final class _CursorCellSnapshot {
  final String content;
  final Style style;
  final bool wide;

  const _CursorCellSnapshot(this.content, this.style, {required this.wide});
}

/// Resolves cursor geometry, colors, and block-cursor glyph state.
final class _CursorFrameBuilder {
  final TerminalPaintState _state;
  final CellContentResolver _content;
  var _cursor = const Cursor();
  _CursorCellSnapshot? _lastCell;

  _CursorFrameBuilder(this._state, this._content);

  void refreshGlyph() {
    final cell = _lastCell;
    final entry = _resolveGlyph();
    _state.cursorAtlasEntry = entry;
    if (entry == null || cell == null) return;

    // The character under a block cursor paints in CursorTheme.text (or the
    // terminal background when unset) so it contrasts with the cursor fill.
    final (cellFg, cellBg) = _resolveCellColors(cell);
    final glyphColor =
        _state.theme.cursor.text?.resolve(
          cellForeground: cellFg,
          cellBackground: cellBg,
        ) ??
        Color(_state.terminalBackgroundArgb);
    _state.cursorGlyphPaint.colorFilter = ColorFilter.mode(
      glyphColor,
      BlendMode.modulate,
    );
  }

  void sync({
    required Terminal terminal,
    required RenderState renderState,
    required Scrollbar scrollbar,
  }) {
    final cursor = renderState.cursor;
    final scrollbackLen = scrollbar.total - scrollbar.visible;
    final inViewport =
        cursor.visible &&
        (scrollbackLen <= 0 || scrollbar.offset >= scrollbackLen) &&
        cursor.row >= 0 &&
        cursor.row < _state.rows &&
        cursor.col >= 0 &&
        cursor.col < _state.cols;

    if (!inViewport) {
      _hide(cursor);
      return;
    }

    final adjustedCursor = cursor.wideTail && cursor.col > 0
        ? cursor.copyWith(col: cursor.col - 1)
        : cursor;
    final effectiveCursor = adjustedCursor.shape == CursorShape.block
        ? adjustedCursor.copyWith(shape: _state.theme.cursor.shape)
        : adjustedCursor;
    final ref = GridRef.at(
      terminal,
      col: effectiveCursor.col,
      row: effectiveCursor.row,
    );
    final cell = _CursorCellSnapshot(ref.content, ref.style, wide: ref.isWide);
    ref.dispose();

    _cursor = effectiveCursor;
    _lastCell = cell;
    _state.cursor = effectiveCursor;
    _state.cursorWide = cell.wide;
    _resolveFillColor(terminal, cell);
    refreshGlyph();
  }

  void _hide(Cursor cursor) {
    _cursor = cursor;
    _lastCell = null;
    _state.cursor = cursor.copyWith(visible: false);
    _state.cursorWide = false;
    _state.cursorAtlasEntry = null;
  }

  (Color, Color) _resolveCellColors(_CursorCellSnapshot cell) {
    final theme = _state.theme;
    var fg = theme.resolveColor(cell.style.foreground, isForeground: true);
    var bg = theme.resolveColor(cell.style.background, isForeground: false);
    if (cell.style.inverse) (fg, bg) = (bg, fg);
    return (fg, bg);
  }

  // An OSC 12 color reported by libghostty overrides the theme cursor color.
  void _resolveFillColor(Terminal terminal, _CursorCellSnapshot cell) {
    final osc = terminal.cursorColor;
    if (osc != null) {
      _state.cursorColorArgb = osc.toArgb32;
      return;
    }
    final themeCursor = _state.theme.cursor.color;
    if (themeCursor == null) {
      _state.cursorColorArgb = _state.terminalForegroundArgb;
      return;
    }
    final (cellFg, cellBg) = _resolveCellColors(cell);
    _state.cursorColorArgb = themeCursor
        .resolve(cellForeground: cellFg, cellBackground: cellBg)
        .toARGB32();
  }

  AtlasEntry? _resolveGlyph() {
    final cell = _lastCell;
    if (cell == null ||
        !_state.cursorFocused ||
        _cursor.shape != CursorShape.block) {
      return null;
    }
    final style = cell.style;
    if (cell.content.isEmpty ||
        style.invisible ||
        (style.blink && !_state.blinkVisible)) {
      return null;
    }

    final runes = cell.content.runes;
    return _content.resolve(
      content: cell.content,
      codepoint: runes.first,
      graphemeLength: runes.length,
      style: style,
      span: cell.wide ? 2 : 1,
    );
  }
}

/// Emits text, emoji, and built-in sprite foreground channels.
final class _ForegroundEmitter {
  final SpriteBuffer _sprites;
  final _FrameSnapshot _frame;
  final TerminalPaintState _state;
  final CellContentResolver _content;
  final _AsciiOperatorRun _operators;

  _ForegroundEmitter(this._sprites, this._content, this._frame, this._state)
    : _operators = _AsciiOperatorRun();

  void emit(CellIterator cell, _RowBuildState row, {required int span}) {
    if (!cell.hasText) {
      flush(row);
      return;
    }

    final codepoint = cell.codepoint;
    final style = row.style;

    if (span == 1 && codepoint > 0x20 && codepoint < 0x7F) {
      if (_isOperator(codepoint)) {
        _operators.add(codepoint, row.spriteX);
        return;
      }

      flush(row);
      _emitCodepoint(codepoint, row, style: style, x: row.spriteX);
      return;
    }

    flush(row);
    final entry = _content.resolveCell(cell, style: style, span: span);
    if (entry == null) return;
    _emitEntry(entry, row, x: row.spriteX, wideText: span == 2);
  }

  void flush(_RowBuildState row) {
    if (_operators.isEmpty) return;

    final style = row.style;
    if (_operators.length == 1) {
      _emitCodepoint(_operators.first, row, style: style, x: _operators.x);
    } else {
      _emitShapedRun(
        _operators.text,
        row,
        style: style,
        span: _operators.length,
      );
    }
    _operators.clear();
  }

  void _emitShapedRun(
    String text,
    _RowBuildState row, {
    required Style style,
    required int span,
  }) {
    final theme = _state.theme;
    final width = _frame.cellWidth * span;
    final overhang = style.italic
        ? math.max(1.0, (theme.fontSize * 0.15).ceilToDouble())
        : 0.0;
    final paragraph =
        (ParagraphBuilder(
                ParagraphStyle(
                  fontSize: theme.fontSize,
                  fontFamily: theme.fontFamily,
                  textAlign: .start,
                ),
              )
              ..pushStyle(
                TextStyle(
                  color: Color(row.foreground),
                  fontSize: theme.fontSize,
                  fontFamily: theme.fontFamily,
                  decoration: TextDecoration.none,
                  fontWeight: style.bold ? .bold : theme.fontWeight,
                  fontStyle: style.italic ? .italic : .normal,
                  fontFamilyFallback: theme.fontFamilyFallback,
                ),
              )
              ..addText(text)
              ..pop())
            .build()
          ..layout(const ParagraphConstraints(width: .infinity));
    final bearingX = span > 1
        ? math.max(0.0, (width - paragraph.maxIntrinsicWidth) / 2)
        : 0.0;
    _sprites.shaped.add(
      ShapedRun(
        paragraph: paragraph,
        offset: Offset(
          _operators.x + bearingX,
          row.rowY + _state.metrics.baseline - paragraph.alphabeticBaseline,
        ),
        clip: Rect.fromLTWH(
          _operators.x,
          row.rowY,
          width + overhang,
          _frame.cellHeight,
        ),
      ),
    );
  }

  void _emitCodepoint(
    int codepoint,
    _RowBuildState row, {
    required Style style,
    required double x,
  }) {
    final entry = _content.resolveCodepoint(codepoint, style: style);
    _emitEntry(entry, row, x: x, wideText: false);
  }

  void _emitEntry(
    AtlasEntry entry,
    _RowBuildState row, {
    required double x,
    required bool wideText,
  }) {
    switch (entry.lane) {
      case .emoji:
        _sprites.emoji.add(x, row.rowY, entry, _frame.inverseDpr);
      case .sprite:
        _sprites.sprite.add(
          x,
          row.rowY,
          entry,
          _frame.inverseDpr,
          row.foreground,
        );
      case .text:
        final sprites = wideText ? _sprites.wide : _sprites.regular;
        sprites.add(x, row.rowY, entry, _frame.inverseDpr, row.foreground);
      case .decoration:
        throw StateError('Decoration atlas entries cannot paint cell content.');
    }
  }
}

/// Frame-scoped metrics and theme values read by row emitters.
final class _FrameSnapshot {
  var cellWidth = 0.0;
  var cellHeight = 0.0;
  var underlineThickness = 0.0;
  var strikethroughPosition = 0.0;
  var strikethroughThickness = 0.0;
  var overlinePosition = 0.0;
  var inverseDpr = 1.0;
  var defaultBackgroundArgb = 0;
  var cols = 0;
  var applyCellOpacity = false;
  var cellOpacityAlpha = 255;
  var viewportOffset = 0;
  TerminalSelection? selection;

  bool isSelected(int row, int col) {
    final active = selection;
    if (active == null) return false;
    return active.contains(row + viewportOffset, col);
  }

  int resolveBgArgb(int argb, {required bool inverse}) {
    if (!applyCellOpacity || inverse) return argb;
    final currentAlpha = (argb >>> 24) & 0xFF;
    final newAlpha = (currentAlpha * cellOpacityAlpha + 127) ~/ 255;
    return (newAlpha << 24) | (argb & 0x00FFFFFF);
  }

  void update(TerminalPaintState state, {required Atlas atlas}) {
    final metrics = state.metrics;
    cellWidth = metrics.cellWidth;
    cellHeight = metrics.cellHeight;
    underlineThickness = metrics.underlineThickness;
    strikethroughPosition = metrics.strikethroughPosition;
    strikethroughThickness = metrics.strikethroughThickness;
    overlinePosition = metrics.overlinePosition;
    inverseDpr = 1.0 / atlas.devicePixelRatio;
    defaultBackgroundArgb = state.terminalBackgroundArgb;
    cols = state.cols;

    final theme = state.theme;
    applyCellOpacity =
        theme.backgroundOpacityCells && theme.backgroundOpacity < 1.0;
    cellOpacityAlpha = theme.backgroundOpacityAlpha;
    viewportOffset = state.viewportOffset;
    selection = state.selection;
  }
}

/// Mutable visual state for the row currently being rebuilt.
final class _RowBuildState {
  var row = 0;
  var col = 0;
  var spriteX = 0.0;
  var rowY = 0.0;
  var rowBottom = 0.0;

  var prevStyleId = -1;
  var prevSelected = false;

  var baseForeground = 0xFFFFFFFF;
  var baseBackground = 0;
  var baseBackgroundExplicit = false;
  var foreground = 0xFFFFFFFF;
  var background = 0;
  var backgroundInverse = false;
  var backgroundExplicit = false;
  var hidden = false;
  var hasDecoration = false;
  var style = const Style();

  var bgRunStart = 0;
  var bgRunArgb = 0;
  var bgRunInverse = false;
  var bgRunExplicit = false;

  void advance(int span, double cellWidth) {
    col += span;
    spriteX += cellWidth * span;
  }

  void reset(int row, _FrameSnapshot frame) {
    this.row = row;
    rowY = row * frame.cellHeight;
    rowBottom = rowY + frame.cellHeight;
    col = 0;
    spriteX = 0.0;
    prevStyleId = -1;
    prevSelected = false;
    baseForeground = 0xFFFFFFFF;
    baseBackground = frame.defaultBackgroundArgb;
    baseBackgroundExplicit = false;
    foreground = 0xFFFFFFFF;
    background = frame.defaultBackgroundArgb;
    backgroundInverse = false;
    backgroundExplicit = false;
    hidden = false;
    hasDecoration = false;
    style = const Style();
    bgRunStart = 0;
    bgRunArgb = frame.defaultBackgroundArgb;
    bgRunInverse = false;
    bgRunExplicit = false;
  }
}

/// Resolves and caches style-derived colors for the current frame.
final class _StyleResolver {
  static const _maxEntries = 256;

  final TerminalPaintState _state;
  final Int32List _gen;
  final Int32List _foreground;
  final Int32List _background;
  final Uint8List _explicitBg;
  final List<Style?> _styles;
  var _generation = 0;

  var _defaultFg = 0;
  var _defaultBg = 0;

  _StyleResolver(this._state)
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

  void update(
    CellIterator cell, {
    required bool selected,
    required _RowBuildState row,
  }) {
    if (cell.styleId != row.prevStyleId) {
      final (fg, bg, style, explicitBg) = _resolveBase(cell);
      row.prevStyleId = cell.styleId;
      row.baseForeground = fg;
      row.baseBackground = bg;
      row.baseBackgroundExplicit = explicitBg;
      row.backgroundInverse = style.inverse;
      row.style = style;
      row.hidden = style.invisible || (!_state.blinkVisible && style.blink);
      row.hasDecoration =
          style.underline != .none || style.strikethrough || style.overline;
    }

    if (selected) {
      final selection = _state.theme.selection;
      row.foreground = _resolveSelectionColor(
        row,
        selection.foreground,
        _state.terminalBackgroundArgb,
      );
      row.background = _resolveSelectionColor(
        row,
        selection.background,
        _state.terminalForegroundArgb,
      );
      row.backgroundExplicit = true;
    } else {
      row.foreground = row.baseForeground;
      row.background = row.baseBackground;
      row.backgroundExplicit = row.baseBackgroundExplicit;
    }

    row.prevSelected = selected;
  }

  (int foreground, int background, Style style, bool explicitBg) _resolveBase(
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

  int _resolveSelectionColor(
    _RowBuildState row,
    DynamicColor? override,
    int fallbackArgb,
  ) {
    if (override == null) return fallbackArgb;
    return override
        .resolve(
          cellForeground: Color(row.baseForeground),
          cellBackground: Color(row.baseBackground),
        )
        .toARGB32();
  }
}

/// Rebuilds dirty rows into background, foreground, and decoration channels.
final class _TerminalRowBuilder {
  final Atlas _atlas;
  final SpriteBuffer _sprites;
  final TerminalPaintState _state;
  final _FrameSnapshot _frame;
  final _RowBuildState _row;
  final _StyleResolver _styles;
  late final _ForegroundEmitter _foreground;

  _TerminalRowBuilder({
    required Atlas atlas,
    required SpriteBuffer sprites,
    required TerminalPaintState state,
    required CellContentResolver content,
  }) : _atlas = atlas,
       _sprites = sprites,
       _state = state,
       _frame = _FrameSnapshot(),
       _row = _RowBuildState(),
       _styles = _StyleResolver(state) {
    _foreground = _ForegroundEmitter(sprites, content, _frame, state);
  }

  void beginFrame() {
    _frame.update(_state, atlas: _atlas);
    _styles.beginFrame();
  }

  void rebuildRow(int rowIndex, RowIterator rows, CellIterator cells) {
    _sprites.beginRow(rowIndex);
    _row.reset(rowIndex, _frame);
    cells.reset(rows);

    while (cells.next() && _row.col < _frame.cols) {
      _writeCell(cells);
    }

    _foreground.flush(_row);
    _finishBackgroundRun(_row);
    _sprites.endRow();
  }

  void _closeBackgroundSpan(_RowBuildState row, int span) {
    final endCol = row.col + span > _frame.cols ? _frame.cols : row.col + span;
    _flushBackgroundRun(row, endCol);
    row.bgRunStart = endCol;
    row.bgRunArgb = _frame.defaultBackgroundArgb;
    row.bgRunInverse = false;
    row.bgRunExplicit = false;
  }

  void _emitDecorations(
    _RowBuildState row, {
    required double x,
    required int span,
  }) {
    final style = row.style;
    final right = x + _frame.cellWidth * span;

    final underlineColor = style.underlineColor;
    final color = underlineColor != null
        ? _state.theme
              .resolveColor(underlineColor, isForeground: true)
              .toARGB32()
        : row.foreground;

    if (style.underline != UnderlineStyle.none) {
      final entry = _atlas.addDecoration(style.underline);
      for (var i = 0; i < span; i++) {
        _sprites.underline.add(
          x + _frame.cellWidth * i,
          row.rowY,
          entry,
          _frame.inverseDpr,
          color,
        );
      }
    }

    if (style.strikethrough) {
      final strikeY = row.rowY + _frame.strikethroughPosition;
      _sprites.decoration.add(
        x,
        strikeY,
        right,
        strikeY + _frame.strikethroughThickness,
        row.foreground,
      );
    }

    if (style.overline) {
      final overY = row.rowY + _frame.overlinePosition;
      _sprites.decoration.add(
        x,
        overY,
        right,
        overY + _frame.underlineThickness,
        row.foreground,
      );
    }
  }

  void _finishBackgroundRun(_RowBuildState row) {
    _flushBackgroundRun(row, _frame.cols);
  }

  void _flushBackgroundRun(_RowBuildState row, int endCol) {
    if (!row.bgRunExplicit || row.bgRunStart >= endCol) return;
    _sprites.background.add(
      row.bgRunStart * _frame.cellWidth,
      row.rowY,
      endCol * _frame.cellWidth,
      row.rowBottom,
      _frame.resolveBgArgb(row.bgRunArgb, inverse: row.bgRunInverse),
    );
  }

  void _syncBackgroundRun(_RowBuildState row) {
    final sameRun =
        row.background == row.bgRunArgb &&
        row.backgroundExplicit == row.bgRunExplicit &&
        row.backgroundInverse == row.bgRunInverse;
    if (sameRun) return;

    _flushBackgroundRun(row, row.col);

    row.bgRunArgb = row.background;
    row.bgRunStart = row.col;
    row.bgRunInverse = row.backgroundInverse;
    row.bgRunExplicit = row.backgroundExplicit;
  }

  void _writeCell(CellIterator cell) {
    final row = _row;
    final span = cell.wide == .wide ? 2 : 1;
    final selected = _frame.isSelected(row.row, row.col);

    if (cell.styleId != row.prevStyleId || selected != row.prevSelected) {
      _foreground.flush(row);
      _styles.update(cell, selected: selected, row: row);
    }
    _syncBackgroundRun(row);

    if (!row.hidden) {
      final x = row.spriteX;
      _foreground.emit(cell, row, span: span);
      if (row.hasDecoration) {
        _emitDecorations(row, x: x, span: span);
      }
    } else {
      _foreground.flush(row);
    }

    if (span == 2) {
      _closeBackgroundSpan(row, span);
      cell.next();
    }
    row.advance(span, _frame.cellWidth);
  }
}
