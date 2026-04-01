@Tags(['wasm'])
library;

import 'dart:convert';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import 'helpers/setup.dart';

void main() {
  setUpAll(setUpWasm);

  group('pasteIsSafe', () {
    test('rejects content with newlines', () {
      expect(pasteIsSafe('rm -rf /\n'), isFalse);
    });

    test('rejects content with bracketed paste end marker', () {
      expect(pasteIsSafe('\x1b[201~injected'), isFalse);
    });

    test('accepts safe content', () {
      expect(pasteIsSafe(''), isTrue);
      expect(pasteIsSafe('a'), isTrue);
      expect(pasteIsSafe('hello world'), isTrue);
      expect(pasteIsSafe('hello world\ttab'), isTrue);
    });
  });

  group('pasteEncode', () {
    test('wraps with bracketed paste markers when bracketed', () {
      final result = pasteEncode('hello', bracketed: true);
      final decoded = utf8.decode(result);
      expect(decoded, startsWith('\x1b[200~'));
      expect(decoded, endsWith('\x1b[201~'));
      expect(decoded, contains('hello'));
    });

    test('omits bracketed paste markers when not bracketed', () {
      final result = pasteEncode('hello', bracketed: false);
      final decoded = utf8.decode(result);
      expect(decoded, isNot(contains('\x1b[200~')));
      expect(decoded, contains('hello'));
    });

    test('replaces newlines with carriage returns when not bracketed', () {
      final result = pasteEncode('a\nb', bracketed: false);
      final decoded = utf8.decode(result);
      expect(decoded, contains('\r'));
      expect(decoded, isNot(contains('\n')));
    });
  });
}
