@Tags(['ffi'])
library;

import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import 'helpers/cell_reader.dart';
import 'helpers/terminal_dump.dart';

void main() {
  group('Terminal', () {
    late Terminal terminal;
    late RenderState renderState;
    late RowIterator rows;
    late CellIterator cells;

    setUp(() {
      terminal = Terminal(cols: 80, rows: 24);
      renderState = RenderState();
      rows = RowIterator();
      cells = CellIterator();
    });

    tearDown(() {
      cells.dispose();
      rows.dispose();
      renderState.dispose();
      terminal.dispose();
    });

    group('constructor', () {
      test('initializes dimensions', () {
        renderState.update(terminal);
        expect(renderState.cols, 80);
        expect(renderState.rows, 24);
      });
    });

    group('write', () {
      test('updates screen cells', () {
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        final h = readCellAt(terminal, 0, 0);
        expect(h.content, 'H');
        final o = readCellAt(terminal, 0, 4);
        expect(o.content, 'o');
      });

      test('applies SGR style to text', () {
        terminal.write(Uint8List.fromList('\x1b[1;31mBold Red'.codeUnits));
        final cell = readCellAt(terminal, 0, 0);
        expect(cell.content, 'B');
        expect(cell.style.bold, isTrue);
        expect(cell.foreground, isA<PaletteColor>());
      });

      test('decodes multi-byte UTF-8', () {
        terminal.write(Uint8List.fromList([0xC3, 0xA9]));
        final cell = readCellAt(terminal, 0, 0);
        expect(cell.content, '\u00E9');
      });

      test('decodes split UTF-8 across writes', () {
        terminal.write(Uint8List.fromList([0xC3]));
        terminal.write(Uint8List.fromList([0xA9]));
        final cell = readCellAt(terminal, 0, 0);
        expect(cell.content, '\u00E9');
      });

      test('updates row text content', () {
        terminal.write(Uint8List.fromList('Hello World'.codeUnits));
        final text = readRowText(terminal, 0);
        expect(text, startsWith('Hello World'));
      });

      test('handles CRLF line breaks', () {
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

      test('sets wide character width on leading and trailing cells', () {
        terminal.write(
          Uint8List.fromList([0xE6, 0x97, 0xA5, ...('A'.codeUnits)]),
        );
        final cell0 = readCellAt(terminal, 0, 0);
        expect(cell0.wide, CellWidth.wide);
        final cell1 = readCellAt(terminal, 0, 1);
        expect(cell1.wide, CellWidth.spacerTail);
        final cell2 = readCellAt(terminal, 0, 2);
        expect(cell2.wide, CellWidth.narrow);
      });

      test('wraps long lines across rows', () {
        final t = Terminal(cols: 5, rows: 3);
        final rs = RenderState();
        addTearDown(rs.dispose);
        addTearDown(t.dispose);
        t.write(Uint8List.fromList('ABCDEFGH'.codeUnits));

        rs.update(t);
        final cellE = readCellAt(t, 0, 4);
        expect(cellE.content, 'E');
        expect(isRowWrapped(t, 0), isTrue);
        final cellF = readCellAt(t, 1, 0);
        expect(cellF.content, 'F');
        final cellH = readCellAt(t, 1, 2);
        expect(cellH.content, 'H');
        expect(isRowWrapped(t, 1), isFalse);
      });
    });

    group('cursor', () {
      test('tracks write position', () {
        terminal.write(Uint8List.fromList('Hi'.codeUnits));
        renderState.update(terminal);
        expect(renderState.cursor.col, 2);
        expect(renderState.cursor.row, 0);
      });

      test('tracks visibility mode', () {
        terminal.write(Uint8List.fromList('\x1b[?25l'.codeUnits));
        renderState.update(terminal);
        expect(renderState.cursor.visible, isFalse);

        terminal.write(Uint8List.fromList('\x1b[?25h'.codeUnits));
        renderState.update(terminal);
        expect(renderState.cursor.visible, isTrue);
      });

      test('uses defaultCursorShape for reset sequence', () {
        terminal.defaultCursorShape = .underline;

        terminal.write(Uint8List.fromList('\x1b[0 q'.codeUnits));
        renderState.update(terminal);

        expect(renderState.cursor.shape, CursorShape.underline);
      });

      test('uses defaultCursorBlink for reset sequence', () {
        terminal.defaultCursorBlink = true;

        terminal.write(Uint8List.fromList('\x1b[0 q'.codeUnits));
        renderState.update(terminal);

        expect(renderState.cursor.blinking, isTrue);
      });
    });

    group('modes', () {
      test('tracks default-off DEC private modes', () {
        expect(terminal.modeGet(const .cursorKeys()), isFalse);

        terminal.write(Uint8List.fromList('\x1b[?2004h'.codeUnits));
        expect(terminal.modeGet(const .bracketedPaste()), isTrue);

        terminal.write(Uint8List.fromList('\x1b[?2004l'.codeUnits));
        expect(terminal.modeGet(const .bracketedPaste()), isFalse);

        terminal.write(Uint8List.fromList('\x1b[?1h'.codeUnits));
        expect(terminal.modeGet(const .cursorKeys()), isTrue);

        terminal.write(Uint8List.fromList('\x1b[?1l'.codeUnits));
        expect(terminal.modeGet(const .cursorKeys()), isFalse);
      });

      test('tracks default-on DEC private modes', () {
        expect(terminal.modeGet(const .autoWrap()), isTrue);
        expect(terminal.modeGet(const .alternateScroll()), isTrue);

        terminal.write(Uint8List.fromList('\x1b[?7l'.codeUnits));
        expect(terminal.modeGet(const .autoWrap()), isFalse);

        terminal.write(Uint8List.fromList('\x1b[?7h'.codeUnits));
        expect(terminal.modeGet(const .autoWrap()), isTrue);

        terminal.write(Uint8List.fromList('\x1b[?1007l'.codeUnits));
        expect(terminal.modeGet(const .alternateScroll()), isFalse);

        terminal.write(Uint8List.fromList('\x1b[?1007h'.codeUnits));
        expect(terminal.modeGet(const .alternateScroll()), isTrue);
      });

      test('tracks ANSI modes', () {
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

        test('tracks DECSET tracking modes', () {
          terminal.write(Uint8List.fromList('\x1b[?9h'.codeUnits));
          expect(terminal.mouseTracking, MouseTracking.x10);

          terminal.write(Uint8List.fromList('\x1b[?1000h'.codeUnits));
          expect(terminal.mouseTracking, MouseTracking.normal);

          terminal.write(Uint8List.fromList('\x1b[?1002h'.codeUnits));
          expect(terminal.mouseTracking, MouseTracking.button);

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

    group('activeScreen', () {
      test('switches between primary and alternate screens', () {
        terminal.write(Uint8List.fromList('Primary'.codeUnits));
        terminal.write(Uint8List.fromList('\x1b[?1049h'.codeUnits));

        expect(terminal.activeScreen, TerminalScreen.alternate);
        final cell = readCellAt(terminal, 0, 0);
        expect(cell.isEmpty, isTrue);

        terminal.write(Uint8List.fromList('\x1b[?1049l'.codeUnits));

        expect(terminal.activeScreen, TerminalScreen.primary);
        final pCell = readCellAt(terminal, 0, 0);
        expect(pCell.content, 'P');
      });
    });

    group('isViewportActive', () {
      test('is true for the active area', () {
        expect(terminal.isViewportActive, isTrue);
      });

      test('is false after scrolling into history', () {
        final t = Terminal(cols: 5, rows: 2);
        addTearDown(t.dispose);
        t.write(Uint8List.fromList('one\r\ntwo\r\nthree'.codeUnits));

        t.scrollViewport(-1);

        expect(t.isViewportActive, isFalse);
      });
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

    group('onPwdChanged', () {
      test('fires for OSC 7 pwd change', () {
        var count = 0;
        terminal.onPwdChanged = () => count++;

        terminal.write(Uint8List.fromList('\x1b]7;file:///tmp\x07'.codeUnits));

        expect(count, 1);
      });
    });

    group('renderState dirty', () {
      test('writing content makes renderState dirty', () {
        renderState.update(terminal);
        clearDirty(renderState, rows);
        terminal.write(Uint8List.fromList('A'.codeUnits));
        renderState.update(terminal);
        expect(renderState.dirty, isNot(DirtyState.clean));
      });

      test('dirty = clean resets global dirty', () {
        terminal.write(Uint8List.fromList('A'.codeUnits));
        renderState.update(terminal);
        clearDirty(renderState, rows);
        expect(renderState.dirty, DirtyState.clean);
      });

      test('cursor-only move does not dirty renderState', () {
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        renderState.update(terminal);
        clearDirty(renderState, rows);
        terminal.write(Uint8List.fromList('\x1b[H'.codeUnits));
        renderState.update(terminal);
        expect(renderState.dirty, DirtyState.clean);
      });

      test('accumulates across multiple writes', () {
        renderState.update(terminal);
        clearDirty(renderState, rows);
        terminal.write(Uint8List.fromList('X'.codeUnits));
        terminal.write(Uint8List.fromList('\x1b[H'.codeUnits));
        renderState.update(terminal);
        expect(renderState.dirty, isNot(DirtyState.clean));
      });
    });

    group('resize', () {
      test('updates dimensions', () {
        terminal.resize(cols: 120, rows: 40);
        renderState.update(terminal);
        expect(renderState.cols, 120);
        expect(renderState.rows, 40);
      });

      test('emits in-band size report when mode 2048 is enabled', () {
        Uint8List? received;
        terminal.onWritePty = (data) => received = data;
        terminal.modeSet(const TerminalMode.inBandResize(), value: true);

        terminal.resize(cols: 100, rows: 40, cellWidthPx: 9, cellHeightPx: 18);

        expect(String.fromCharCodes(received!), '\x1B[48;40;100;720;900t');
      });

      test('clamps cursor', () {
        terminal.write(Uint8List.fromList('\x1b[24;80H'.codeUnits));
        terminal.resize(cols: 40, rows: 10);
        renderState.update(terminal);
        expect(renderState.cursor.row, lessThan(10));
        expect(renderState.cursor.col, lessThan(40));
      });

      test('shrinking rows adjusts cursor position', () {
        final t = Terminal(cols: 10, rows: 5);
        final rs = RenderState();
        addTearDown(rs.dispose);
        addTearDown(t.dispose);
        t.write(Uint8List.fromList('A\r\nB\r\nC\r\nD\r\nE'.codeUnits));
        rs.update(t);
        expect(rs.cursor.row, 4);

        t.resize(cols: 10, rows: 3);
        rs.update(t);
        expect(rs.cursor.row, 2);
      });

      test('no content duplication after shrink', () {
        final t = Terminal(cols: 10, rows: 6);
        addTearDown(t.dispose);
        t.write(
          Uint8List.fromList(
            'Row_0\r\nRow_1\r\nRow_2\r\nRow_3\r\nRow_4\r\nRow_5\r\n'.codeUnits,
          ),
        );

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

        expect(afterGrow, containsAllInOrder(afterShrink));
      });

      test('multiple resize cycles maintain integrity', () {
        final t = Terminal(cols: 10, rows: 8);
        addTearDown(t.dispose);
        t.write(
          Uint8List.fromList(
            'Line0\r\nLine1\r\nLine2\r\nLine3\r\n'
                    'Line4\r\nLine5\r\nLine6\r\nLine7\r\n'
                .codeUnits,
          ),
        );

        t.resize(cols: 10, rows: 4);
        expect(TerminalDump.hasContentOverlap(t), isFalse);

        t.resize(cols: 10, rows: 6);
        expect(TerminalDump.hasContentOverlap(t), isFalse);

        t.resize(cols: 10, rows: 2);
        expect(TerminalDump.hasContentOverlap(t), isFalse);

        expect(TerminalDump.nonEmptyContent(t), ['Line7']);
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
          final rs = RenderState();
          addTearDown(rs.dispose);
          addTearDown(t.dispose);
          _expectAllCellsEmpty(t);
          rs.update(t);
          expect(rs.cursor.row, 0);
          expect(rs.cursor.col, 0);
        });

        test('multiple dispose-recreate cycles produce clean screens', () {
          final first = Terminal(cols: 40, rows: 10);
          _expectAllCellsEmpty(first);
          first.write(Uint8List.fromList('Cycle 1 data fill'.codeUnits));
          first.dispose();

          final second = Terminal(cols: 40, rows: 10);
          addTearDown(second.dispose);
          _expectAllCellsEmpty(second);
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
          final cell = readCellAt(t1, 0, 9);
          expect(cell.content, 'O');
          _expectAllCellsEmpty(t2);
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

    group('dirtyState', () {
      test('writing text produces partial dirty state', () {
        renderState.update(terminal);
        clearDirty(renderState, rows);
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        renderState.update(terminal);
        expect(renderState.dirty, DirtyState.partial);
      });

      test('cursor-only move produces clean dirty state', () {
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        renderState.update(terminal);
        clearDirty(renderState, rows);
        terminal.write(Uint8List.fromList('\x1b[H'.codeUnits));
        renderState.update(terminal);
        expect(renderState.dirty, DirtyState.clean);
      });

      test('alternate screen switch produces full dirty state', () {
        renderState.update(terminal);
        clearDirty(renderState, rows);
        terminal.write(Uint8List.fromList('\x1b[?1049h'.codeUnits));
        renderState.update(terminal);
        expect(renderState.dirty, DirtyState.full);
      });
    });

    group('isRowDirty', () {
      test('written row is dirty', () {
        renderState.update(terminal);
        clearDirty(renderState, rows);
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        renderState.update(terminal);
        expect(isRowDirty(renderState, 0), isTrue);
      });

      test('unwritten row is not dirty', () {
        renderState.update(terminal);
        clearDirty(renderState, rows);
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        renderState.update(terminal);
        expect(isRowDirty(renderState, 1), isFalse);
      });

      test('clearing per-row dirty via iterator resets flags', () {
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        renderState.update(terminal);
        clearDirty(renderState, rows);
        expect(isRowDirty(renderState, 0), isFalse);
      });

      test('multiple rows track independently', () {
        renderState.update(terminal);
        clearDirty(renderState, rows);
        terminal.write(Uint8List.fromList('Line1\r\nLine2'.codeUnits));
        renderState.update(terminal);
        expect(isRowDirty(renderState, 0), isTrue);
        expect(isRowDirty(renderState, 1), isTrue);
        expect(isRowDirty(renderState, 2), isFalse);
      });

      test('cursor-only move does not dirty row', () {
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        renderState.update(terminal);
        clearDirty(renderState, rows);
        terminal.write(Uint8List.fromList('\x1b[H'.codeUnits));
        renderState.update(terminal);
        expect(isRowDirty(renderState, 0), isFalse);
      });
    });

    group('onDeviceAttributes', () {
      String responseFor(
        String request,
        DeviceAttributesResponse Function() callback,
      ) {
        Uint8List? received;
        terminal.onWritePty = (data) => received = data;
        terminal.onDeviceAttributes = callback;
        terminal.write(Uint8List.fromList(request.codeUnits));
        expect(received, isNotNull);
        return String.fromCharCodes(received!);
      }

      test('sends configured responses', () {
        final primary = responseFor(
          '\x1b[c',
          () => const DeviceAttributesResponse(
            primary: DeviceAttributesPrimary(
              conformanceLevel: 65,
              features: [1, 6, 22],
            ),
          ),
        );
        expect(primary, contains('\x1b[?65;1;6;22c'));

        final secondary = responseFor(
          '\x1b[>c',
          () => const DeviceAttributesResponse(
            secondary: DeviceAttributesSecondary(
              deviceType: 41,
              firmwareVersion: 10,
            ),
          ),
        );
        expect(secondary, contains('\x1b[>41;10;0c'));

        final tertiary = responseFor(
          '\x1b[=c',
          () => const DeviceAttributesResponse(
            tertiary: DeviceAttributesTertiary(unitId: 42),
          ),
        );
        expect(tertiary, contains('!|0000002A'));
      });

      test('uses default response when unset', () {
        Uint8List? received;
        terminal.onWritePty = (data) => received = data;
        terminal.onDeviceAttributes = null;
        terminal.write(Uint8List.fromList('\x1b[c'.codeUnits));
        final response = String.fromCharCodes(received!);
        expect(response, contains('\x1b[?62'));
      });
    });

    group('RowIterator', () {
      group('properties', () {
        test('empty row has no content flags', () {
          renderState.update(terminal);
          rows.reset(renderState);
          rows.next();
          expect(rows.hasGrapheme, isFalse);
          expect(rows.hasStyled, isFalse);
          expect(rows.hasHyperlink, isFalse);
          expect(rows.hasKittyVirtualPlaceholder, isFalse);
          expect(rows.semanticPrompt, SemanticPrompt.none);
        });

        test('styled row reports hasStyled', () {
          terminal.write(Uint8List.fromList('\x1b[1mBold'.codeUnits));
          renderState.update(terminal);
          rows.reset(renderState);
          rows.next();
          expect(rows.hasStyled, isTrue);
        });

        test('index tracks row position', () {
          renderState.update(terminal);
          rows.reset(renderState);
          rows.next();
          expect(rows.index, 0);
          rows.next();
          expect(rows.index, 1);
        });
      });
    });

    group('CellIterator', () {
      void advanceToFirstCell() {
        renderState.update(terminal);
        rows.reset(renderState);
        rows.next();
        cells.reset(rows);
        cells.next();
      }

      group('properties', () {
        test('default cell has no styling, protection, or special content', () {
          terminal.write(Uint8List.fromList('A'.codeUnits));
          advanceToFirstCell();
          expect(cells.style.bold, isFalse);
          expect(cells.isProtected, isFalse);
          expect(cells.semanticContent, SemanticContent.output);
          expect(cells.backgroundArgb, isNull);
          expect(cells.foregroundArgb, isNull);
        });

        test('styled cell reports hasStyling', () {
          terminal.write(Uint8List.fromList('\x1b[1mB'.codeUnits));
          advanceToFirstCell();
          expect(cells.hasStyling, isTrue);
        });

        test('codepoint returns value for text and 0 for empty cell', () {
          terminal.write(Uint8List.fromList('Z'.codeUnits));
          advanceToFirstCell();
          expect(cells.codepoint, 0x5A);

          cells.next();
          expect(cells.codepoint, 0);
        });

        test('col tracks column position', () {
          terminal.write(Uint8List.fromList('ABC'.codeUnits));
          advanceToFirstCell();
          expect(cells.col, 0);
          cells.next();
          expect(cells.col, 1);
        });

        test('graphemeLength is 1 for single codepoint and 0 for empty', () {
          terminal.write(Uint8List.fromList('A'.codeUnits));
          advanceToFirstCell();
          expect(cells.graphemeLength, 1);

          cells.next();
          expect(cells.graphemeLength, 0);
        });

        test('color ARGB returns packed values for RGB colors', () {
          terminal.write(
            .fromList('\x1b[48;2;255;128;0m\x1b[38;2;0;255;64mY'.codeUnits),
          );
          advanceToFirstCell();
          expect(cells.backgroundArgb, 0xFFFF8000);
          expect(cells.foregroundArgb, 0xFF00FF40);
        });
      });
    });

    group('Cursor properties', () {
      test('cursor wideTail is false on normal position', () {
        renderState.update(terminal);
        final cursor = renderState.cursor;
        expect(cursor.wideTail, isFalse);
      });
    });

    group('Formatter', () {
      test('plain format returns screen content', () {
        terminal.write(Uint8List.fromList('Hello'.codeUnits));
        final formatter = Formatter(
          terminal: terminal,
          format: .plain,
          trim: true,
        );
        addTearDown(formatter.dispose);
        expect(formatter.format(), contains('Hello'));
      });

      test('selection restricts output to the given range', () {
        terminal.write(Uint8List.fromList('ABCDE\r\nFGHIJ'.codeUnits));
        final formatter = Formatter(
          terminal: terminal,
          format: .plain,
          selection: Selection.fromRefs(
            start: GridRef.at(terminal, col: 0, row: 0),
            end: GridRef.at(terminal, col: 2, row: 0),
          ),
        );
        addTearDown(formatter.dispose);
        final text = formatter.format();
        expect(text, contains('ABC'));
        expect(text, isNot(contains('FGHIJ')));
      });
    });

    group('formatSelection', () {
      test('returns null without an active selection', () {
        final text = terminal.formatSelection();

        expect(text, isNull);
      });

      test('formats an explicit selection', () {
        terminal.write(Uint8List.fromList('ABCDE'.codeUnits));
        final selection = Selection.fromRefs(
          start: GridRef.at(terminal, col: 1, row: 0),
          end: GridRef.at(terminal, col: 3, row: 0),
        );

        final text = terminal.formatSelection(selection: selection);

        expect(text, 'BCD');
      });
    });

    group('selectAll', () {
      test('selects all screen content', () {
        terminal.write(Uint8List.fromList('ABC\r\nDEF'.codeUnits));

        final selection = terminal.selectAll();

        expect(
          terminal.formatSelection(selection: selection, trim: true),
          'ABC\nDEF',
        );
      });
    });

    group('selectLine', () {
      test('selects the line under a ref', () {
        terminal.write(Uint8List.fromList('ABC\r\nDEF'.codeUnits));
        final ref = GridRef.at(terminal, col: 1, row: 1);

        final selection = terminal.selectLine(ref);

        expect(
          terminal.formatSelection(selection: selection, trim: true),
          'DEF',
        );
      });
    });

    group('selectOutput', () {
      test('selects command output under a ref', () {
        terminal.write(
          Uint8List.fromList(
            '\x1b]133;A\x07\$ \x1b]133;B\x07ls\r\n'
                    '\x1b]133;C\x07ABC\r\nDEF\x1b]133;D\x07'
                .codeUnits,
          ),
        );
        final ref = GridRef.at(terminal, col: 1, row: 1);

        final selection = terminal.selectOutput(ref);

        expect(
          terminal.formatSelection(selection: selection, trim: true),
          'ABC\nDEF',
        );
      });
    });

    group('selectWord', () {
      test('returns the selected word', () {
        terminal.write(Uint8List.fromList('hello world'.codeUnits));
        final ref = GridRef.at(terminal, col: 1, row: 0);

        final selection = terminal.selectWord(ref);

        expect(terminal.formatSelection(selection: selection), 'hello');
      });

      test('rejects refs from another terminal', () {
        final other = Terminal(cols: 80, rows: 24);
        addTearDown(other.dispose);
        final ref = GridRef.at(other, col: 0, row: 0);

        expect(() => terminal.selectWord(ref), throwsA(isA<ArgumentError>()));
      });
    });

    group('selectWordBetween', () {
      test('selects the word between two refs', () {
        terminal.write(Uint8List.fromList('hello world'.codeUnits));
        final start = GridRef.at(terminal, col: 1, row: 0);
        final end = GridRef.at(terminal, col: 3, row: 0);

        final selection = terminal.selectWordBetween(start, end);

        expect(terminal.formatSelection(selection: selection), 'hello');
      });
    });

    group('selection', () {
      test('setter installs active selection', () {
        terminal.write(Uint8List.fromList('ABCDE'.codeUnits));
        final selection = Selection.fromRefs(
          start: GridRef.at(terminal, col: 0, row: 0),
          end: GridRef.at(terminal, col: 2, row: 0),
        );

        terminal.selection = selection;

        expect(terminal.formatSelection(), 'ABC');
      });

      test('getter returns active selection', () {
        terminal.write(Uint8List.fromList('ABCDE'.codeUnits));
        final selection = Selection.fromRefs(
          start: GridRef.at(terminal, col: 0, row: 0),
          end: GridRef.at(terminal, col: 2, row: 0),
        );
        terminal.selection = selection;

        final active = terminal.selection;

        expect(active?.equal(selection), isTrue);
      });

      test('setter clears active selection', () {
        terminal.write(Uint8List.fromList('ABCDE'.codeUnits));
        terminal.selection = Selection.fromRefs(
          start: GridRef.at(terminal, col: 0, row: 0),
          end: GridRef.at(terminal, col: 2, row: 0),
        );

        terminal.selection = null;

        expect(terminal.selection, isNull);
      });

      test('setter rejects selections from another terminal', () {
        final other = Terminal(cols: 80, rows: 24);
        addTearDown(other.dispose);
        final selection = Selection.fromRefs(
          start: GridRef.at(other, col: 0, row: 0),
          end: GridRef.at(other, col: 2, row: 0),
        );

        expect(
          () => terminal.selection = selection,
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('CellIterator.select', () {
      test('reads specific column content', () {
        terminal.write(Uint8List.fromList('ABCDE'.codeUnits));
        renderState.update(terminal);
        rows.reset(renderState);
        rows.next();
        cells.reset(rows);

        cells.select(2);
        expect(cells.content, 'C');

        cells.select(0);
        expect(cells.content, 'A');

        cells.select(4);
        expect(cells.content, 'E');
      });
    });
  });
}

void clearDirty(RenderState renderState, RowIterator rows) {
  rows.reset(renderState);
  while (rows.next()) {
    rows.dirty = false;
  }
  renderState.dirty = DirtyState.clean;
}

void _expectAllCellsEmpty(Terminal terminal) {
  final rs = RenderState();
  final rowIter = RowIterator();
  final cellIter = CellIterator();
  try {
    rs.update(terminal);
    rowIter.reset(rs);
    while (rowIter.next()) {
      cellIter.reset(rowIter);
      while (cellIter.next()) {
        expect(
          cellIter.hasText,
          isFalse,
          reason: 'cell at (${rowIter.index}, ${cellIter.col}) should be empty',
        );
      }
    }
  } finally {
    cellIter.dispose();
    rowIter.dispose();
    rs.dispose();
  }
}
