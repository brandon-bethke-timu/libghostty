import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flterm/src/rendering/kitty_image_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KittyImageCache', () {
    test('dispose clears ready entries and is idempotent', () async {
      final cache = KittyImageCache(onImageReady: () {});
      final image = await _testImage();

      cache.putReady(1, image);
      expect(cache.lookupById(1), isA<KittyImageReady>());

      cache.dispose();
      cache.dispose();

      expect(cache.lookupById(1), isNull);
    });
  });
}

Future<ui.Image> _testImage() {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    Uint8List.fromList([0xff, 0xff, 0xff, 0xff]),
    1,
    1,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
