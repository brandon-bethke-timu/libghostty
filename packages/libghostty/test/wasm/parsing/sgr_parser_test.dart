@Tags(['wasm'])
library;

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

import '../helpers/setup.dart';

Matcher hasTag(SgrAttributeTag tag) =>
    predicate<SgrAttribute>((a) => a.tag == tag, 'has tag $tag');

void main() {
  setUpAll(setUpWasm);

  group('SgrParser', () {
    late SgrParser parser;

    setUp(() {
      parser = SgrParser();
    });

    tearDown(() {
      parser.dispose();
    });

    test('parses bold', () {
      final attrs = parser.parse([1]);
      expect(attrs, hasLength(1));
      expect(attrs.first, hasTag(SgrAttributeTag.bold));
    });

    test('parses bold and red foreground', () {
      final attrs = parser.parse([1, 31]);
      expect(attrs, hasLength(2));
      expect(attrs[0], hasTag(SgrAttributeTag.bold));
      expect(attrs[1], hasTag(SgrAttributeTag.fg8));
      expect(attrs[1].paletteIndex, const NamedColor.red());
    });

    test('parses italic', () {
      final attrs = parser.parse([3]);
      expect(attrs, hasLength(1));
      expect(attrs.first, hasTag(SgrAttributeTag.italic));
    });

    test('parses reset (SGR 0)', () {
      final attrs = parser.parse([0]);
      expect(attrs, hasLength(1));
      expect(attrs.first, hasTag(SgrAttributeTag.unset));
    });

    test('parses RGB foreground color', () {
      final attrs = parser.parse([38, 2, 51, 102, 153]);
      expect(attrs, hasLength(1));
      expect(attrs.first, hasTag(SgrAttributeTag.directColorFg));
      expect(attrs.first.color, const RgbColor(51, 102, 153));
    });

    test('parses RGB background color', () {
      final attrs = parser.parse([48, 2, 10, 20, 30]);
      expect(attrs, hasLength(1));
      expect(attrs.first, hasTag(SgrAttributeTag.directColorBg));
      expect(attrs.first.color, const RgbColor(10, 20, 30));
    });

    test('parses 256-color foreground', () {
      final attrs = parser.parse([38, 5, 196]);
      expect(attrs, hasLength(1));
      expect(attrs.first, hasTag(SgrAttributeTag.fg256));
      expect(attrs.first.paletteIndex, 196);
    });

    test('parses curly underline with colon separator', () {
      final attrs = parser.parse([4, 3], separators: [':', ';']);
      expect(attrs, hasLength(1));
      expect(attrs.first, hasTag(SgrAttributeTag.underline));
      expect(attrs.first.underlineStyle, UnderlineStyle.curly);
    });

    test('parses complex styling: curly underline + RGB foreground', () {
      final attrs = parser.parse(
        [4, 3, 38, 2, 51, 51, 51],
        separators: [':', ';', ';', ';', ';', ';', ';'],
      );
      expect(attrs.length, greaterThanOrEqualTo(2));

      final underline = attrs
          .where((a) => a.tag == SgrAttributeTag.underline)
          .firstOrNull;
      expect(underline, isNotNull);
      expect(underline!.underlineStyle, UnderlineStyle.curly);

      final fg = attrs
          .where((a) => a.tag == SgrAttributeTag.directColorFg)
          .firstOrNull;
      expect(fg, isNotNull);
      expect(fg!.color, const RgbColor(51, 51, 51));
    });

    test('parses strikethrough', () {
      final attrs = parser.parse([9]);
      expect(attrs, hasLength(1));
      expect(attrs.first, hasTag(SgrAttributeTag.strikethrough));
    });

    test('parses inverse', () {
      final attrs = parser.parse([7]);
      expect(attrs, hasLength(1));
      expect(attrs.first, hasTag(SgrAttributeTag.inverse));
    });

    test('parser can be reused', () {
      final first = parser.parse([1]);
      expect(first.first, hasTag(SgrAttributeTag.bold));

      final second = parser.parse([3]);
      expect(second.first, hasTag(SgrAttributeTag.italic));
    });
  });
}
