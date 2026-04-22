@Tags(['ffi', 'golden'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/rendering.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

import '../helpers/font_loader.dart';

void main() {
  setUpAll(loadBundledFonts);

  group('Background opacity', () {
    final baseTheme = TerminalTheme.dark().copyWith(
      fontFamilyFallback: bundledFontFamilyFallback,
    );

    testWidgets('opacity 1.0 paints fully opaque over backdrop', (
      tester,
    ) async {
      await _pumpScene(tester, baseTheme, content: 'Hello');
      await _expectGolden('transparent_baseline.png');
    });

    testWidgets('opacity 0.5 leaves explicit-bg cells opaque by default', (
      tester,
    ) async {
      await _pumpScene(
        tester,
        baseTheme.copyWith(backgroundOpacity: 0.5),
        content: 'default bg\r\n${_explicitBgAnsi}explicit bg\x1b[0m',
      );
      await _expectGolden('transparent_default_cells.png');
    });

    testWidgets('opacity 0.5 with cells=true tints explicit bgs too', (
      tester,
    ) async {
      await _pumpScene(
        tester,
        baseTheme.copyWith(
          backgroundOpacity: 0.5,
          backgroundOpacityCells: true,
        ),
        content: 'default bg\r\n${_explicitBgAnsi}explicit bg\x1b[0m',
      );
      await _expectGolden('transparent_all_cells.png');
    });

    testWidgets('inverse cells stay opaque even with cells=true', (
      tester,
    ) async {
      await _pumpScene(
        tester,
        baseTheme.copyWith(
          backgroundOpacity: 0.5,
          backgroundOpacityCells: true,
        ),
        content: 'normal\r\n\x1b[7minverse\x1b[0m',
      );
      await _expectGolden('transparent_inverse.png');
    });

    testWidgets('explicit bg matching theme.background stays opaque', (
      tester,
    ) async {
      // Explicit bg whose RGB equals the theme default must still emit
      // an opaque rect so nvim/tmux repaints don't leak the backdrop.
      await _pumpScene(
        tester,
        baseTheme.copyWith(backgroundOpacity: 0.5),
        content: 'default bg\r\n\x1b[48;2;29;31;33mexplicit default\x1b[0m',
      );
      await _expectGolden('transparent_explicit_default.png');
    });
  });
}

const _backdrop = Color(0xFFFF2030);
const _cols = 20;
const _explicitBgAnsi = '\x1b[48;2;40;200;80m';
const _metrics = CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12);
const _rows = 5;

final _sceneKey = GlobalKey();

Future<void> _expectGolden(String name) {
  return expectLater(find.byKey(_sceneKey), matchesGoldenFile('goldens/$name'));
}

Future<void> _pumpScene(
  WidgetTester tester,
  TerminalTheme theme, {
  required String content,
}) async {
  final terminal = Terminal(cols: _cols, rows: _rows);
  addTearDown(terminal.dispose);
  terminal.writeUtf8(content);

  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: _cols * _metrics.cellWidth,
            maxHeight: _rows * _metrics.cellHeight,
          ),
          // Wrapping in a RepaintBoundary so the golden captures the
          // full composite (backdrop + alpha-tinted ColoredBox + renderer
          // layer), not just the inner renderer's bare layer.
          child: RepaintBoundary(
            key: _sceneKey,
            child: ColoredBox(
              color: _backdrop,
              child: ColoredBox(
                color: theme.background.withValues(
                  alpha: theme.backgroundOpacity,
                ),
                child: TerminalRenderer(
                  terminal: terminal,
                  theme: theme,
                  metrics: _metrics,
                  offset: ViewportOffset.zero(),
                  renderObserver: const _Observer(),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Observer implements TerminalRenderObserver {
  const _Observer();

  @override
  bool get hasFocus => true;

  @override
  TerminalSelection? get selection => null;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

extension on Terminal {
  void writeUtf8(String text) => write(Uint8List.fromList(utf8.encode(text)));
}
