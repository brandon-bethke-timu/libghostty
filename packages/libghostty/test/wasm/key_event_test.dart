@Tags(['wasm'])
library;

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import 'helpers/setup.dart';

void main() {
  setUpAll(setUpWasm);

  group('KeyEvent', () {
    late KeyEvent event;

    setUp(() => event = KeyEvent());

    tearDown(() => event.dispose());

    test('defaults to press action, unidentified key, no mods', () {
      expect(event.action, KeyAction.press);
      expect(event.key, Key.unidentified);
      expect(event.mods, const Mods.none());
      expect(event.composing, isFalse);
      expect(event.utf8, isNull);
      expect(event.unshiftedCodepoint, 0);
    });

    test('set and get action', () {
      event.action = KeyAction.press;
      expect(event.action, KeyAction.press);

      event.action = KeyAction.repeat;
      expect(event.action, KeyAction.repeat);
    });

    test('set and get key', () {
      event.key = Key.a;
      expect(event.key, Key.a);

      event.key = Key.arrowUp;
      expect(event.key, Key.arrowUp);
    });

    test('set and get mods', () {
      event.mods = const Mods.ctrl() | const Mods.shift();
      expect(event.mods.hasCtrl, isTrue);
      expect(event.mods.hasShift, isTrue);
      expect(event.mods.hasAlt, isFalse);
    });

    test('set and get consumed mods', () {
      event.consumedMods = const Mods.alt();
      expect(event.consumedMods.hasAlt, isTrue);
      expect(event.consumedMods.hasCtrl, isFalse);
    });

    test('set and get composing', () {
      event.composing = true;
      expect(event.composing, isTrue);
    });

    test('set and get utf8', () {
      event.utf8 = 'a';
      expect(event.utf8, 'a');
    });

    test('set utf8 to null clears it', () {
      event.utf8 = 'x';
      event.utf8 = null;
      expect(event.utf8, isNull);
    });

    test('set and get unshifted codepoint', () {
      event.unshiftedCodepoint = 0x61;
      expect(event.unshiftedCodepoint, 0x61);
    });

    test('can reuse event by changing properties', () {
      event.action = KeyAction.press;
      event.key = Key.a;
      expect(event.key, Key.a);

      event.key = Key.b;
      expect(event.key, Key.b);
      expect(event.action, KeyAction.press);
    });
  });
}
