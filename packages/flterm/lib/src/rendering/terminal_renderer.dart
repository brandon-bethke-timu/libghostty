import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:libghostty/libghostty.dart';

import '../foundation.dart';
import 'atlas/glyph_atlas.dart';
import 'atlas/sprite_buffer.dart';
import 'kitty_image_cache.dart';
import 'paint_state.dart';
import 'painters/background_painter.dart';
import 'painters/cursor_painter.dart';
import 'painters/decoration_painter.dart';
import 'painters/emoji_painter.dart';
import 'painters/kitty_graphics_painter.dart';
import 'painters/selection_painter.dart';
import 'painters/terminal_text_painter.dart';
import 'painters/underline_painter.dart';
import 'sprite_builder.dart';

/// Pre-fetched cell data at the cursor position.
///
/// Snapshot of the cell under the cursor, taken during state sync so the
/// cursor painter can render the character glyph inside a block cursor
/// without accessing the terminal during paint.
class CursorCell {
  /// Text content of the cell (grapheme cluster).
  final String content;

  /// Style attributes (bold, italic, blink, inverse, etc.).
  final Style style;

  /// Whether this is a wide (2-cell) character.
  final bool wide;

  const CursorCell(this.content, this.style, {required this.wide});
}

/// Renders a terminal screen with cell backgrounds, styled text, cursors,
/// and selection overlays.
///
/// This is the core rendering widget used internally by [TerminalView].
/// It owns a [TerminalRenderBox] that orchestrates layout (grid sizing,
/// terminal resize), state sync (reading cells, building sprites), and
/// painting (six painters in z-order: background, text, cursor, emoji,
/// decorations, selection).
///
/// Sizing is determined by the parent constraints and cell metrics: the
/// widget computes how many columns and rows fit, then sizes itself to
/// exactly that grid. When the grid dimensions change, the terminal is
/// resized and [onResize] fires.
///
/// ```dart
/// TerminalRenderer(
///   terminal: myTerminal,
///   theme: TerminalTheme.dark(),
///   metrics: measureCellMetrics(fontFamily: 'monospace', fontSize: 14),
///   offset: ViewportOffset.zero(),
///   renderObserver: controller,
/// )
/// ```
class TerminalRenderer extends LeafRenderObjectWidget {
  /// The terminal whose screen is rendered.
  final Terminal terminal;

  /// Visual style applied to the terminal.
  ///
  /// When changed, theme colors are pushed to the terminal (foreground,
  /// background, palette, cursor color), the glyph atlas is updated if
  /// font properties changed, and a full repaint is scheduled.
  final TerminalTheme theme;

  /// Cell pixel dimensions used for grid sizing and coordinate conversion.
  ///
  /// When changed, the glyph atlas is cleared and layout is recalculated.
  /// A grid dimension change triggers terminal resize and [onResize].
  final CellMetrics metrics;

  /// Scroll offset provided by a [Scrollable] ancestor.
  ///
  /// At `pixels == 0`, the oldest scrollback row is visible.
  /// At `pixels == maxScrollExtent`, the live screen is visible.
  final ViewportOffset offset;

  /// Observable state for selection and focus.
  ///
  /// Listened to by the render box. Changes trigger a repaint to update
  /// selection highlights and cursor appearance (filled vs hollow).
  final TerminalRenderObserver renderObserver;

  /// Whether the cursor blink is currently in the visible phase.
  ///
  /// When false, the cursor and blinking text (SGR 5) are hidden.
  /// Toggled by a timer in [TerminalView].
  final bool blinkVisible;

  /// Called when the terminal grid dimensions change during layout.
  ///
  /// Fires after the terminal has been resized. Use this to notify the
  /// backend (PTY, SSH) of the new dimensions.
  final OnResize? onResize;

  const TerminalRenderer({
    super.key,
    required this.terminal,
    required this.theme,
    required this.metrics,
    required this.offset,
    required this.renderObserver,
    this.blinkVisible = true,
    this.onResize,
  });

