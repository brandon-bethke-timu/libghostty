@Tags(['ffi'])
library;

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('MouseEncoder', () {
    late MouseEncoder encoder;
    late MouseEvent event;

    setUp(() {
      encoder = MouseEncoder();
      event = MouseEvent()
        ..action = MouseAction.press
        ..button = MouseButton.left
        ..setPosition(10.0, 5.0);
    });

    tearDown(() {
      event.dispose();
      encoder.dispose();
    });

    test('encode returns empty without tracking mode', () {
      expect(encoder.encode(event), isEmpty);
    });

    test('setSize accepts size with and without padding', () {
      encoder.setSize(
        const MouseEncoderSize(
          screenWidth: 800,
          screenHeight: 600,
          cellWidth: 8,
          cellHeight: 16,
        ),
      );
      encoder.setSize(
        const MouseEncoderSize(
          screenWidth: 800,
          screenHeight: 600,
          cellWidth: 8,
          cellHeight: 16,
          paddingTop: 4,
          paddingBottom: 4,
          paddingLeft: 4,
          paddingRight: 4,
        ),
      );
    });

    test('encode produces SGR output with terminal-synced tracking', () {
      final terminal = Terminal(cols: 80, rows: 24);
      addTearDown(terminal.dispose);

      terminal.write(.fromList('\x1b[?1000h\x1b[?1006h'.codeUnits));

      encoder.syncFrom(terminal);
      encoder.setSize(
        const MouseEncoderSize(
          screenWidth: 640,
          screenHeight: 384,
          cellWidth: 8,
          cellHeight: 16,
        ),
      );

      event
        ..action = MouseAction.press
        ..button = MouseButton.left
        ..setPosition(24.0, 32.0);

      final result = encoder.encode(event);
      expect(result, startsWith('\x1b[<'));
      expect(result, endsWith('M'));
    });

    test('encode produces SGR output with manual tracking and format', () {
      encoder.setTrackingMode(MouseTracking.normal);
      encoder.setFormat(MouseFormat.sgr);
      encoder.setSize(
        const MouseEncoderSize(
          screenWidth: 640,
          screenHeight: 384,
          cellWidth: 8,
          cellHeight: 16,
        ),
      );

      event
        ..action = MouseAction.press
        ..button = MouseButton.left
        ..setPosition(24.0, 32.0);

      final result = encoder.encode(event);
      expect(result, startsWith('\x1b[<'));
      expect(result, endsWith('M'));
    });

    test('configuration methods accept values without error', () {
      encoder.setAnyButtonPressed(pressed: true);
      encoder.setAnyButtonPressed(pressed: false);
      encoder.setTrackLastCell(enabled: true);
      encoder.setTrackLastCell(enabled: false);
      encoder.reset();
    });

    test('double dispose is safe', () {
      event.dispose();
      encoder.dispose();
      encoder.dispose();
      encoder = MouseEncoder();
      event = MouseEvent();
    });
  });
}
