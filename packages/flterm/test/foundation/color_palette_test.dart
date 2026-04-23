import 'package:flterm/src/foundation/color_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ColorPalette (default / xterm cube)', () {
    late ColorPalette palette;

    setUp(
      () => palette = ColorPalette(
        ansiColors: _ansiColors,
        background: _bg,
        foreground: _fg,
      ),
    );

    test('exposes background, foreground, and ansiColors as fields', () {
      expect(palette.background, _bg);
      expect(palette.foreground, _fg);
      expect(palette.ansiColors, _ansiColors);
    });

    test('indices 0–15 match the provided ANSI colors', () {
      for (var i = 0; i < 16; i++) {
        expect(palette[i], _ansiColors[i], reason: 'index $i');
      }
    });

    test('index 16 is xterm cube black (0,0,0)', () {
      expect(palette[16], const Color(0xFF000000));
    });

    test('index 231 is xterm cube white (5,5,5)', () {
      expect(palette[231], const Color(0xFFFFFFFF));
    });

    test('index 196 is xterm cube pure red (5,0,0)', () {
      expect(palette[196], const Color(0xFFFF0000));
    });

    test('grayscale ramp values follow the standard formula', () {
      for (var i = 232; i < 256; i++) {
        final v = (i - 232) * 10 + 8;
        expect(palette[i], Color.fromARGB(255, v, v, v), reason: 'index $i');
      }
    });

    test('all 256 indices return opaque Colors', () {
      for (var i = 0; i < 256; i++) {
        expect((palette[i].a * 255.0).round(), 255, reason: 'index $i');
      }
    });

    test('equality and hashCode include background and foreground', () {
      final other = ColorPalette(
        ansiColors: _ansiColors,
        background: _bg,
        foreground: _fg,
      );
      expect(palette, equals(other));
      expect(palette.hashCode, other.hashCode);

      final differentBg = ColorPalette(
        ansiColors: _ansiColors,
        background: const Color(0xFF111111),
        foreground: _fg,
      );
      expect(palette, isNot(equals(differentBg)));
    });

    test('copyWith rebuilds the palette in the same (xterm cube) mode', () {
      final newBg = palette.copyWith(background: const Color(0xFF111111));
      expect(newBg.background, const Color(0xFF111111));
      // Still xterm cube: index 16 stays pure black regardless of bg change.
      expect(newBg[16], const Color(0xFF000000));
    });

    test('requires exactly 16 ANSI colors', () {
      expect(
        () => ColorPalette(
          ansiColors: const [Color(0xFF000000)],
          background: _bg,
          foreground: _fg,
        ),
        throwsArgumentError,
      );
    });
  });

  group('ColorPalette.generated (theme-derived)', () {
    late ColorPalette palette;

    setUp(
      () => palette = ColorPalette.generated(
        ansiColors: _ansiColors,
        background: _bg,
        foreground: _fg,
      ),
    );

    test('indices 0–15 match the provided ANSI colors', () {
      for (var i = 0; i < 16; i++) {
        expect(palette[i], _ansiColors[i], reason: 'index $i');
      }
    });

    test('cube corner (0,0,0) at index 16 equals background', () {
      expect(palette[16], _bg);
    });

    test('cube corner (5,5,5) at index 231 equals foreground', () {
      expect(palette[231], _fg);
    });

    test('grayscale ramp (232–255) is monotonically non-darkening', () {
      double luma(Color c) =>
          0.299 * c.r * 255 + 0.587 * c.g * 255 + 0.114 * c.b * 255;
      for (var i = 233; i < 256; i++) {
        expect(
          luma(palette[i]),
          greaterThanOrEqualTo(luma(palette[i - 1])),
          reason: 'index $i should not be darker than ${i - 1}',
        );
      }
    });

    test('copyWith preserves the generated mode', () {
      final modified = palette.copyWith(background: const Color(0xFF111111));
      // Still generated: index 16 tracks the new bg, not pure xterm black.
      expect(modified[16], const Color(0xFF111111));
    });

    test('requires exactly 16 ANSI colors', () {
      expect(
        () => ColorPalette.generated(
          ansiColors: const [Color(0xFF000000)],
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
