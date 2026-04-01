@Tags(['ffi'])
library;

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('MouseEvent', () {
    late MouseEvent event;

    setUp(() => event = MouseEvent());

    tearDown(() => event.dispose());

    test('defaults to press action, no button, no mods', () {
      expect(event.action, MouseAction.press);
      expect(event.button, isNull);
      expect(event.mods, const Mods.none());
    });

    test('set and get action', () {
      event.action = MouseAction.release;
      expect(event.action, MouseAction.release);

      event.action = MouseAction.motion;
      expect(event.action, MouseAction.motion);
    });

    test('set and get button', () {
      event.button = MouseButton.left;
      expect(event.button, MouseButton.left);

      event.button = MouseButton.right;
      expect(event.button, MouseButton.right);
    });

    test('clearButton resets to null', () {
      event.button = MouseButton.left;
      event.clearButton();
      expect(event.button, isNull);
    });

    test('set and get mods', () {
      event.mods = const Mods.ctrl() | const Mods.shift();
      expect(event.mods.hasCtrl, isTrue);
      expect(event.mods.hasShift, isTrue);
      expect(event.mods.hasAlt, isFalse);
    });

    test('setPosition and get position roundtrip', () {
      event.setPosition(10.5, 20.5);
      final (x, y) = event.position;
      expect(x, closeTo(10.5, 0.01));
      expect(y, closeTo(20.5, 0.01));
    });

    test('double dispose is safe', () {
      final e = MouseEvent();
      e.dispose();
      e.dispose();
    });
  });
}