  @override
  TerminalRenderBox createRenderObject(BuildContext context) {
    return TerminalRenderBox(
      theme: theme,
      offset: offset,
      metrics: metrics,
      terminal: terminal,
      onResize: onResize,
      blinkVisible: blinkVisible,
      renderObserver: renderObserver,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<Terminal>('terminal', terminal))
      ..add(DiagnosticsProperty<TerminalTheme>('theme', theme))
      ..add(DiagnosticsProperty<CellMetrics>('metrics', metrics))
      ..add(
        DiagnosticsProperty<TerminalSelection?>(
          'selection',
          renderObserver.selection,
        ),
      )
      ..add(DiagnosticsProperty<ViewportOffset>('offset', offset))
      ..add(
        FlagProperty(
          'blinkVisible',
          value: blinkVisible,
          ifTrue: 'blink visible',
        ),
      );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    TerminalRenderBox renderObject,
  ) {
    renderObject
      ..terminal = terminal
      ..theme = theme
      ..offset = offset
      ..metrics = metrics
      ..onResize = onResize
      ..renderObserver = renderObserver
      ..blinkVisible = blinkVisible;
  }
}

/// Render object orchestrating terminal layout, state sync, and painting.
///
/// Three phases per frame:
///
/// 1. **Layout**: computes grid size from constraints and [CellMetrics],
///    configures the glyph atlas for the current DPR, resizes the terminal
///    if the grid changed, and updates scroll extents.
///
/// 2. **Sync** (start of paint): snapshots terminal cells, resolves colors
///    (including OSC 10/11 overrides, bold-is-bright, inverse, faint),
///    builds sprite data for text/backgrounds/decorations, resolves
///    the cursor cell glyph, and collects Kitty graphics placements.
///
/// 3. **Paint**: delegates to painters in z-order: kitty-below-bg,
///    background, kitty-below-text, underlines, text, cursor, emoji,
///    decorations, kitty-above-text, selection. Each painter reads
///    only from pre-built sprite data and cached images, with zero
///    terminal access.
///
/// Created and managed by [TerminalRenderer]. Not intended for direct use.
class TerminalRenderBox extends RenderBox {
  Terminal _terminal;
  ViewportOffset _offset;
  TerminalRenderObserver _renderObserver;
  OnResize? _onResize;
  var _performingLayout = false;
  var _needsContentSync = false;
  var _needsSpriteRebuild = false;
  var _stickToBottom = true;
  var _lastScrollbackRows = 0;
  var _lastCursor = const Cursor();
  CursorCell? _lastCursorCell;

  late final GlyphAtlas _atlas;
  late final SpriteBuffer _sprites;
  late final SpriteBuilder _spriteBuilder;

  late final EmojiPainter _emojiPainter;
  late final CursorPainter _cursorPainter;
  late final TerminalPaintState _paintState;
  late final TerminalTextPainter _textPainter;
  late final SelectionPainter _selectionPainter;
  late final UnderlinePainter _underlinePainter;
  late final BackgroundPainter _backgroundPainter;
  late final DecorationPainter _decorationPainter;
  late final KittyImageCache _kittyImageCache;
  late final KittyGraphicsPainter _kittyBelowBgPainter;
  late final KittyGraphicsPainter _kittyBelowTextPainter;
  late final KittyGraphicsPainter _kittyAbovePainter;
  final List<KittyPlacementSnapshot> _kittyPlacements = [];

