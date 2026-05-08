import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/glyph_atlas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GlyphAtlas', () {
    late GlyphAtlas atlas;

    setUp(() {
      atlas = GlyphAtlas(
        fontFamily: 'monospace',
        fontFamilyFallback: const [],
        fontSize: 14,
      );
    });

    tearDown(() => atlas.dispose());

    group('configure', () {
      test('sets dimensions, pre-seeds glyphs, and creates atlas image', () {
        atlas.configure(dpr: 2.0, metrics: _metrics);

        expect(atlas.devicePixelRatio, 2.0);
        expect(atlas.cacheSize, greaterThan(0));
        expect(atlas.image, isNotNull);
      });

      test('is no-op when called with same values', () {
        atlas.configure(dpr: 2.0, metrics: _metrics);
        final sizeAfterFirst = atlas.cacheSize;
        final imageAfterFirst = atlas.image;

        atlas.configure(dpr: 2.0, metrics: _metrics);
        expect(atlas.cacheSize, sizeAfterFirst);
        expect(atlas.image, same(imageAfterFirst));
      });

      test('clears and re-seeds on DPR change', () {
        atlas.configure(dpr: 1.0, metrics: _metrics);
        final sizeBefore = atlas.cacheSize;
        final imageBefore = atlas.image;

        atlas.configure(dpr: 2.0, metrics: _metrics);
        expect(atlas.cacheSize, sizeBefore);
        expect(atlas.image, isNot(same(imageBefore)));
      });
    });

    group('addCodepoint', () {
      test('creates entry and returns cached on second call', () {
        atlas.configure(dpr: 1.0, metrics: _metrics);

        final entry1 = atlas.addCodepoint(0x100, bold: false, italic: false);
        final entry2 = atlas.addCodepoint(0x100, bold: false, italic: false);

        expect(entry1.srcRight, greaterThan(entry1.srcLeft));
        expect(identical(entry1, entry2), isTrue);
      });

      test('different styles produce different entries', () {
        atlas.configure(dpr: 1.0, metrics: _metrics);

        final plain = atlas.addCodepoint(0x41, bold: false, italic: false);
        final bold = atlas.addCodepoint(0x41, bold: true, italic: false);
        expect(identical(plain, bold), isFalse);
      });

      test('sprite codepoints reuse geometry across styles', () {
        atlas.configure(dpr: 1.0, metrics: _metrics);

        for (final codepoint in _spriteSamples) {
          final plain = atlas.addCodepoint(
            codepoint,
            bold: false,
            italic: false,
          );
          final boldItalic = atlas.addCodepoint(
            codepoint,
            bold: true,
            italic: true,
          );

          expect(identical(plain, boldItalic), isTrue, reason: '$codepoint');
        }
      });

      test('span participates in sprite cache key', () {
        atlas.configure(dpr: 1.0, metrics: _metrics);

        final single = atlas.addCodepoint(0xE0B0, bold: false, italic: false);
        final doubleWidth = atlas.addCodepoint(
          0xE0B0,
          bold: false,
          italic: false,
          span: 2,
        );

        expect(identical(single, doubleWidth), isFalse);
        expect(
          doubleWidth.srcRight - doubleWidth.srcLeft,
          greaterThan(single.srcRight - single.srcLeft),
        );
      });
    });

    group('add', () {
      test('creates entry and returns cached on second call', () {
        atlas.configure(dpr: 1.0, metrics: _metrics);
        final sizeBefore = atlas.cacheSize;

        const key = (text: '\u{1234}', bold: false, italic: false);
        final entry1 = atlas.add(key);
        final entry2 = atlas.add(key);

        expect(atlas.cacheSize, sizeBefore + 1);
        expect(identical(entry1, entry2), isTrue);
      });

      test('wide entry spans 2 cells', () {
        atlas.configure(dpr: 1.0, metrics: _metrics);

        const key = (text: '\u{4e00}', bold: false, italic: false);
        final entry = atlas.add(key, span: 2);

        final expectedWidth = (8.0 * 2 * 1.0).ceil().toDouble();
        expect(entry.srcRight - entry.srcLeft, expectedWidth);
        expect(entry.isEmoji, isFalse);
      });

      test('emoji entry has isEmoji true', () {
        atlas.configure(dpr: 1.0, metrics: _metrics);

        const key = (text: '\u{1F600}', bold: false, italic: false);
        final entry = atlas.add(key, emoji: true);
        expect(entry.isEmoji, isTrue);
      });

      test('sequential adds produce non-overlapping positions', () {
        atlas.configure(dpr: 1.0, metrics: _metrics);

        final entries = <GlyphEntry>[];
        for (var code = 0x300; code < 0x310; code++) {
          entries.add(
            atlas.add((
              text: String.fromCharCode(code),
              bold: false,
              italic: false,
            )),
          );
        }

        for (var i = 0; i < entries.length; i++) {
          for (var j = i + 1; j < entries.length; j++) {
            final a = entries[i];
            final b = entries[j];
            final overlap =
                a.srcLeft < b.srcRight &&
                a.srcRight > b.srcLeft &&
                a.srcTop < b.srcBottom &&
                a.srcBottom > b.srcTop;
            expect(overlap, isFalse, reason: 'entries $i and $j overlap');
          }
        }
      });

      test('early positions remain stable after many adds', () {
        atlas.configure(dpr: 1.0, metrics: _metrics);

        final earlyEntries = <GlyphEntry>[];
        for (var code = 0x400; code < 0x410; code++) {
          earlyEntries.add(
            atlas.add((
              text: String.fromCharCode(code),
              bold: false,
              italic: false,
            )),
          );
        }

        final positions = earlyEntries
            .map((e) => (e.srcLeft, e.srcTop, e.srcRight, e.srcBottom))
            .toList();

        for (var code = 0x410; code < 0x600; code++) {
          atlas.add((
            text: String.fromCharCode(code),
            bold: false,
            italic: false,
          ));
        }

        for (var i = 0; i < earlyEntries.length; i++) {
          final e = earlyEntries[i];
          final p = positions[i];
          expect(e.srcLeft, p.$1);
          expect(e.srcTop, p.$2);
          expect(e.srcRight, p.$3);
          expect(e.srcBottom, p.$4);
        }
      });
    });

    group('ensureImage', () {
      test('composites pending glyphs into atlas image', () {
        atlas.configure(dpr: 1.0, metrics: _metrics);

        atlas.add((text: '\u{1234}', bold: false, italic: false));
        atlas.ensureImage();
        expect(atlas.image, isNotNull);
      });

      test('composites pending sprite glyphs into atlas image', () {
        atlas.configure(dpr: 1.0, metrics: _metrics);

        for (final codepoint in _spriteSamples) {
          atlas.addCodepoint(codepoint, bold: false, italic: false);
        }
        atlas.ensureImage();
        expect(atlas.image, isNotNull);
      });

      test('is no-op when no pending glyphs', () {
        atlas.configure(dpr: 1.0, metrics: _metrics);
        final imageBefore = atlas.image;

        atlas.ensureImage();
        expect(atlas.image, same(imageBefore));
      });
    });

    group('clear', () {
      test('resets caches and image', () {
        atlas.configure(dpr: 1.0, metrics: _metrics);
        atlas.add((text: 'X', bold: false, italic: false));
        expect(atlas.cacheSize, greaterThan(0));
        expect(atlas.image, isNotNull);

        atlas.clear();

        expect(atlas.cacheSize, 0);
        expect(atlas.image, isNull);
      });
    });

    group('dispose', () {
      test('releases image', () {
        atlas.configure(dpr: 1.0, metrics: _metrics);
        expect(atlas.image, isNotNull);

        atlas.dispose();
        expect(atlas.image, isNull);
      });
    });
  });
}

const _metrics = CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12);

// One representative codepoint from each sprite family in the registry.
// dart format off
const _spriteSamples = [
  0x2500, // ─ box drawing
  0x25E2, // ◢ geometric shapes
  0xF5D6, //   branch drawing
  0x1CC21, //   legacy supplement (box dash combo)
  0x1CC30, //   legacy supplement (circle piece)
  0x1CE0B, //   legacy supplement (block stub)
  0x1FB95, //   legacy computing (checkerboard)
  0x1FBBD, //   legacy computing (filled polygon)
];
// dart format on
