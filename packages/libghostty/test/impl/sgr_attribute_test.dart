import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('SgrAttribute', () {
    test('stores unknown parameters', () {
      const attr = SgrAttribute(
        tag: SgrAttributeTag.unknown,
        unknownFull: [1, 2],
        unknownPartial: [3],
      );
      expect(attr.unknownFull, [1, 2]);
      expect(attr.unknownPartial, [3]);
    });

    test('stores RGB color', () {
      const attr = SgrAttribute(
        tag: SgrAttributeTag.directColorFg,
        color: RgbColor(255, 128, 64),
      );
      expect(attr.color, const RgbColor(255, 128, 64));
    });

    test('stores palette index', () {
      const attr = SgrAttribute(tag: SgrAttributeTag.fg8, paletteIndex: 5);
      expect(attr.paletteIndex, 5);
    });

    test('stores underline style', () {
      const attr = SgrAttribute(
        tag: SgrAttributeTag.underline,
        underlineStyle: UnderlineStyle.curly,
      );
      expect(attr.underlineStyle, UnderlineStyle.curly);
    });
  });
}
