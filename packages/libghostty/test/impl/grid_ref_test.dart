@Tags(['ffi'])
library;

import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
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

    test('content returns character at position', () {
      final ref = terminal.gridRefAt(col: 0, row: 0);
      addTearDown(ref.dispose);
      expect(ref.content, 'H');
    });

    test('content at different column', () {
      final ref = terminal.gridRefAt(col: 4, row: 0);
      addTearDown(ref.dispose);
      expect(ref.content, 'o');
    });

    test('cell returns valid handle', () {
      final ref = terminal.gridRefAt(col: 0, row: 0);
      addTearDown(ref.dispose);
      expect(ref.cell, isNonZero);
    });

    test('row returns valid handle', () {
      final ref = terminal.gridRefAt(col: 0, row: 0);
      addTearDown(ref.dispose);
      expect(ref.row, isNonZero);
    });

    test('style reflects bold attribute', () {
      terminal.write(Uint8List.fromList('\x1b[1mB'.codeUnits));
      final ref = terminal.gridRefAt(col: 5, row: 0);
      addTearDown(ref.dispose);
      expect(ref.style, isA<Style>());
      expect(ref.style.bold, isTrue);
    });

    test('graphemes returns codepoint list', () {
      final ref = terminal.gridRefAt(col: 0, row: 0);
      addTearDown(ref.dispose);
      expect(ref.graphemes, contains(0x48));
    });

    test('empty cell returns empty content', () {
      final ref = terminal.gridRefAt(col: 79, row: 23);
      addTearDown(ref.dispose);
      expect(ref.content, isEmpty);
    });

    test('narrow character returns CellWidth.narrow', () {
      final ref = terminal.gridRefAt(col: 0, row: 0);
      addTearDown(ref.dispose);
      expect(ref.wide, CellWidth.narrow);
      expect(ref.isWide, isFalse);
    });

    test('wide character returns CellWidth.wide', () {
      terminal.write(Uint8List.fromList([0xE6, 0x97, 0xA5]));
      final ref = terminal.gridRefAt(col: 5, row: 0);
      addTearDown(ref.dispose);
      expect(ref.wide, CellWidth.wide);
      expect(ref.isWide, isTrue);
    });

    test('double dispose is safe', () {
      final ref = terminal.gridRefAt(col: 0, row: 0);
      ref.dispose();
      ref.dispose();
    });
  });
}
