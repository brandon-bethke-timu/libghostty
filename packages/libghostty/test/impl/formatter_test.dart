@Tags(['ffi'])
library;

import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('Formatter', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: 80, rows: 24);
    });

    tearDown(() {
      terminal.dispose();
    });

    test('plain text format returns terminal content', () {
      terminal.write(Uint8List.fromList('Hello World'.codeUnits));
      final formatter = terminal.createFormatter(format: FormatterFormat.plain);
      addTearDown(formatter.dispose);

      final result = formatter.format();
      expect(result, contains('Hello World'));
    });

    test('vt format preserves escape sequences', () {
      terminal.write(Uint8List.fromList('\x1b[1mBold\x1b[0m'.codeUnits));
      final formatter = terminal.createFormatter(format: FormatterFormat.vt);
      addTearDown(formatter.dispose);

      final result = formatter.format();
      expect(result, contains('Bold'));
      expect(result, contains('\x1b['));
    });

    test('trim strips trailing whitespace', () {
      terminal.write(Uint8List.fromList('Hi'.codeUnits));
      final trimmed = terminal.createFormatter(
        format: FormatterFormat.plain,
        trim: true,
      );
      addTearDown(trimmed.dispose);

      final result = trimmed.format();
      expect(result.trimRight(), result);
    });

    test('vt format with cursor extra includes CUP sequence', () {
      terminal.write(Uint8List.fromList('Hi'.codeUnits));
      final formatter = terminal.createFormatter(
        format: FormatterFormat.vt,
        extra: const FormatterExtra(cursor: true),
      );
      addTearDown(formatter.dispose);

      final result = formatter.format();
      expect(result, contains('\x1b['));
      expect(result, contains('H'));
    });

    test('vt format with all extras produces more output', () {
      terminal.write(Uint8List.fromList('Hi'.codeUnits));
      final withoutExtras = terminal.createFormatter(
        format: FormatterFormat.vt,
      );
      final withExtras = terminal.createFormatter(
        format: FormatterFormat.vt,
        extra: const FormatterExtra.all(),
      );
      addTearDown(withoutExtras.dispose);
      addTearDown(withExtras.dispose);

      final basic = withoutExtras.format();
      final full = withExtras.format();
      expect(full.length, greaterThan(basic.length));
    });

    test('double dispose is safe', () {
      final formatter = terminal.createFormatter(format: FormatterFormat.plain);
      formatter.dispose();
      formatter.dispose();
    });
  });
}
