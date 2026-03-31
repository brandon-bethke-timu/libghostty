@Tags(['ffi'])
library;

import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import '../helpers/cell_reader.dart';

void main() {
  group('Terminal integration', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: 80, rows: 24);
    });

    tearDown(() {
      terminal.dispose();
    });

    test('colored ls-like output', () {
      terminal.write(
        Uint8List.fromList('\x1b[1;34mdir/\x1b[0m  file.txt'.codeUnits),
      );

      final dirCell = readCellAt(terminal, 0, 0);
      expect(dirCell.content, 'd');
      expect(dirCell.style.bold, isTrue);
      expect(dirCell.foreground, isA<PaletteColor>());

      final fileCell = readCellAt(terminal, 0, 6);
      expect(fileCell.content, 'f');
      expect(fileCell.style.bold, isFalse);
      expect(fileCell.foreground, isA<DefaultColor>());
    });

    test('cursor movement with CUP overwrites mid-line', () {
      terminal.write(Uint8List.fromList('ABCDE'.codeUnits));
      terminal.write(Uint8List.fromList('\x1b[1;3H'.codeUnits));
      terminal.write(Uint8List.fromList('X'.codeUnits));
      final cellX = readCellAt(terminal, 0, 2);
      expect(cellX.content, 'X');
      final cellA = readCellAt(terminal, 0, 0);
      expect(cellA.content, 'A');
      final cellB = readCellAt(terminal, 0, 1);
      expect(cellB.content, 'B');
    });

    test('erase display below cursor', () {
      terminal.write(Uint8List.fromList('Line1\r\nLine2\r\nLine3'.codeUnits));
      terminal.write(Uint8List.fromList('\x1b[2;1H'.codeUnits));
      terminal.write(Uint8List.fromList('\x1b[0J'.codeUnits));
      final cell00 = readCellAt(terminal, 0, 0);
      expect(cell00.content, 'L');
      final cell10 = readCellAt(terminal, 1, 0);
      expect(cell10.isEmpty, isTrue);
      final cell20 = readCellAt(terminal, 2, 0);
      expect(cell20.isEmpty, isTrue);
    });

    test('scroll region preserves content outside region', () {
      for (var i = 0; i < 5; i++) {
        terminal.write(Uint8List.fromList('Row$i\r\n'.codeUnits));
      }
      terminal.write(Uint8List.fromList('\x1b[2;4r'.codeUnits));
      terminal.write(Uint8List.fromList('\x1b[2;1H'.codeUnits));
      terminal.write(Uint8List.fromList('\x1b[S'.codeUnits));
      final cell00 = readCellAt(terminal, 0, 0);
      expect(cell00.content, 'R');
    });

    test('256-color and RGB foreground colors', () {
      terminal.write(
        Uint8List.fromList(
          '\x1b[38;5;196mRed\x1b[38;2;0;255;0mGreen'.codeUnits,
        ),
      );
      final redCell = readCellAt(terminal, 0, 0);
      expect(redCell.foreground, isA<PaletteColor>());

      final greenCell = readCellAt(terminal, 0, 3);
      expect(greenCell.foreground, const RgbColor(0, 255, 0));
    });

    test('CellColor pattern matching on RGB', () {
      terminal.write(Uint8List.fromList('\x1b[38;2;100;150;200mA'.codeUnits));
      final cell = readCellAt(terminal, 0, 0);
      final result = switch (cell.foreground) {
        DefaultColor() => 'default',
        RgbColor(:final r, :final g, :final b) => 'rgb:$r,$g,$b',
        PaletteColor(:final index) => 'palette:$index',
      };
      expect(result, 'rgb:100,150,200');
    });

    test('multiple style attributes combine', () {
      terminal.write(Uint8List.fromList('\x1b[1;3;4;31;42mStyled'.codeUnits));
      final cell = readCellAt(terminal, 0, 0);
      expect(cell.style.bold, isTrue);
      expect(cell.style.italic, isTrue);
      expect(cell.underlineStyle, UnderlineStyle.single);
      expect(cell.foreground, isA<PaletteColor>());
      expect(cell.background, isA<PaletteColor>());
    });

    test('hyperlink via OSC 8', () {
      terminal.write(
        Uint8List.fromList(
          '\x1b]8;;https://example.com\x1b\\Click\x1b]8;;\x1b\\'.codeUnits,
        ),
      );

      final linked = readCellAt(terminal, 0, 0);
      expect(linked.content, 'C');
      expect(linked.hasHyperlink, isTrue);

      final lastLinked = readCellAt(terminal, 0, 4);
      expect(lastLinked.content, 'k');
      expect(lastLinked.hasHyperlink, isTrue);

      final after = readCellAt(terminal, 0, 5);
      expect(after.hasHyperlink, isFalse);
    });
  });
}
