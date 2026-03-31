import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('KittyKeyFlags', () {
    test('disabled has value 0', () {
      expect(const KittyKeyFlags.disabled().isDisabled, isTrue);
    });

    test('all combines all flags', () {
      expect(const KittyKeyFlags.all().isDisabled, isFalse);
    });

    test('| operator combines flags', () {
      final combined =
          const KittyKeyFlags.disambiguate() |
          const KittyKeyFlags.reportEvents();
      expect(combined.isDisabled, isFalse);
    });

    test('equality compares by value', () {
      final a =
          const KittyKeyFlags.disambiguate() |
          const KittyKeyFlags.reportEvents();
      final b =
          const KittyKeyFlags.reportEvents() |
          const KittyKeyFlags.disambiguate();
      expect(a, equals(b));
    });

    test('inequality for different values', () {
      expect(
        const KittyKeyFlags.disambiguate(),
        isNot(equals(const KittyKeyFlags.reportEvents())),
      );
    });

    test('hashCode is consistent with equality', () {
      final a =
          const KittyKeyFlags.disambiguate() | const KittyKeyFlags.reportAll();
      final b =
          const KittyKeyFlags.reportAll() | const KittyKeyFlags.disambiguate();
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
