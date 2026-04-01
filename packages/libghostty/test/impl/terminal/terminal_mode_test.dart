@Tags(['ffi'])
library;

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('TerminalMode', () {
    test('modeValue extracts numeric value', () {
      expect(const TerminalMode.bracketedPaste().modeValue, 2004);
      expect(const TerminalMode.cursorKeys().modeValue, 1);
    });

    test('modeValue strips ANSI flag', () {
      expect(const TerminalMode.insert().modeValue, 4);
      expect(const TerminalMode.kam().modeValue, 2);
    });

    test('isAnsi is false for DEC private modes', () {
      expect(const TerminalMode.bracketedPaste().isAnsi, isFalse);
      expect(const TerminalMode.cursorKeys().isAnsi, isFalse);
    });

    test('isAnsi is true for ANSI modes', () {
      expect(const TerminalMode.insert().isAnsi, isTrue);
      expect(const TerminalMode.kam().isAnsi, isTrue);
      expect(const TerminalMode.srm().isAnsi, isTrue);
      expect(const TerminalMode.linefeed().isAnsi, isTrue);
    });

    test('encodeReport produces non-empty sequence', () {
      final result = const TerminalMode.bracketedPaste().encodeReport(.set);
      expect(result, isNotEmpty);
    });

    test('encodeReport for ANSI mode produces non-empty sequence', () {
      final result = const TerminalMode.insert().encodeReport(.reset);
      expect(result, isNotEmpty);
    });
  });
}
