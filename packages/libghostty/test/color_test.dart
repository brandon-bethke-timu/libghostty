import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('RgbColor', () {
    test('constructor stores components', () {
      const color = RgbColor(10, 20, 30);
      expect(color.r, 10);
      expect(color.g, 20);
      expect(color.b, 30);
    });

    test('equality and hashCode', () {
      const a = RgbColor(100, 150, 200);
      const b = RgbColor(100, 150, 200);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(const RgbColor(100, 150, 201))));
    });

    test('toString contains components', () {
      const color = RgbColor(10, 20, 30);
      expect(color.toString(), 'RgbColor(10, 20, 30)');
    });
  });

  group('NamedColor', () {
    test('standard colors have expected indices', () {
      expect(const NamedColor.black(), 0);
      expect(const NamedColor.red(), 1);
      expect(const NamedColor.green(), 2);
      expect(const NamedColor.yellow(), 3);
      expect(const NamedColor.blue(), 4);
      expect(const NamedColor.magenta(), 5);
      expect(const NamedColor.cyan(), 6);
      expect(const NamedColor.white(), 7);
    });

    test('bright colors have expected indices', () {
      expect(const NamedColor.brightBlack(), 8);
      expect(const NamedColor.brightRed(), 9);
      expect(const NamedColor.brightGreen(), 10);
      expect(const NamedColor.brightYellow(), 11);
      expect(const NamedColor.brightBlue(), 12);
      expect(const NamedColor.brightMagenta(), 13);
      expect(const NamedColor.brightCyan(), 14);
      expect(const NamedColor.brightWhite(), 15);
    });
  });
}
