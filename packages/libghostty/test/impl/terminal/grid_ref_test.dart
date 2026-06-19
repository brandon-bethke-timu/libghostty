@Tags(['ffi'])
library;

import 'dart:typed_data' show Uint8List;

import 'package:libghostty/libghostty.dart'
    show CellWidth, GridRef, InvalidValueException, Style, Terminal;
import 'package:test/test.dart';

void main() {
  group('GridRef', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: 80, rows: 24);
      terminal.write(Uint8List.fromList('Hello'.codeUnits));
    });

    tearDown(() {
      terminal.dispose();
    });

    group('at', () {
      test('returns content for a resolved cell', () {
        final ref = GridRef.at(terminal, col: 0, row: 0);
        addTearDown(ref.dispose);

        final result = ref.content;

        expect(result, 'H');
      });

      test('returns empty content for an empty cell', () {
        final ref = GridRef.at(terminal, col: 79, row: 23);
        addTearDown(ref.dispose);

        final result = ref.content;

        expect(result, isEmpty);
      });

      test('throws for an out of range column', () {
        expect(
          () => GridRef.at(terminal, col: 80, row: 0),
          throwsA(isA<InvalidValueException>()),
        );
      });
    });

    group('cell', () {
      test('returns a cell handle', () {
        final ref = GridRef.at(terminal, col: 0, row: 0);
        addTearDown(ref.dispose);

        final result = ref.cell;

        expect(result, isNonZero);
      });
    });

    group('row', () {
      test('returns a row handle', () {
        final ref = GridRef.at(terminal, col: 0, row: 0);
        addTearDown(ref.dispose);

        final result = ref.row;

        expect(result, isNonZero);
      });
    });

    group('style', () {
      test('returns the cell style', () {
        terminal.write(Uint8List.fromList('\x1b[1mB'.codeUnits));
        final ref = GridRef.at(terminal, col: 5, row: 0);
        addTearDown(ref.dispose);

        final result = ref.style;

        expect(result, isA<Style>());
      });

      test('reflects bold text', () {
        terminal.write(Uint8List.fromList('\x1b[1mB'.codeUnits));
        final ref = GridRef.at(terminal, col: 5, row: 0);
        addTearDown(ref.dispose);

        final result = ref.style.bold;

        expect(result, isTrue);
      });
    });

    group('graphemes', () {
      test('returns the cell codepoints', () {
        final ref = GridRef.at(terminal, col: 0, row: 0);
        addTearDown(ref.dispose);

        final result = ref.graphemes;

        expect(result, contains(0x48));
      });
    });

    group('hyperlinkUri', () {
      test('returns null when the cell has no hyperlink', () {
        final ref = GridRef.at(terminal, col: 0, row: 0);
        addTearDown(ref.dispose);

        final result = ref.hyperlinkUri;

        expect(result, isNull);
      });
    });

    group('wide', () {
      test('returns narrow for a single width cell', () {
        final ref = GridRef.at(terminal, col: 0, row: 0);
        addTearDown(ref.dispose);

        final result = ref.wide;

        expect(result, CellWidth.narrow);
      });

      test('returns wide for a leading wide cell', () {
        terminal.write(Uint8List.fromList([0xE6, 0x97, 0xA5]));
        final ref = GridRef.at(terminal, col: 5, row: 0);
        addTearDown(ref.dispose);

        final result = ref.wide;

        expect(result, CellWidth.wide);
      });
    });

    group('isWide', () {
      test('returns false for a single width cell', () {
        final ref = GridRef.at(terminal, col: 0, row: 0);
        addTearDown(ref.dispose);

        final result = ref.isWide;

        expect(result, isFalse);
      });

      test('returns true for a leading wide cell', () {
        terminal.write(Uint8List.fromList([0xE6, 0x97, 0xA5]));
        final ref = GridRef.at(terminal, col: 5, row: 0);
        addTearDown(ref.dispose);

        final result = ref.isWide;

        expect(result, isTrue);
      });
    });

    group('rowWrap', () {
      test('returns true for a wrapped row', () {
        final wrapped = Terminal(cols: 5, rows: 2);
        addTearDown(wrapped.dispose);
        wrapped.write(Uint8List.fromList('ABCDEF'.codeUnits));
        final ref = GridRef.at(wrapped, col: 0, row: 0);
        addTearDown(ref.dispose);

        final result = ref.rowWrap;

        expect(result, isTrue);
      });
    });

    group('pointIn', () {
      test('returns coordinates in the requested coordinate space', () {
        final ref = GridRef.at(terminal, col: 2, row: 0);
        addTearDown(ref.dispose);

        final result = ref.pointIn(.active);

        expect(result, (col: 2, row: 0));
      });
    });
  });
}
