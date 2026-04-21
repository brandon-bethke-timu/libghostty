@Tags(['ffi', 'golden'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/rendering/kitty_image_cache.dart';
import 'package:flterm/src/rendering/paint_state.dart';
import 'package:flterm/src/rendering/painters/kitty_graphics_painter.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:libghostty/libghostty.dart'
    show DecodedImage, LibGhostty, Terminal;

void main() {
  group('KittyGraphicsPainter golden', () {
    testWidgets('draws a single placement', (tester) async {
      late ui.Image captured;
      await tester.runAsync(() async {
        final cache = KittyImageCache(onImageReady: () {});
        addTearDown(cache.dispose);
        cache.putReady(1, await _imageFromRgba(_quadrantsRgba(), 4, 4));

        const snapshots = <KittyPlacementSnapshot>[
          KittyPlacementSnapshot(
            imageId: 1,
            dst: Rect.fromLTWH(8, 8, 64, 64),
            src: Rect.fromLTWH(0, 0, 4, 4),
            z: 0,
          ),
        ];
        final painter = KittyGraphicsPainter(
          state: _stateFor(cols: 80, rows: 80),
          cache: cache,
          snapshots: snapshots,
          layer: KittyPaintLayer.aboveText,
        );

        captured = await _paint(width: 80, height: 80, draw: painter.paint);
      });
      await expectLater(
        captured,
        matchesGoldenFile('goldens/kitty_single_placement.png'),
      );
    });

    testWidgets('separates below and above layers', (tester) async {
      late ui.Image captured;
      await tester.runAsync(() async {
        final cache = KittyImageCache(onImageReady: () {});
        addTearDown(cache.dispose);
        cache.putReady(1, await _imageFromRgba(_quadrantsRgba(), 4, 4));
        cache.putReady(
          2,
          await _imageFromRgba(
            Uint8List.fromList([0x00, 0xff, 0xff, 0xff]),
            1,
            1,
          ),
        );

        const snapshots = <KittyPlacementSnapshot>[
          KittyPlacementSnapshot(
            imageId: 1,
            dst: Rect.fromLTWH(0, 0, 80, 80),
            src: Rect.fromLTWH(0, 0, 4, 4),
            z: -1,
          ),
          KittyPlacementSnapshot(
            imageId: 2,
            dst: Rect.fromLTWH(40, 0, 40, 40),
            src: Rect.fromLTWH(0, 0, 1, 1),
            z: 0,
          ),
        ];

        final state = _stateFor(cols: 80, rows: 80);
        final below = KittyGraphicsPainter(
          state: state,
          cache: cache,
          snapshots: snapshots,
          layer: KittyPaintLayer.belowText,
        );
        final above = KittyGraphicsPainter(
          state: state,
          cache: cache,
          snapshots: snapshots,
          layer: KittyPaintLayer.aboveText,
        );

        captured = await _paint(
          width: 80,
          height: 80,
          draw: (canvas) {
            below.paint(canvas);
            above.paint(canvas);
          },
        );
      });
      await expectLater(
        captured,
        matchesGoldenFile('goldens/kitty_z_layers.png'),
      );
    });

    testWidgets('routes a PNG through the full pipeline', (tester) async {
      late ui.Image captured;
      await tester.runAsync(() async {
        LibGhostty.setPngDecoder(_decodePng);
        addTearDown(LibGhostty.clearPngDecoder);

        final terminal = Terminal(cols: 80, rows: 24)
          ..kittyImageStorageLimit = 1 << 20;
        addTearDown(terminal.dispose);

        final payload = base64Encode(_loadFixture('test_image.png'));
        terminal.write(
          Uint8List.fromList('\x1b_Gf=100,a=t,i=1;$payload\x1b\\'.codeUnits),
        );

        final image = terminal.kittyGraphics!.image(1)!;
        expect(image.width, 64);
        expect(image.height, 64);

        final cache = KittyImageCache(onImageReady: () {});
        addTearDown(cache.dispose);
        cache.putReady(
          image.id,
          await _imageFromRgba(image.pixelData, image.width, image.height),
        );

        final snapshots = [
          KittyPlacementSnapshot(
            imageId: image.id,
            dst: const Rect.fromLTWH(0, 0, 64, 64),
            src: const Rect.fromLTWH(0, 0, 64, 64),
            z: 0,
          ),
        ];
        final painter = KittyGraphicsPainter(
          state: _stateFor(cols: 64, rows: 64),
          cache: cache,
          snapshots: snapshots,
          layer: KittyPaintLayer.aboveText,
        );

        captured = await _paint(width: 64, height: 64, draw: painter.paint);
      });
      await expectLater(
        captured,
        matchesGoldenFile('goldens/kitty_png_pipeline.png'),
      );
    });
  });
}

DecodedImage? _decodePng(Uint8List bytes) {
  final decoded = img.decodePng(bytes);
  if (decoded == null) return null;
  final rgba = decoded.convert(format: img.Format.uint8, numChannels: 4);
  return (
    width: rgba.width,
    height: rgba.height,
    rgba: Uint8List.fromList(rgba.toUint8List()),
  );
}

Future<ui.Image> _imageFromRgba(Uint8List rgba, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

Uint8List _loadFixture(String name) {
  final path = [
    Directory.current.path,
    'test',
    'fixtures',
    'kitty_graphics',
    name,
  ].join(Platform.pathSeparator);
  return File(path).readAsBytesSync();
}

Future<ui.Image> _paint({
  required int width,
  required int height,
  required void Function(Canvas canvas) draw,
}) {
  final recorder = ui.PictureRecorder();
  final rect = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  final canvas = Canvas(recorder, rect)
    ..drawRect(rect, Paint()..color = const Color(0xff000000));
  draw(canvas);
  return recorder.endRecording().toImage(width, height);
}

Uint8List _quadrantsRgba() {
  const colors = <List<int>>[
    [0xff, 0x00, 0x00, 0xff],
    [0x00, 0xff, 0x00, 0xff],
    [0x00, 0x00, 0xff, 0xff],
    [0xff, 0xff, 0x00, 0xff],
  ];
  final out = Uint8List(4 * 4 * 4);
  for (var y = 0; y < 4; y++) {
    for (var x = 0; x < 4; x++) {
      final quadrant = (y < 2 ? 0 : 2) + (x < 2 ? 0 : 1);
      final color = colors[quadrant];
      final offset = (y * 4 + x) * 4;
      out.setRange(offset, offset + 4, color);
    }
  }
  return out;
}

TerminalPaintState _stateFor({required int cols, required int rows}) {
  return TerminalPaintState(
      TerminalTheme.dark(),
      const CellMetrics(cellWidth: 1, cellHeight: 1, baseline: 1),
    )
    ..cols = cols
    ..rows = rows;
}