  TerminalRenderBox({
    required Terminal terminal,
    required TerminalTheme theme,
    required CellMetrics metrics,
    required ViewportOffset offset,
    required TerminalRenderObserver renderObserver,
    bool blinkVisible = true,
    OnResize? onResize,
  }) : _terminal = terminal,
       _offset = offset,
       _onResize = onResize,
       _renderObserver = renderObserver {
    _paintState = TerminalPaintState(theme, metrics)
      ..blinkVisible = blinkVisible
      ..selection = renderObserver.selection
      ..cursorFocused = renderObserver.hasFocus;
    _atlas = GlyphAtlas(
      fontSize: theme.fontSize,
      fontWeight: theme.fontWeight,
      fontFamily: theme.fontFamily,
      fontFamilyFallback: theme.fontFamilyFallback,
    );

    _sprites = SpriteBuffer();
    _spriteBuilder = SpriteBuilder(_atlas, _sprites, _paintState);
    _backgroundPainter = BackgroundPainter(_paintState, _sprites);
    _textPainter = TerminalTextPainter(_atlas, _sprites.wide, _sprites.regular);
    _cursorPainter = CursorPainter(_paintState, _atlas);
    _emojiPainter = EmojiPainter(_atlas, _sprites);
    _underlinePainter = UnderlinePainter(_atlas, _sprites);
    _decorationPainter = DecorationPainter(_sprites);
    _selectionPainter = SelectionPainter(_paintState);
    _kittyImageCache = KittyImageCache(onImageReady: markNeedsPaint);
    _kittyBelowBgPainter = KittyGraphicsPainter(
      state: _paintState,
      cache: _kittyImageCache,
      snapshots: _kittyPlacements,
      layer: KittyPaintLayer.belowBg,
    );
    _kittyBelowTextPainter = KittyGraphicsPainter(
      state: _paintState,
      cache: _kittyImageCache,
      snapshots: _kittyPlacements,
      layer: KittyPaintLayer.belowText,
    );
    _kittyAbovePainter = KittyGraphicsPainter(
      state: _paintState,
      cache: _kittyImageCache,
      snapshots: _kittyPlacements,
      layer: KittyPaintLayer.aboveText,
    );

    _applyThemeColors();
  }

  bool get blinkVisible => _paintState.blinkVisible;

