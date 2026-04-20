@Tags(['ffi'])
library;

import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

/// Kitty graphics APC for a 1x1 RGB image (red pixel), id=42, action=transmit
/// only (no placement). Wire format:
///   ESC _ G f=24,s=1,v=1,a=t,i=42 ; base64("\xff\x00\x00") ESC \
Uint8List _transmitRedPixel({int id = 42}) {
  return Uint8List.fromList(
    '\x1b_Gf=24,s=1,v=1,a=t,i=$id;/wAA\x1b\\'.codeUnits,
  );
}

void main() {
  group('Terminal.kittyGraphics', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: 80, rows: 24);
      terminal.kittyImageStorageLimit = 1 << 20; // 1 MiB enables storage
    });

    test('returns a handle when kitty graphics are enabled at build time', () {
      expect(terminal.kittyGraphics, isNotNull);
    });

    test('image() returns null for an unknown id', () {
      expect(terminal.kittyGraphics?.image(99999), isNull);
    });

    test('image() exposes metadata after a transmit APC', () {
      terminal.write(_transmitRedPixel());

      final image = terminal.kittyGraphics?.image(42);
      expect(image, isNotNull);
      expect(image!.id, 42);
      expect(image.width, 1);
      expect(image.height, 1);
      expect(image.format, KittyImageFormat.rgb);
    });

    test('image().pixelData returns the decoded RGB bytes', () {
      terminal.write(_transmitRedPixel(id: 7));

      final image = terminal.kittyGraphics!.image(7)!;
      expect(image.pixelData, equals(Uint8List.fromList([0xff, 0x00, 0x00])));
    });
  });

  group('LibGhostty.setPngDecoder', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: 80, rows: 24);
      terminal.kittyImageStorageLimit = 1 << 20;
    });

    tearDown(LibGhostty.clearPngDecoder);

    test('is invoked with PNG payload and produces an image', () {
      final pngBytesSeen = <Uint8List>[];
      LibGhostty.setPngDecoder((bytes) {
        pngBytesSeen.add(Uint8List.fromList(bytes));
        // Return a fixed 2x1 RGBA image regardless of input bytes.
        return (
          width: 2,
          height: 1,
          rgba: Uint8List.fromList([
            0xff,
            0x00,
            0x00,
            0xff,
            0x00,
            0xff,
            0x00,
            0xff,
          ]),
        );
      });

      // f=100 (PNG), a=t (transmit), i=55, payload is base64 "hello" bytes.
      terminal.write(
        Uint8List.fromList('\x1b_Gf=100,a=t,i=55;aGVsbG8=\x1b\\'.codeUnits),
      );

      expect(pngBytesSeen, hasLength(1));
      final image = terminal.kittyGraphics!.image(55);
      expect(image, isNotNull);
      expect(image!.width, 2);
      expect(image.height, 1);
      expect(image.format, KittyImageFormat.rgba);
      expect(image.pixelData, hasLength(8));
    });

    test('returning null rejects the payload', () {
      LibGhostty.setPngDecoder((_) => null);

      terminal.write(
        Uint8List.fromList('\x1b_Gf=100,a=t,i=56;aGVsbG8=\x1b\\'.codeUnits),
      );

      expect(terminal.kittyGraphics!.image(56), isNull);
    });

    test('clearPngDecoder stops routing to the Dart callback', () {
      var called = 0;
      LibGhostty.setPngDecoder((_) {
        called++;
        return (width: 1, height: 1, rgba: Uint8List(4));
      });
      LibGhostty.clearPngDecoder();

      terminal.write(
        Uint8List.fromList('\x1b_Gf=100,a=t,i=57;aGVsbG8=\x1b\\'.codeUnits),
      );
      expect(called, 0);
      expect(terminal.kittyGraphics!.image(57), isNull);
    });
  });

  group('Terminal.kittyGraphics.placements', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: 80, rows: 24);
      terminal.kittyImageStorageLimit = 1 << 20;
    });

    test('returns an empty list when no placements exist', () {
      expect(terminal.kittyGraphics?.placements(), isEmpty);
    });

    test('captures a placement emitted via transmit+display', () {
      // a=T transmits and places at the cursor; default columns/rows=0
      // means "derive from image size".
      terminal.write(
        Uint8List.fromList(
          '\x1b_Gf=24,s=1,v=1,a=T,i=11,c=2,r=1;/wAA\x1b\\'.codeUnits,
        ),
      );

      final placements = terminal.kittyGraphics!.placements();
      expect(placements, hasLength(1));
      final p = placements.single;
      expect(p.imageId, 11);
      expect(p.isVirtual, isFalse);
      expect(p.renderInfo.viewportVisible, isTrue);
      expect(p.renderInfo.viewportCol, 0);
      expect(p.renderInfo.viewportRow, 0);
      expect(p.renderInfo.gridCols, 2);
      expect(p.renderInfo.gridRows, 1);
      expect(p.renderInfo.sourceWidth, 1);
      expect(p.renderInfo.sourceHeight, 1);
    });
  });
}
