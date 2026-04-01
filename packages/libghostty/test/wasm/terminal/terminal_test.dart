@Tags(['wasm'])
library;

import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import '../../impl/terminal/helpers/cell_reader.dart';
import '../../impl/terminal/helpers/terminal_dump.dart';
import '../helpers/setup.dart';

void main() {
  setUpAll(setUpWasm);

  group('Terminal', () {
    late Terminal terminal;

    setUp(() => terminal = Terminal(cols: 80, rows: 24));

    tearDown(() => terminal.dispose());

    test('initial dimensions', () {
      terminal.renderState.update();
      expect(terminal.renderState.cols, 80);
      expect(terminal.renderState.rows, 24);
    });

    test('write bytes and read screen', () {
      terminal.write(Uint8List.fromList('Hello'.codeUnits));
      final h = readCellAt(terminal, 0, 0);
      expect(h.content, 'H');
      final o = readCellAt(terminal, 0, 4);
      expect(o.content, 'o');
    });

    test('cursor tracks position', () {
      terminal.write(Uint8List.fromList('Hi'.codeUnits));
      terminal.renderState.update();
      expect(terminal.renderState.cursor.col, 2);
      expect(terminal.renderState.cursor.row, 0);
    });

    test('cursor visibility', () {
      terminal.write(Uint8List.fromList('\x1b[?25l'.codeUnits));
      terminal.renderState.update();
      expect(terminal.renderState.cursor.visible, isFalse);
      terminal.write(Uint8List.fromList('\x1b[?25h'.codeUnits));
      terminal.renderState.update();
      expect(terminal.renderState.cursor.visible, isTrue);
    });

    group('modes', () {
      test('bracketedPaste tracks DECSET 2004', () {
        terminal.write(Uint8List.fromList('\x1b[?2004h'.codeUnits));
        expect(terminal.modeGet(const .bracketedPaste()), isTrue);

        terminal.write(Uint8List.fromList('\x1b[?2004l'.codeUnits));
        expect(terminal.modeGet(const .bracketedPaste()), isFalse);
      });

      test('cursorKeyApplication tracks DECSET 1', () {
        expect(terminal.modeGet(const .cursorKeys()), isFalse);

        terminal.write(Uint8List.fromList('\x1b[?1h'.codeUnits));
        expect(terminal.modeGet(const .cursorKeys()), isTrue);

        terminal.write(Uint8List.fromList('\x1b[?1l'.codeUnits));
        expect(terminal.modeGet(const .cursorKeys()), isFalse);
      });

      test('autoWrap tracks DECSET 7', () {
        expect(terminal.modeGet(const .autoWrap()), isTrue);

        terminal.write(Uint8List.fromList('\x1b[?7l'.codeUnits));
        expect(terminal.modeGet(const .autoWrap()), isFalse);

        terminal.write(Uint8List.fromList('\x1b[?7h'.codeUnits));
        expect(terminal.modeGet(const .autoWrap()), isTrue);
      });

      test('insertMode tracks SM 4', () {
        expect(terminal.modeGet(const .insert()), isFalse);

        terminal.write(Uint8List.fromList('\x1b[4h'.codeUnits));
        expect(terminal.modeGet(const .insert()), isTrue);

        terminal.write(Uint8List.fromList('\x1b[4l'.codeUnits));
        expect(terminal.modeGet(const .insert()), isFalse);
      });

      group('mouseTracking', () {
        test('default is none', () {
          expect(terminal.mouseTracking, MouseTracking.none);
        });

        test('DECSET 9 activates x10', () {
          terminal.write(Uint8List.fromList('\x1b[?9h'.codeUnits));
          expect(terminal.mouseTracking, MouseTracking.x10);
        });

        test('DECSET 1000 activates normal', () {
          terminal.write(Uint8List.fromList('\x1b[?1000h'.codeUnits));
          expect(terminal.mouseTracking, MouseTracking.normal);
        });

        test('DECSET 1002 activates buttonEvent', () {
          terminal.write(Uint8List.fromList('\x1b[?1002h'.codeUnits));
          expect(terminal.mouseTracking, MouseTracking.button);
        });

        test('DECSET 1003 activates anyEvent', () {
          terminal.write(Uint8List.fromList('\x1b[?1003h'.codeUnits));
          expect(terminal.mouseTracking, MouseTracking.any);
        });

        test('DECRST disables mouse tracking', () {
          terminal.write(Uint8List.fromList('\x1b[?1000h'.codeUnits));
          expect(terminal.mouseTracking, MouseTracking.normal);

          terminal.write(Uint8List.fromList('\x1b[?1000l'.codeUnits));
          expect(terminal.mouseTracking, MouseTracking.none);
        });
      });
    });

    test('alternate screen switch', () {
      terminal.write(Uint8List.fromList('Primary'.codeUnits));
      terminal.write(Uint8List.fromList('\x1b[?1049h'.codeUnits));
      expect(terminal.activeScreen, TerminalScreen.alternate);
      final altCell = readCellAt(terminal, 0, 0);
      expect(altCell.isEmpty, isTrue);
      terminal.write(Uint8List.fromList('\x1b[?1049l'.codeUnits));
      expect(terminal.activeScreen, TerminalScreen.primary);
      final priCell = readCellAt(terminal, 0, 0);
      expect(priCell.content, 'P');
    });

    test('styled text', () {
      terminal.write(Uint8List.fromList('\x1b[1;31mBold Red'.codeUnits));
      final cell = readCellAt(terminal, 0, 0);
      expect(cell.content, 'B');
      expect(cell.style.bold, isTrue);
      expect(cell.foreground, isA<PaletteColor>());
    });

    test('multi-byte UTF-8', () {
      terminal.write(Uint8List.fromList([0xC3, 0xA9]));
      final cell = readCellAt(terminal, 0, 0);
      expect(cell.content, '\u00E9');
    });

    test('split UTF-8 across writes', () {
      terminal.write(Uint8List.fromList([0xC3]));
      terminal.write(Uint8List.fromList([0xA9]));
      final cell = readCellAt(terminal, 0, 0);
      expect(cell.content, '\u00E9');
    });

    test('row text content', () {
      terminal.write(Uint8List.fromList('Hello World'.codeUnits));
      final text = readRowText(terminal, 0);
      expect(text, startsWith('Hello World'));
    });

    test('CRLF line breaks', () {
      terminal.write(Uint8List.fromList('Line1\r\nLine2'.codeUnits));
      final cell00 = readCellAt(terminal, 0, 0);
      expect(cell00.content, 'L');
      final cell10 = readCellAt(terminal, 1, 0);
      expect(cell10.content, 'L');
      final row0 = readRowText(terminal, 0);
      expect(row0, startsWith('Line1'));
      final row1 = readRowText(terminal, 1);
      expect(row1, startsWith('Line2'));
    });

    group('listeners', () {
      test('notifies on write', () {
        var count = 0;
        terminal.addListener(() => count++);
        terminal.write(Uint8List.fromList('A'.codeUnits));
        expect(count, greaterThan(0));
      });

      test('notifies on resize', () {
        var count = 0;
        terminal.addListener(() => count++);
        terminal.resize(cols: 120, rows: 40);
        expect(count, 1);
      });
    });

    group('renderState dirty', () {
      test('writing content makes renderState dirty', () {
        terminal.renderState.update();
        terminal.renderState.markClean();
        terminal.write(Uint8List.fromList('A'.codeUnits));
        terminal.renderState.update();
        expect(terminal.renderState.dirty, isNot(DirtyState.clean));
      });

      test('markClean resets dirty state', () {
        terminal.write(Uint8List.fromList('A'.codeUnits));
        terminal.renderState.update();
        terminal.renderState.markClean();
        expect(terminal.renderState.dirty, DirtyState.clean);
      });

      test('cursor-only move does not dirty renderState', () {
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        terminal.renderState.update();
        terminal.renderState.markClean();
        terminal.write(Uint8List.fromList('\x1b[H'.codeUnits));
        terminal.renderState.update();
        expect(terminal.renderState.dirty, DirtyState.clean);
      });

      test('accumulates across multiple writes', () {
        terminal.renderState.update();
        terminal.renderState.markClean();
        terminal.write(Uint8List.fromList('X'.codeUnits));
        terminal.write(Uint8List.fromList('\x1b[H'.codeUnits));
        terminal.renderState.update();
        expect(terminal.renderState.dirty, isNot(DirtyState.clean));
      });
    });

    group('resize', () {
      test('updates dimensions', () {
        terminal.resize(cols: 120, rows: 40);
        terminal.renderState.update();
        expect(terminal.renderState.cols, 120);
        expect(terminal.renderState.rows, 40);
      });

      test('clamps cursor', () {
        terminal.write(Uint8List.fromList('\x1b[24;80H'.codeUnits));
        terminal.resize(cols: 40, rows: 10);
        terminal.renderState.update();
        expect(terminal.renderState.cursor.row, lessThan(10));
        expect(terminal.renderState.cursor.col, lessThan(40));
      });

      test('shrinking rows adjusts cursor position', () {
        final t = Terminal(cols: 10, rows: 5);
        addTearDown(t.dispose);
        t.write(Uint8List.fromList('A\r\nB\r\nC\r\nD\r\nE'.codeUnits));
        t.renderState.update();
        expect(t.renderState.cursor.row, 4);

        t.resize(cols: 10, rows: 3);
        t.renderState.update();
        expect(t.renderState.cursor.row, 2);
      });

      test('no content duplication after shrink', () {
        final t = Terminal(cols: 10, rows: 6);
        addTearDown(t.dispose);
        for (var i = 0; i < 6; i++) {
          t.write(Uint8List.fromList('Row_$i\r\n'.codeUnits));
        }

        t.resize(cols: 10, rows: 3);

        expect(TerminalDump.hasContentOverlap(t), isFalse);
      });

      test('shrink-grow cycle preserves screen content', () {
        final t = Terminal(cols: 10, rows: 6);
        addTearDown(t.dispose);
        t.write(
          Uint8List.fromList(
            'AAA\r\nBBB\r\nCCC\r\nDDD\r\nEEE\r\nFFF'.codeUnits,
          ),
        );

        t.resize(cols: 10, rows: 3);
        final afterShrink = TerminalDump.screenContent(
          t,
        ).map((l) => l.trimRight()).where((l) => l.isNotEmpty).toList();

        t.resize(cols: 10, rows: 6);
        final afterGrow = TerminalDump.screenContent(
          t,
        ).map((l) => l.trimRight()).where((l) => l.isNotEmpty).toList();

        for (final line in afterShrink) {
          expect(afterGrow, contains(line));
        }
      });

      test('multiple resize cycles maintain integrity', () {
        final t = Terminal(cols: 10, rows: 8);
        addTearDown(t.dispose);
        for (var i = 0; i < 8; i++) {
          t.write(Uint8List.fromList('Line$i\r\n'.codeUnits));
        }

        t.resize(cols: 10, rows: 4);
        expect(TerminalDump.hasContentOverlap(t), isFalse);

        t.resize(cols: 10, rows: 6);
        expect(TerminalDump.hasContentOverlap(t), isFalse);

        t.resize(cols: 10, rows: 2);
        expect(TerminalDump.hasContentOverlap(t), isFalse);

        final all = TerminalDump.nonEmptyContent(t);
        for (var i = 0; i < all.length - 1; i++) {
          final currentNum = int.tryParse(
            all[i].replaceAll(RegExp('[^0-9]'), ''),
          );
          final nextNum = int.tryParse(
            all[i + 1].replaceAll(RegExp('[^0-9]'), ''),
          );
          if (currentNum != null && nextNum != null) {
            expect(currentNum, lessThan(nextNum));
          }
        }
      });

      test('column shrink preserves content within new width', () {
        final t = Terminal(cols: 10, rows: 3);
        addTearDown(t.dispose);
        t.write(Uint8List.fromList('ABCDEFGHIJ'.codeUnits));

        t.resize(cols: 5, rows: 3);
        final cellA = readCellAt(t, 0, 0);
        expect(cellA.content, 'A');
        final cellE = readCellAt(t, 0, 4);
        expect(cellE.content, 'E');
      });

      test('column grow pads with empty cells', () {
        final t = Terminal(cols: 5, rows: 3);
        addTearDown(t.dispose);
        t.write(Uint8List.fromList('ABCDE'.codeUnits));

        t.resize(cols: 10, rows: 3);
        final cellA = readCellAt(t, 0, 0);
        expect(cellA.content, 'A');
        final cellE = readCellAt(t, 0, 4);
        expect(cellE.content, 'E');
        final cell5 = readCellAt(t, 0, 5);
        expect(cell5.isEmpty, isTrue);
        final cell9 = readCellAt(t, 0, 9);
        expect(cell9.isEmpty, isTrue);
      });
    });

    group('screen', () {
      group('initialization', () {
        test('fresh terminal is clean', () {
          final t = Terminal(cols: 80, rows: 24);
          addTearDown(t.dispose);
          _expectAllCellsEmpty(t);
          t.renderState.update();
          expect(t.renderState.cursor.row, 0);
          expect(t.renderState.cursor.col, 0);
        });

        test('multiple dispose-recreate cycles produce clean screens', () {
          for (var i = 0; i < 5; i++) {
            final t = Terminal(cols: 40, rows: 10);
            _expectAllCellsEmpty(t);
            t.write(Uint8List.fromList('Cycle $i data fill'.codeUnits));
            t.dispose();
          }
        });

        test(
          'recreated terminal with different dimensions has all empty cells',
          () {
            var t = Terminal(cols: 80, rows: 24);
            t.write(Uint8List.fromList('Fill the screen'.codeUnits));
            t.dispose();

            t = Terminal(cols: 120, rows: 40);
            addTearDown(t.dispose);
            _expectAllCellsEmpty(t);
          },
        );
      });

      group('multi-instance', () {
        test('concurrent terminals have independent state', () {
          final t1 = Terminal(cols: 80, rows: 24);
          addTearDown(t1.dispose);
          final t2 = Terminal(cols: 80, rows: 24);
          addTearDown(t2.dispose);

          t1.write(Uint8List.fromList('Terminal One'.codeUnits));
          t2.write(Uint8List.fromList('Terminal Two'.codeUnits));

          final t1Cell = readCellAt(t1, 0, 9);
          expect(t1Cell.content, 'O');
          final t2Cell = readCellAt(t2, 0, 9);
          expect(t2Cell.content, 'T');
        });

        test('disposing one terminal does not affect the other', () {
          final t1 = Terminal(cols: 80, rows: 24);
          final t2 = Terminal(cols: 80, rows: 24);
          addTearDown(t2.dispose);

          t2.write(Uint8List.fromList('Still alive'.codeUnits));
          t1.dispose();

          final cellS = readCellAt(t2, 0, 0);
          expect(cellS.content, 'S');
          t2.write(Uint8List.fromList('\r\nMore data'.codeUnits));
          final cellM = readCellAt(t2, 1, 0);
          expect(cellM.content, 'M');
        });
      });
    });

    test('wide char sets CellWidth on both cells', () {
      terminal.write(
        Uint8List.fromList([
          0xE6, 0x97, 0xA5, // U+65E5
          ...('A'.codeUnits),
        ]),
      );
      final cell0 = readCellAt(terminal, 0, 0);
      expect(cell0.wide, CellWidth.wide);
      final cell1 = readCellAt(terminal, 0, 1);
      expect(cell1.wide, CellWidth.spacerTail);
      final cell2 = readCellAt(terminal, 0, 2);
      expect(cell2.wide, CellWidth.narrow);
    });

    test('long line wraps across rows with correct cells', () {
      final t = Terminal(cols: 5, rows: 3);
      addTearDown(t.dispose);
      t.write(Uint8List.fromList('ABCDEFGH'.codeUnits));

      t.renderState.update();
      final cellE = readCellAt(t, 0, 4);
      expect(cellE.content, 'E');
      expect(isRowWrapped(t, 0), isTrue);
      final cellF = readCellAt(t, 1, 0);
      expect(cellF.content, 'F');
      final cellH = readCellAt(t, 1, 2);
      expect(cellH.content, 'H');
      expect(isRowWrapped(t, 1), isFalse);
    });

    group('dirtyState', () {
      test('writing text produces partial dirty state', () {
        terminal.renderState.update();
        terminal.renderState.markClean();
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        terminal.renderState.update();
        expect(terminal.renderState.dirty, DirtyState.partial);
      });

      test('cursor-only move produces clean dirty state', () {
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        terminal.renderState.update();
        terminal.renderState.markClean();
        terminal.write(Uint8List.fromList('\x1b[H'.codeUnits));
        terminal.renderState.update();
        expect(terminal.renderState.dirty, DirtyState.clean);
      });

      test('alternate screen switch produces full dirty state', () {
        terminal.renderState.update();
        terminal.renderState.markClean();
        terminal.write(Uint8List.fromList('\x1b[?1049h'.codeUnits));
        terminal.renderState.update();
        expect(terminal.renderState.dirty, DirtyState.full);
      });
    });

    group('isRowDirty', () {
      test('written row is dirty', () {
        terminal.renderState.update();
        terminal.renderState.markClean();
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        terminal.renderState.update();
        expect(isRowDirty(terminal, 0), isTrue);
      });

      test('unwritten row is not dirty', () {
        terminal.renderState.update();
        terminal.renderState.markClean();
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        terminal.renderState.update();
        expect(isRowDirty(terminal, 1), isFalse);
      });

      test('markClean resets row dirty flags', () {
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        terminal.renderState.update();
        terminal.renderState.markClean();
        expect(isRowDirty(terminal, 0), isFalse);
      });

      test('multiple rows track independently', () {
        terminal.renderState.update();
        terminal.renderState.markClean();
        terminal.write(Uint8List.fromList('Line1\r\nLine2'.codeUnits));
        terminal.renderState.update();
        expect(isRowDirty(terminal, 0), isTrue);
        expect(isRowDirty(terminal, 1), isTrue);
        expect(isRowDirty(terminal, 2), isFalse);
      });

      test('cursor-only move does not dirty row', () {
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        terminal.renderState.update();
        terminal.renderState.markClean();
        terminal.write(Uint8List.fromList('\x1b[H'.codeUnits));
        terminal.renderState.update();
        expect(isRowDirty(terminal, 0), isFalse);
      });
    });

    group('callbacks', () {
      test('writePty receives terminal responses', () {
        Uint8List? received;
        terminal.onWritePty = (data) => received = data;
        terminal.write(Uint8List.fromList('\x1b[5n'.codeUnits));
        expect(received, isNotNull);
      });

      test('writePty data is correct DSR response', () {
        Uint8List? received;
        terminal.onWritePty = (data) => received = data;
        terminal.write(Uint8List.fromList('\x1b[5n'.codeUnits));
        expect(received, isNotNull);
        final response = String.fromCharCodes(received!);
        expect(response, contains('\x1b[0n'));
      });

      test('bell callback fires on BEL character', () {
        var bellCount = 0;
        terminal.onBell = () => bellCount++;
        terminal.write(Uint8List.fromList([0x07]));
        expect(bellCount, 1);
      });

      test('multiple bell callbacks accumulate', () {
        var count = 0;
        terminal.onBell = () => count++;
        terminal.write(Uint8List.fromList([0x07, 0x07, 0x07]));
        expect(count, 3);
      });

      test('titleChanged fires on OSC 0', () {
        var changed = false;
        terminal.onTitleChanged = () => changed = true;
        terminal.write(Uint8List.fromList('\x1b]0;New Title\x1b\\'.codeUnits));
        expect(changed, isTrue);
      });

      test('null callback clears without error', () {
        terminal.onWritePty = (data) {};
        terminal.onWritePty = null;
        terminal.write(Uint8List.fromList('\x1b[5n'.codeUnits));
      });

      test('deviceAttributes DA1 sends primary response', () {
        Uint8List? received;
        terminal.onWritePty = (data) => received = data;
        terminal.onDeviceAttributes = () => const DeviceAttributesResponse(
          primary: DeviceAttributesPrimary(
            conformanceLevel: 65,
            features: [1, 6, 22],
          ),
        );
        terminal.write(Uint8List.fromList('\x1b[c'.codeUnits));
        expect(received, isNotNull);
        final response = String.fromCharCodes(received!);
        expect(response, contains('\x1b[?65;1;6;22c'));
      });

      test('deviceAttributes DA2 sends secondary response', () {
        Uint8List? received;
        terminal.onWritePty = (data) => received = data;
        terminal.onDeviceAttributes = () => const DeviceAttributesResponse(
          secondary: DeviceAttributesSecondary(
            deviceType: 41,
            firmwareVersion: 10,
          ),
        );
        terminal.write(Uint8List.fromList('\x1b[>c'.codeUnits));
        expect(received, isNotNull);
        final response = String.fromCharCodes(received!);
        expect(response, contains('\x1b[>41;10;0c'));
      });

      test('deviceAttributes DA3 sends tertiary response', () {
        Uint8List? received;
        terminal.onWritePty = (data) => received = data;
        terminal.onDeviceAttributes = () => const DeviceAttributesResponse(
          tertiary: DeviceAttributesTertiary(unitId: 42),
        );
        terminal.write(Uint8List.fromList('\x1b[=c'.codeUnits));
        expect(received, isNotNull);
        final response = String.fromCharCodes(received!);
        expect(response, contains('!|0000002A'));
      });

      test('deviceAttributes null callback uses default response', () {
        Uint8List? received;
        terminal.onWritePty = (data) => received = data;
        terminal.onDeviceAttributes = null;
        terminal.write(Uint8List.fromList('\x1b[c'.codeUnits));
        final response = String.fromCharCodes(received!);
        expect(response, contains('\x1b[?62'));
      });
    });

    group('Row properties', () {
      test('empty row has no content flags', () {
        terminal.renderState.update();
        terminal.renderState.nextRow();
        final row = terminal.renderState.row;
        expect(row.hasGrapheme, isFalse);
        expect(row.hasStyled, isFalse);
        expect(row.hasHyperlink, isFalse);
        expect(row.hasKittyVirtualPlaceholder, isFalse);
        expect(row.semanticPrompt, SemanticPrompt.none);
      });

      test('styled row reports hasStyled', () {
        terminal.write(Uint8List.fromList('\x1b[1mBold'.codeUnits));
        terminal.renderState.update();
        terminal.renderState.nextRow();
        expect(terminal.renderState.row.hasStyled, isTrue);
      });
    });

    group('Cell properties', () {
      test('default cell has no styling, protection, or special content', () {
        terminal.write(Uint8List.fromList('A'.codeUnits));
        terminal.renderState.update();
        terminal.renderState.nextRow();
        terminal.renderState.nextCell();
        final cell = terminal.renderState.cell;
        expect(cell.style.bold, isFalse);
        expect(cell.isProtected, isFalse);
        expect(cell.semanticContent, SemanticContent.output);
      });

      test('styled cell reports hasStyling', () {
        terminal.write(Uint8List.fromList('\x1b[1mB'.codeUnits));
        terminal.renderState.update();
        terminal.renderState.nextRow();
        terminal.renderState.nextCell();
        expect(terminal.renderState.cell.hasStyling, isTrue);
      });
    });

    group('Cursor properties', () {
      test('cursor wideTail is false on normal position', () {
        terminal.renderState.update();
        final cursor = terminal.renderState.cursor;
        expect(cursor.wideTail, isFalse);
      });
    });

    group('resetIteration', () {
      test('allows re-iterating rows after exhaustion', () {
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        terminal.renderState.update();

        var count1 = 0;
        while (terminal.renderState.nextRow()) {
          count1++;
        }

        terminal.renderState.resetIteration();
        var count2 = 0;
        while (terminal.renderState.nextRow()) {
          count2++;
        }

        expect(count1, greaterThan(0));
        expect(count2, count1);
      });
    });

    group('selectCell', () {
      test('reads specific column content', () {
        terminal.write(Uint8List.fromList('ABCDE'.codeUnits));
        terminal.renderState.update();

        terminal.renderState.nextRow();
        terminal.renderState.selectCell(2);
        expect(terminal.renderState.cell.content, 'C');

        terminal.renderState.selectCell(0);
        expect(terminal.renderState.cell.content, 'A');

        terminal.renderState.selectCell(4);
        expect(terminal.renderState.cell.content, 'E');
      });
    });

    group('dispose', () {
      test('double dispose is safe', () {
        terminal.dispose();
        terminal.dispose();
      });
    });
  });
}

void _expectAllCellsEmpty(Terminal terminal) {
  terminal.renderState.update();
  var rowIndex = 0;
  while (terminal.renderState.nextRow()) {
    var colIndex = 0;
    while (terminal.renderState.nextCell()) {
      expect(
        terminal.renderState.cell.hasText,
        isFalse,
        reason: 'cell at ($rowIndex, $colIndex) should be empty',
      );
      colIndex++;
    }
    rowIndex++;
  }
}
