@Tags(['ffi'])
library;

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('FocusEvent.encode', () {
    test('gained encodes as CSI I', () {
      final result = FocusEvent.gained.encode();
      expect(result, '\x1b[I');
    });

    test('lost encodes as CSI O', () {
      final result = FocusEvent.lost.encode();
      expect(result, '\x1b[O');
    });
  });

  group('SizeReportStyle.encode', () {
    test('mode2048 encodes in-band size report', () {
      final result = SizeReportStyle.mode2048.encode(
        rows: 24,
        columns: 80,
        cellWidth: 8,
        cellHeight: 16,
      );
      expect(result, startsWith('\x1b[48;'));
      expect(result, endsWith('t'));
      expect(result, contains('24'));
      expect(result, contains('80'));
    });

    test('csi14T encodes text area size in pixels', () {
      final result = SizeReportStyle.csi14T.encode(
        rows: 24,
        columns: 80,
        cellWidth: 8,
        cellHeight: 16,
      );
      expect(result, startsWith('\x1b[4;'));
      expect(result, endsWith('t'));
    });

    test('csi16T encodes cell size in pixels', () {
      final result = SizeReportStyle.csi16T.encode(
        rows: 24,
        columns: 80,
        cellWidth: 8,
        cellHeight: 16,
      );
      expect(result, startsWith('\x1b[6;'));
      expect(result, endsWith('t'));
    });

    test('csi18T encodes text area size in characters', () {
      final result = SizeReportStyle.csi18T.encode(
        rows: 24,
        columns: 80,
        cellWidth: 8,
        cellHeight: 16,
      );
      expect(result, startsWith('\x1b[8;'));
      expect(result, endsWith('t'));
      expect(result, contains('24'));
      expect(result, contains('80'));
    });
  });
}
