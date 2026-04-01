@Tags(['ffi'])
library;

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('Terminal colors', () {
    late Terminal terminal;

    setUp(() => terminal = Terminal(cols: 80, rows: 24));

    tearDown(() => terminal.dispose());

    test('render state returns valid foreground, background, and palette', () {
      terminal.renderState.update();
      final colors = terminal.renderState.colors;
      expect(colors.foreground, isA<RgbColor>());
      expect(colors.background, isA<RgbColor>());
      expect(colors.palette, hasLength(256));
    });

    test('set and get foreground color', () {
      terminal.foreground = const RgbColor(255, 0, 0);
      expect(terminal.foreground, const RgbColor(255, 0, 0));
    });

    test('set and get background color', () {
      terminal.background = const RgbColor(0, 255, 0);
      expect(terminal.background, const RgbColor(0, 255, 0));
    });

    test('set and get cursor color', () {
      terminal.cursorColor = const RgbColor(0, 0, 255);
      expect(terminal.cursorColor, const RgbColor(0, 0, 255));
    });

    test('clearing colors returns null', () {
      terminal.foreground = const RgbColor(255, 0, 0);
      terminal.foreground = null;
      expect(terminal.foreground, isNull);

      terminal.background = const RgbColor(0, 255, 0);
      terminal.background = null;
      expect(terminal.background, isNull);

      terminal.cursorColor = const RgbColor(0, 0, 255);
      terminal.cursorColor = null;
      expect(terminal.cursorColor, isNull);
    });

    test('get palette returns 256 valid colors', () {
      final palette = terminal.palette;
      expect(palette, hasLength(256));
      for (final color in palette) {
        expect(color, isA<RgbColor>());
      }
    });

    test('set and get palette', () {
      final colors = List.generate(256, (i) => RgbColor(i, 0, 0));
      terminal.palette = colors;
      final result = terminal.palette;
      expect(result, hasLength(256));
      expect(result[0], const RgbColor(0, 0, 0));
      expect(result[128], const RgbColor(128, 0, 0));
      expect(result[255], const RgbColor(255, 0, 0));
    });

    test('reset palette to defaults', () {
      final original = terminal.palette;
      terminal.palette = List.generate(256, (i) => RgbColor(i, i, i));
      terminal.palette = null;
      expect(terminal.palette, original);
    });

    test('default color matches effective when no OSC override', () {
      terminal.foreground = const RgbColor(100, 100, 100);
      expect(terminal.foreground, const RgbColor(100, 100, 100));
      expect(terminal.foregroundDefault, const RgbColor(100, 100, 100));
    });
  });
}
