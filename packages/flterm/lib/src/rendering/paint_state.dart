import 'dart:ui';

import 'package:libghostty/libghostty.dart' show Cursor;

import '../foundation.dart' show CellMetrics, TerminalSelection, TerminalTheme;
import 'atlas/glyph_atlas.dart';

/// Mutable state shared between [TerminalRenderBox] and all painters.
///
/// Written by the render box during state sync (start of paint). Read by
/// painters during the paint phase. Each painter holds a final reference
/// and never mutates this object.
///
/// Contains grid dimensions, device pixel ratio, resolved terminal
/// colors, selection state, cursor state, and faint text opacity.
class TerminalPaintState {
  TerminalTheme theme;
  CellMetrics metrics;

  var rows = 0;
  var cols = 0;
  var blinkVisible = true;

  /// Scale between Flutter's logical-pixel canvas and the physical
  /// pixels libghostty uses for size reports and Kitty graphics.
  var devicePixelRatio = 1.0;

  late int terminalForegroundArgb;
  late int terminalBackgroundArgb;

  /// Alpha byte (0-255) applied to faint text foregrounds.
  int faintAlpha;

  TerminalSelection? selection;
  Color selectionBackground;
  var viewportOffset = 0;

  var cursor = const Cursor();
  var cursorWide = false;
  var cursorFocused = true;
  var cursorColorArgb = 0xFFFFFFFF;
  GlyphEntry? cursorGlyphEntry;
  final cursorGlyphPaint = Paint();

  TerminalPaintState(this.theme, this.metrics)
    : selectionBackground = theme.selection.background ?? theme.foreground,
      faintAlpha = (theme.faintOpacity * 255).ceil() {
    terminalForegroundArgb = theme.foreground.toARGB32();
    terminalBackgroundArgb = theme.background.toARGB32();
  }

  void updateTheme(TerminalTheme newTheme) {
    theme = newTheme;
    selectionBackground = newTheme.selection.background ?? newTheme.foreground;
    faintAlpha = (newTheme.faintOpacity * 255).ceil();
  }
}
