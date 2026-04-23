import 'package:flterm/src/foundation/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cellFg = Color(0xFF112233);
  const cellBg = Color(0xFF445566);

  group('DynamicColor.fixed', () {
    test('resolve returns the fixed color regardless of cell colors', () {
      const color = DynamicColor.fixed(Color(0xFFAA00FF));
      expect(
        color.resolve(cellForeground: cellFg, cellBackground: cellBg),
        const Color(0xFFAA00FF),
      );
    });

    test('fixedColor exposes the RGB', () {
      expect(
        const DynamicColor.fixed(Color(0xFF123456)).fixedColor,
        const Color(0xFF123456),
      );
    });

    test('equality and hashCode', () {
      const a = DynamicColor.fixed(Color(0xFF123456));
      const b = DynamicColor.fixed(Color(0xFF123456));
      const c = DynamicColor.fixed(Color(0xFF654321));
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('DynamicColor.cellForeground', () {
    test('resolve returns the cell foreground', () {
      const color = DynamicColor.cellForeground();
      expect(
        color.resolve(cellForeground: cellFg, cellBackground: cellBg),
        cellFg,
      );
    });

    test('fixedColor returns null', () {
      expect(const DynamicColor.cellForeground().fixedColor, isNull);
    });

    test('all instances are equal', () {
      expect(
        const DynamicColor.cellForeground(),
        equals(const DynamicColor.cellForeground()),
      );
    });
  });

  group('DynamicColor.cellBackground', () {
    test('resolve returns the cell background', () {
      const color = DynamicColor.cellBackground();
      expect(
        color.resolve(cellForeground: cellFg, cellBackground: cellBg),
        cellBg,
      );
    });

    test('fixedColor returns null', () {
      expect(const DynamicColor.cellBackground().fixedColor, isNull);
    });
  });

  test('different variants are not equal', () {
    expect(
      const DynamicColor.fixed(Color(0xFF112233)),
      isNot(equals(const DynamicColor.cellForeground())),
    );
    expect(
      const DynamicColor.cellForeground(),
      isNot(equals(const DynamicColor.cellBackground())),
    );
  });
}
