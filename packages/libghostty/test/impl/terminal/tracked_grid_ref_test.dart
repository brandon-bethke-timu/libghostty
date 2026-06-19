@Tags(['ffi'])
library;

import 'dart:typed_data' show Uint8List;

import 'package:libghostty/libghostty.dart'
    show GridRef, InvalidValueException, Terminal, TrackedGridRef;
import 'package:test/test.dart';

void main() {
  group('TrackedGridRef', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: 80, rows: 24);
      terminal.write(Uint8List.fromList('Hello'.codeUnits));
    });

    tearDown(() {
      terminal.dispose();
    });

    group('at', () {
      test('throws for an out of range column', () {
        expect(
          () => TrackedGridRef.at(terminal, col: 80, row: 0),
          throwsA(isA<InvalidValueException>()),
        );
      });
    });

    group('hasValue', () {
      test('returns true for a live cell', () {
        final tracked = TrackedGridRef.at(terminal, col: 0, row: 0);
        addTearDown(tracked.dispose);

        final result = tracked.hasValue;

        expect(result, isTrue);
      });

      test('returns false after reset', () {
        final tracked = TrackedGridRef.at(terminal, col: 0, row: 0);
        addTearDown(tracked.dispose);

        terminal.reset();
        final result = tracked.hasValue;

        expect(result, isFalse);
      });
    });

    group('pointIn', () {
      test('returns coordinates in the requested coordinate space', () {
        final tracked = TrackedGridRef.at(terminal, col: 1, row: 0);
        addTearDown(tracked.dispose);

        final result = tracked.pointIn(.active);

        expect(result, (col: 1, row: 0));
      });

      test('returns null after reset', () {
        final tracked = TrackedGridRef.at(terminal, col: 0, row: 0);
        addTearDown(tracked.dispose);

        terminal.reset();
        final result = tracked.pointIn(.active);

        expect(result, isNull);
      });
    });

    group('set', () {
      test('moves the tracked point', () {
        final tracked = TrackedGridRef.at(terminal, col: 0, row: 0);
        addTearDown(tracked.dispose);

        tracked.set(col: 2, row: 0);
        final result = tracked.pointIn(.active);

        expect(result, (col: 2, row: 0));
      });

      test('throws for an out of range column', () {
        final tracked = TrackedGridRef.at(terminal, col: 0, row: 0);
        addTearDown(tracked.dispose);

        expect(
          () => tracked.set(col: 80, row: 0),
          throwsA(isA<InvalidValueException>()),
        );
      });
    });

    group('snapshot', () {
      test('returns a grid reference for a live cell', () {
        final tracked = TrackedGridRef.at(terminal, col: 1, row: 0);
        addTearDown(tracked.dispose);

        final result = tracked.snapshot();
        addTearDown(result!.dispose);

        expect(result, isA<GridRef>());
      });

      test('returns content from the tracked cell', () {
        final tracked = TrackedGridRef.at(terminal, col: 1, row: 0);
        addTearDown(tracked.dispose);

        final result = tracked.snapshot();
        addTearDown(result!.dispose);

        expect(result.content, 'e');
      });

      test('returns null after reset', () {
        final tracked = TrackedGridRef.at(terminal, col: 0, row: 0);
        addTearDown(tracked.dispose);

        terminal.reset();
        final result = tracked.snapshot();

        expect(result, isNull);
      });

      test('follows the cell after scrolling', () {
        final scrolled = Terminal(cols: 8, rows: 3, maxScrollback: 100);
        addTearDown(scrolled.dispose);
        scrolled.write(
          Uint8List.fromList('alpha\r\nbravo\r\ncharlie'.codeUnits),
        );
        final tracked = TrackedGridRef.at(scrolled, col: 0, row: 0);
        addTearDown(tracked.dispose);

        scrolled.write(Uint8List.fromList('\r\ndelta'.codeUnits));
        final result = tracked.snapshot();
        addTearDown(result!.dispose);

        expect(result.content, 'a');
      });
    });
  });
}
