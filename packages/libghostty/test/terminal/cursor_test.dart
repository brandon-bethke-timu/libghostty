@Tags(['ffi'])
library;

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('CursorShape', () {
    test('has expected values', () {
      expect(
        CursorShape.values,
        containsAll([
          CursorShape.block,
          CursorShape.underline,
          CursorShape.bar,
          CursorShape.blockHollow,
        ]),
      );
    });
  });

  group('Cursor', () {
    test('default cursor', () {
      const cursor = Cursor();
      expect(cursor.row, 0);
      expect(cursor.col, 0);
      expect(cursor.visible, isTrue);
      expect(cursor.shape, CursorShape.block);
    });

    test('equality', () {
      const a = Cursor(row: 5, col: 10, shape: CursorShape.bar);
      const b = Cursor(row: 5, col: 10, shape: CursorShape.bar);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality across all properties', () {
      const base = Cursor(row: 5, col: 10);
      expect(base, isNot(equals(const Cursor(row: 6, col: 10))));
      expect(
        base,
        isNot(equals(const Cursor(row: 5, col: 10, visible: false))),
      );
      expect(
        base,
        isNot(
          equals(const Cursor(row: 5, col: 10, shape: CursorShape.underline)),
        ),
      );
    });

    test('copyWith', () {
      const cursor = Cursor(row: 5, col: 10, shape: CursorShape.bar);
      final moved = cursor.copyWith(row: 6, col: 11);
      expect(moved.row, 6);
      expect(moved.col, 11);
      expect(moved.shape, CursorShape.bar);
      expect(moved.visible, isTrue);
    });
  });
}
