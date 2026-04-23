import 'package:flterm/src/foundation/generate_256_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generate256Color', () {
    test('returns exactly 256 entries', () {
      final result = generate256Color(
        base: _ansiColors,
        background: _bg,
        foreground: _fg,
      );
      expect(result.length, 256);
    });

    test('preserves base 16 colors in indices 0–15', () {
      final result = generate256Color(
        base: _ansiColors,
        background: _bg,
        foreground: _fg,
      );
      for (var i = 0; i < 16; i++) {
        expect(result[i], _ansiColors[i], reason: 'index $i');
      }
    });

    test('cube corner (0,0,0) at index 16 equals background', () {
      // ri=gi=bi=0 → every lerp returns its first arg → base8[0] = bg.
      final result = generate256Color(
        base: _ansiColors,
        background: _bg,
        foreground: _fg,
      );
      expect(result[16], _bg);
    });

    test('cube corner (5,5,5) at index 231 equals foreground', () {
      // ri=gi=bi=5 → every lerp returns its second arg → base8[7] = fg.
      final result = generate256Color(
        base: _ansiColors,
        background: _bg,
        foreground: _fg,
      );
      expect(result[231], _fg);
    });

    test('grayscale ramp (232–255) is monotonically non-darkening', () {
      double luma(Color c) =>
          0.299 * c.r * 255 + 0.587 * c.g * 255 + 0.114 * c.b * 255;
      final result = generate256Color(
        base: _ansiColors,
        background: _bg,
        foreground: _fg,
      );
      for (var i = 233; i < 256; i++) {
        expect(
          luma(result[i]),
          greaterThanOrEqualTo(luma(result[i - 1])),
          reason: 'index $i should not be darker than ${i - 1}',
        );
      }
    });

    test('light theme without harmonious swaps orientation so cube runs '
        'dark→light', () {
      // For a light theme bg is brighter than fg; with harmonious=false
      // (default) bg/fg are swapped internally so corner (0,0,0) is the
      // darker of the two — which is fg.
      const lightBg = Color(0xFFF0F0F0);
      const lightFg = Color(0xFF1E1E1E);
      final result = generate256Color(
        base: _ansiColors,
        background: lightBg,
        foreground: lightFg,
      );
      expect(result[16], lightFg);
    });

    test('skip set preserves specified base indices unchanged', () {
      final customBase = List<Color>.from(_ansiColors);
      const custom = Color(0xFF7B2D43);
      customBase[0] = custom;
      final result = generate256Color(
        base: customBase,
        background: _bg,
        foreground: _fg,
        skip: {0},
      );
      expect(result[0], custom);
      expect(result[16], _bg);
      expect(result[231], _fg);
    });

    test('requires exactly 16 base colors', () {
      expect(
        () => generate256Color(
          base: const [Color(0xFF000000)],
          background: _bg,
          foreground: _fg,
        ),
        throwsArgumentError,
      );
    });
  });
}

const _bg = Color(0xFF181818);
const _fg = Color(0xFFD8D8D8);

const _ansiColors = [
  Color(0xFF282828),
  Color(0xFFCC4242),
  Color(0xFF66994C),
  Color(0xFFE5B566),
  Color(0xFF668ECC),
  Color(0xFFB266B2),
  Color(0xFF4CB2B2),
  Color(0xFFAAAAAA),
  Color(0xFF505050),
  Color(0xFFE66464),
  Color(0xFF8CBE6E),
  Color(0xFFF0C878),
  Color(0xFF82A0DC),
  Color(0xFFC882C8),
  Color(0xFF64C8C8),
  Color(0xFFDCDCDC),
];