  set blinkVisible(bool value) {
    if (_paintState.blinkVisible == value) return;
    _paintState.blinkVisible = value;
    _needsSpriteRebuild = true;
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => true;

  set metrics(CellMetrics value) {
    if (_paintState.metrics == value) return;
    _paintState.metrics = value;
    _atlas.clear();
    markNeedsLayout();
  }

  set offset(ViewportOffset value) {
    if (_offset == value) return;
    if (attached) _offset.removeListener(_onScroll);
    _offset = value;
    if (attached) _offset.addListener(_onScroll);
    markNeedsLayout();
  }

  set onResize(OnResize? value) => _onResize = value;

  set renderObserver(TerminalRenderObserver value) {
    if (_renderObserver == value) return;
    if (attached) _renderObserver.removeListener(_onRenderObserverChanged);
    _renderObserver = value;
    if (attached) _renderObserver.addListener(_onRenderObserverChanged);
    _onRenderObserverChanged();
  }

  set terminal(Terminal value) {
    if (_terminal == value) return;
    if (attached) _terminal.removeListener(_onTerminalChanged);
    _terminal = value;
    if (attached) _terminal.addListener(_onTerminalChanged);
    _applyThemeColors();
    _needsContentSync = true;
    markNeedsLayout();
  }

  TerminalTheme get theme => _paintState.theme;

  /// Updates the theme, clearing the atlas only if font properties changed.
  ///
  /// Color-only changes (palette, foreground, background) use markNeedsPaint
  /// which repaints with the existing atlas. Font changes (size, weight,
  /// family) use markNeedsLayout which reconfigures the atlas, re-measures
  /// the grid, and pre-seeds glyphs.
  set theme(TerminalTheme value) {
    if (_paintState.theme == value) return;
    final fontChanged = _atlas.updateFont(
      fontSize: value.fontSize,
      fontWeight: value.fontWeight,
      fontFamily: value.fontFamily,
      fontFamilyFallback: value.fontFamilyFallback,
    );
    _paintState.updateTheme(value);
    _applyThemeColors();
    _needsContentSync = true;

    if (fontChanged) {
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _offset.addListener(_onScroll);
    _renderObserver.addListener(_onRenderObserverChanged);
    _terminal.addListener(_onTerminalChanged);
    markNeedsLayout();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('cols', _paintState.cols))
      ..add(IntProperty('rows', _paintState.rows))
      ..add(DiagnosticsProperty<TerminalTheme>('theme', _paintState.theme))
      ..add(DiagnosticsProperty<CellMetrics>('metrics', _paintState.metrics))
      ..add(
        DiagnosticsProperty<TerminalSelection?>(
          'selection',
          _paintState.selection,
        ),
      )
      ..add(
        FlagProperty(
          'blinkVisible',
          value: _paintState.blinkVisible,
          ifTrue: 'cursor visible',
        ),
      )
      ..add(
        DiagnosticsProperty<TerminalRenderObserver?>(
          'renderObserver',
          _renderObserver,
        ),
      );
  }

  @override
  void detach() {
    _offset.removeListener(_onScroll);
    _renderObserver.removeListener(_onRenderObserverChanged);
    _terminal.removeListener(_onTerminalChanged);
    _atlas.dispose();
    _paintState.rows = 0;
    _paintState.cols = 0;
    super.detach();
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    _syncTerminalState();

    final canvas = context.canvas;

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    _kittyBelowBgPainter.paint(canvas);
    _backgroundPainter.paint(canvas);
    _kittyBelowTextPainter.paint(canvas);
    // Underlines drawn before text so descender glyphs cover the underline
    // at intersections.
    _underlinePainter.paint(canvas);
    _textPainter.paint(canvas);
    _cursorPainter.paint(canvas);
    _emojiPainter.paint(canvas);
    // Strikethrough and overline drawn after text so strikethrough visibly
    // crosses through glyphs.
    _decorationPainter.paint(canvas);
    _kittyAbovePainter.paint(canvas);
    _selectionPainter.paint(canvas);
    canvas.restore();
  }

  @override
  void performLayout() {
    _performingLayout = true;

    final maxW = constraints.hasBoundedWidth ? constraints.maxWidth : 0.0;
    final maxH = constraints.hasBoundedHeight ? constraints.maxHeight : 0.0;
    final (newCols, newRows) = _paintState.metrics.gridSize(maxW, maxH);

    size = constraints.constrain(
      Size(
        newCols * _paintState.metrics.cellWidth,
        newRows * _paintState.metrics.cellHeight,
      ),
    );

    final dpr =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final atlasReconfigured = _atlas.configure(
      dpr: dpr,
      metrics: _paintState.metrics,
    );

    final gridChanged =
        newCols != _paintState.cols || newRows != _paintState.rows;
    if (gridChanged) {
      _paintState.cols = newCols;
      _paintState.rows = newRows;
      _paintState.devicePixelRatio = dpr;
      _sprites.resize(newRows * newCols);
      if (newCols > 0 && newRows > 0) {
        // Cell size is reported in physical pixels so size-report
        // escapes and Kitty graphics geometry match a native terminal
        // at the same DPI.
        _terminal.resize(
          cols: newCols,
          rows: newRows,
          cellWidthPx: (_paintState.metrics.cellWidth * dpr).round(),
          cellHeightPx: (_paintState.metrics.cellHeight * dpr).round(),
        );
        _onResize?.call(newCols, newRows);
      }
    } else if (_paintState.devicePixelRatio != dpr) {
      _paintState.devicePixelRatio = dpr;
    }

    _syncScrollLayout();

    // Only rebuild sprites when grid dimensions or atlas changed.
    // Sub-cell pixel resize steps skip the expensive sprite build.
    if (gridChanged || atlasReconfigured) _markTerminalDirty();

    _performingLayout = false;
  }

  void _applyThemeColors() {
    _terminal.foreground = _paintState.theme.foreground.toRgbColor();
    _terminal.background = _paintState.theme.background.toRgbColor();
    _terminal.cursorColor = _paintState.theme.cursor.color?.toRgbColor();
    _terminal.palette = [
      for (var i = 0; i < 256; i++) _paintState.theme.palette[i].toRgbColor(),
    ];
  }

  void _markTerminalDirty() {
    _needsContentSync = true;
    markNeedsPaint();
  }

  void _onRenderObserverChanged() {
    _paintState.selection = _renderObserver.selection;
    _paintState.cursorFocused = _renderObserver.hasFocus;
    _resolveCursorGlyph();
    markNeedsPaint();
  }

  void _onScroll() {
    if (_performingLayout) return;
    if (_paintState.rows == 0 || _paintState.metrics.cellHeight <= 0) return;

    final scrollbar = _terminal.scrollbar;
    final scrollbackLen = scrollbar.total - scrollbar.visible;
    if (scrollbackLen <= 0) return;

    final cellHeight = _paintState.metrics.cellHeight;
    final maxExtent = scrollbackLen * cellHeight;
    final pixels = _offset.pixels.clamp(0.0, maxExtent);

    _stickToBottom = maxExtent <= 0 || pixels >= maxExtent - cellHeight;

    final targetOffset = (pixels / cellHeight).floor();
    final delta = targetOffset - scrollbar.offset;

    if (delta == 0) return;

    _terminal.scrollViewport(delta);
    _markTerminalDirty();
  }

  // Handles terminal change notifications.
  //
  // When scrollback length changes, a layout pass is needed because scroll
  // extents must be recalculated. For normal output (same scrollback
  // length), only a repaint is needed.
  void _onTerminalChanged() {
    if (_paintState.rows == 0 || _performingLayout) return;

    if (_terminal.scrollbackRows != _lastScrollbackRows) {
      _needsContentSync = true;
      markNeedsLayout();
      return;
    }

    _markTerminalDirty();
  }

  void _resolveCursor(RenderState renderState, Scrollbar scrollbar) {
    final cursor = renderState.cursor;
    final scrollbackLen = scrollbar.total - scrollbar.visible;
    final inViewport =
        cursor.visible &&
        (scrollbackLen <= 0 || scrollbar.offset >= scrollbackLen) &&
        cursor.row >= 0 &&
        cursor.row < _paintState.rows &&
        cursor.col >= 0 &&
        cursor.col < _paintState.cols;

    if (!inViewport) {
      _lastCursor = cursor;
      _lastCursorCell = null;
      _paintState.cursor = cursor.copyWith(visible: false);
      _paintState.cursorWide = false;
      _paintState.cursorGlyphEntry = null;
      return;
    }

    var col = cursor.col;
    if (cursor.wideTail && col > 0) col -= 1;
    final effectiveCursor = col != cursor.col
        ? cursor.copyWith(col: col)
        : cursor;
    final ref = _terminal.gridRefAt(col: col, row: cursor.row);
    final cursorCell = CursorCell(ref.content, ref.style, wide: ref.isWide);
    ref.dispose();

    _lastCursor = effectiveCursor;
    _lastCursorCell = cursorCell;
    _paintState.cursor = effectiveCursor;
    _paintState.cursorWide = cursorCell.wide;
    _resolveCursorGlyph();
  }

  // Builds the block cursor glyph from cached cursor cell data.
  // Called after cursor resolution and on focus changes.
  void _resolveCursorGlyph() {
    _paintState.cursorGlyphEntry = null;
    final cell = _lastCursorCell;
    if (cell == null ||
        !_paintState.cursorFocused ||
        _lastCursor.shape != CursorShape.block) {
      return;
    }
    final style = cell.style;
    if (cell.content.isEmpty ||
        style.invisible ||
        (style.blink && !_paintState.blinkVisible)) {
      return;
    }
    _paintState.cursorGlyphEntry = _atlas.add((
      text: cell.content,
      bold: style.bold,
      italic: style.italic,
    ), span: cell.wide ? 2 : 1);

    // The glyph shows in the terminal background color so it contrasts
    // with the cursor (which uses the terminal foreground / cursor color).
    // This matches standard terminal behavior: the block cursor always
    // inverts to bg/fg regardless of the cell's own styling.
    _paintState.cursorGlyphPaint.colorFilter = ColorFilter.mode(
      Color(_paintState.terminalBackgroundArgb),
      BlendMode.modulate,
    );
  }

  // Maintains scroll position and content dimensions.
  //
  // "Stick to bottom" keeps the viewport pinned to the latest output,
  // which is the normal mode when the user hasn't scrolled up. Once the
  // user scrolls away from the bottom, new output no longer forces the
  // viewport down. Stick-to-bottom re-engages when the user scrolls
  // back to within one cell of the bottom edge.
  void _syncScrollLayout() {
    _offset.applyViewportDimension(size.height);

    if (_terminal.activeScreen == .alternate) {
      _offset.applyContentDimensions(0, 0);
      _lastScrollbackRows = 0;
      _stickToBottom = true;
      return;
    }

    final scrollbar = _terminal.scrollbar;
    final scrollbackLen = scrollbar.total - scrollbar.visible;
    final cellHeight = _paintState.metrics.cellHeight;
    final maxExtent = scrollbackLen * cellHeight;

    // Detect if the terminal was scrolled to bottom externally.
    if (!_stickToBottom &&
        scrollbackLen > 0 &&
        scrollbar.offset >= scrollbackLen) {
      _stickToBottom = true;
    }

    if (_stickToBottom && maxExtent > 0) {
      final correction = maxExtent - _offset.pixels;
      if (correction.abs() > 0.01) _offset.correctBy(correction);
      if (scrollbar.offset < scrollbackLen) _terminal.scrollToBottom();
    }
    _offset.applyContentDimensions(0, maxExtent);
    _lastScrollbackRows = scrollbackLen;
    _stickToBottom = maxExtent <= 0 || _offset.pixels >= maxExtent - cellHeight;
  }

  // Reads terminal state and builds sprites for the current frame.
  //
  // Called at the start of paint(). After this method returns, all painters
  // read only from pre-built sprite data with zero terminal access.
  //
  // Content sync: snapshots the terminal, reads colors, builds sprites,
  // resolves cursor. Triggered by terminal output, scroll, theme, or resize.
  //
  // Sprite-only rebuild: re-iterates the existing snapshot to rebuild
  // sprites without FFI overhead. Triggered by blink visibility changes
  // when no content change is pending.
  void _syncTerminalState() {
    if (_paintState.rows == 0) return;

    if (_needsContentSync) {
      _needsContentSync = false;
      _needsSpriteRebuild = false;

      final renderState = _terminal.renderState;
      renderState.update();

      final scrollbar = _terminal.scrollbar;
      _paintState.viewportOffset = scrollbar.offset;

      _paintState.terminalForegroundArgb =
          _terminal.foreground?.toArgb32 ??
          _paintState.theme.foreground.toARGB32();
      _paintState.terminalBackgroundArgb =
          _terminal.background?.toArgb32 ??
          _paintState.theme.background.toARGB32();
      _paintState.cursorColorArgb =
          _terminal.cursorColor?.toArgb32 ?? _paintState.terminalForegroundArgb;

      _spriteBuilder.build(renderState);
      renderState.markClean();

      _resolveCursor(renderState, scrollbar);
    } else if (_needsSpriteRebuild) {
      _needsSpriteRebuild = false;

      final renderState = _terminal.renderState;
      renderState.resetIteration();
      _spriteBuilder.build(renderState);
    }

    _syncKittyPlacements();
  }

  void _syncKittyPlacements() {
    _kittyPlacements.clear();
    final graphics = _terminal.kittyGraphics;
    if (graphics == null) return;

    final cellWidth = _paintState.metrics.cellWidth;
    final cellHeight = _paintState.metrics.cellHeight;
    // Placement geometry is reported in physical pixels, matching the
    // cell size we report at resize. Convert back to logical pixels for
    // the Flutter canvas.
    final dpr = _paintState.devicePixelRatio;
    final liveIds = <int>{};
    for (final placement in graphics.placements()) {
      final info = placement.renderInfo;
      if (!info.viewportVisible) continue;
      if (info.pixelWidth == 0 || info.pixelHeight == 0) continue;

      final image = graphics.image(placement.imageId);
      if (image == null) continue;
      liveIds.add(placement.imageId);
      _kittyImageCache.lookup(image);

      _kittyPlacements.add(
        KittyPlacementSnapshot(
          imageId: placement.imageId,
          dst: Rect.fromLTWH(
            info.viewportCol * cellWidth + placement.xOffset / dpr,
            info.viewportRow * cellHeight + placement.yOffset / dpr,
            info.pixelWidth / dpr,
            info.pixelHeight / dpr,
          ),
          src: Rect.fromLTWH(
            info.sourceX.toDouble(),
            info.sourceY.toDouble(),
            info.sourceWidth.toDouble(),
            info.sourceHeight.toDouble(),
          ),
          z: placement.z,
        ),
      );
    }
    // Sort once so each layer painter can filter in a single pass.
    // Equal-z placements keep storage iteration order.
    _kittyPlacements.sort((a, b) => a.z.compareTo(b.z));
    _kittyImageCache.evict(liveIds);
  }
}

extension on Color {
  RgbColor toRgbColor() => RgbColor(
    (r * 255.0).round().clamp(0, 255),
    (g * 255.0).round().clamp(0, 255),
    (b * 255.0).round().clamp(0, 255),
  );
}
