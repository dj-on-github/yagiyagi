// Draws the app icon and writes it out at every size the platforms need.
//
//   flutter test tool/generate_icons.dart
//
// The artwork is vector, so the icon can be retouched here and regenerated
// rather than round-tripped through an image editor.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where the icon sits inside its canvas.
enum IconShape {
  /// Edge to edge. iOS, Android and the browser apply their own mask.
  square,

  /// Rounded square with a margin, the way macOS wants it.
  rounded,
}

const _deepTeal = Color(0xFF10262E);
const _deepShadow = Color(0xFF070D10);
const _boomGrey = Color(0xFF7C939D);
const _elementWhite = Color(0xFFEAF3F5);
const _accent = Color(0xFF43D8C2);

/// Paints the icon into a canvas [s] pixels square.
///
/// A Yagi in profile: boom across, elements crossing it and shortening
/// towards the front, with the beam leaving the director end. Four elements
/// is the most that still reads at 16 px.
void paintIcon(
  Canvas canvas,
  double s, {
  IconShape shape = IconShape.square,
  double contentScale = 1.0,
  bool withArcs = true,
}) {
  final inset = shape == IconShape.rounded ? 0.055 * s : 0.0;
  final box = Rect.fromLTWH(inset, inset, s - 2 * inset, s - 2 * inset);
  final background = Paint()
    ..shader = ui.Gradient.linear(
      box.topLeft,
      box.bottomRight,
      const [_deepTeal, _deepShadow],
    );

  if (shape == IconShape.rounded) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(box, Radius.circular(0.225 * s)), background);
  } else {
    canvas.drawRect(box, background);
  }

  canvas.save();
  canvas.translate(s / 2, s / 2);
  canvas.scale(contentScale);
  canvas.translate(-s / 2, -s / 2);
  _paintYagi(canvas, s, withArcs: withArcs);
  canvas.restore();
}

void _paintYagi(Canvas canvas, double s, {required bool withArcs}) {
  // Below about 24 px four elements smear into a single block, so the small
  // sizes get a simplified three-element cut with fatter strokes.
  final tiny = s <= 24;
  const boomY = 0.50;
  final xs = tiny
      ? const [0.215, 0.395, 0.545]
      : const [0.200, 0.340, 0.465, 0.570];
  final halfLengths = tiny
      ? const [0.300, 0.250, 0.200]
      : const [0.290, 0.250, 0.215, 0.185];
  final boomFrom = tiny ? 0.16 : 0.155;
  final boomTo = tiny ? 0.62 : 0.645;

  canvas.drawLine(
    Offset(boomFrom * s, boomY * s),
    Offset(boomTo * s, boomY * s),
    Paint()
      ..color = _boomGrey
      ..strokeWidth = (tiny ? 0.055 : 0.040) * s
      ..strokeCap = StrokeCap.round,
  );

  final element = Paint()
    ..color = _elementWhite
    ..strokeWidth = (tiny ? 0.075 : 0.050) * s
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < xs.length; i++) {
    canvas.drawLine(
      Offset(xs[i] * s, (boomY - halfLengths[i]) * s),
      Offset(xs[i] * s, (boomY + halfLengths[i]) * s),
      element,
    );
  }

  if (!withArcs) return;
  // The beam leaves the director end, which is what makes the drawing read
  // as an antenna rather than a row of tally marks.
  final focus = Offset(xs.last * s, boomY * s);
  final arcs = tiny ? 2 : 3;
  for (var i = 0; i < arcs; i++) {
    final radius = (tiny ? 0.16 + 0.10 * i : 0.135 + 0.072 * i) * s;
    canvas.drawArc(
      Rect.fromCircle(center: focus, radius: radius),
      -40 * pi / 180,
      80 * pi / 180,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (tiny ? 0.062 : 0.034) * s
        ..strokeCap = StrokeCap.round
        ..color = _accent.withValues(alpha: 0.95 - 0.20 * i),
    );
  }
}

Future<Uint8List> _render(
  WidgetTester tester,
  int size, {
  IconShape shape = IconShape.square,
  double contentScale = 1.0,
  bool withArcs = true,
}) async {
  final recorder = ui.PictureRecorder();
  paintIcon(Canvas(recorder), size.toDouble(),
      shape: shape, contentScale: contentScale, withArcs: withArcs);
  final picture = recorder.endRecording();
  late Uint8List bytes;
  // Rasterising has to happen outside the fake async zone.
  await tester.runAsync(() async {
    final image = await picture.toImage(size, size);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    bytes = data!.buffer.asUint8List();
    image.dispose();
  });
  return bytes;
}

/// Packs PNGs into a Windows .ico. Every entry is a PNG, which Windows has
/// accepted since Vista and keeps the file small.
Uint8List buildIco(List<Uint8List> pngs, List<int> sizes) {
  const headerBytes = 6, entryBytes = 16;
  final directory = headerBytes + entryBytes * pngs.length;
  final total =
      directory + pngs.fold<int>(0, (sum, png) => sum + png.length);
  final out = Uint8List(total);
  final view = ByteData.view(out.buffer);

  view.setUint16(0, 0, Endian.little); // reserved
  view.setUint16(2, 1, Endian.little); // 1 = icon
  view.setUint16(4, pngs.length, Endian.little);

  var offset = directory;
  for (var i = 0; i < pngs.length; i++) {
    final entry = headerBytes + entryBytes * i;
    // 256 is stored as 0.
    out[entry] = sizes[i] >= 256 ? 0 : sizes[i];
    out[entry + 1] = sizes[i] >= 256 ? 0 : sizes[i];
    out[entry + 2] = 0; // palette size
    out[entry + 3] = 0; // reserved
    view.setUint16(entry + 4, 1, Endian.little); // colour planes
    view.setUint16(entry + 6, 32, Endian.little); // bits per pixel
    view.setUint32(entry + 8, pngs[i].length, Endian.little);
    view.setUint32(entry + 12, offset, Endian.little);
    out.setRange(offset, offset + pngs[i].length, pngs[i]);
    offset += pngs[i].length;
  }
  return out;
}

void main() {
  // Contact sheet for eyeballing the design; build/ is not checked in.
  final preview = '${Directory.current.path}/build/icon_preview.png';

  testWidgets('preview', (tester) async {
    Directory('${Directory.current.path}/build').createSync(recursive: true);
    // The sizes that decide whether the design works, so legibility at
    // 16 px can be judged rather than assumed.
    const sizes = [160, 128, 64, 32, 16];
    const pad = 24.0;
    final width = pad + sizes.fold<double>(0, (a, b) => a + b + pad);
    const height = 2 * (160 + pad) + pad;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height),
        Paint()..color = const Color(0xFF2A2F33));

    for (var row = 0; row < 2; row++) {
      var x = pad;
      for (final size in sizes) {
        canvas.save();
        canvas.translate(x, pad + row * (160 + pad));
        paintIcon(canvas, size.toDouble(),
            shape: row == 0 ? IconShape.rounded : IconShape.square);
        canvas.restore();
        x += size + pad;
      }
    }

    final picture = recorder.endRecording();
    await tester.runAsync(() async {
      final image = await picture.toImage(width.toInt(), height.toInt());
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File(preview).writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
    expect(File(preview).existsSync(), isTrue);
  });

  testWidgets('write platform icons', (tester) async {
    final root = Directory.current.path;
    var written = 0;

    Future<void> write(String path, int size,
        {IconShape shape = IconShape.square,
        double contentScale = 1.0}) async {
      final file = File('$root/$path');
      expect(file.parent.existsSync(), isTrue,
          reason: 'missing icon directory for $path');
      file.writeAsBytesSync(await _render(tester, size,
          shape: shape, contentScale: contentScale));
      written++;
    }

    // macOS wants the rounded shape baked in, with a margin.
    for (final size in [16, 32, 64, 128, 256, 512, 1024]) {
      await write(
          'macos/Runner/Assets.xcassets/AppIcon.appiconset/'
          'app_icon_$size.png',
          size,
          shape: IconShape.rounded);
    }

    // iOS masks the icon itself, so these are full-bleed squares.
    const iosIcons = {
      'Icon-App-20x20@1x.png': 20,
      'Icon-App-20x20@2x.png': 40,
      'Icon-App-20x20@3x.png': 60,
      'Icon-App-29x29@1x.png': 29,
      'Icon-App-29x29@2x.png': 58,
      'Icon-App-29x29@3x.png': 87,
      'Icon-App-40x40@1x.png': 40,
      'Icon-App-40x40@2x.png': 80,
      'Icon-App-40x40@3x.png': 120,
      'Icon-App-60x60@2x.png': 120,
      'Icon-App-60x60@3x.png': 180,
      'Icon-App-76x76@1x.png': 76,
      'Icon-App-76x76@2x.png': 152,
      'Icon-App-83.5x83.5@2x.png': 167,
      'Icon-App-1024x1024@1x.png': 1024,
    };
    for (final entry in iosIcons.entries) {
      await write('ios/Runner/Assets.xcassets/AppIcon.appiconset/'
          '${entry.key}', entry.value);
    }

    const android = {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    for (final entry in android.entries) {
      await write(
          'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
          entry.value);
    }

    await write('web/favicon.png', 16);
    await write('web/icons/Icon-192.png', 192);
    await write('web/icons/Icon-512.png', 512);
    // Maskable icons get cropped to a circle of 80% diameter by some
    // launchers, so the artwork is pulled in to survive it.
    await write('web/icons/Icon-maskable-192.png', 192, contentScale: 0.82);
    await write('web/icons/Icon-maskable-512.png', 512, contentScale: 0.82);

    // Windows takes one .ico holding the whole set.
    const icoSizes = [16, 32, 48, 256];
    final icoPngs = <Uint8List>[];
    for (final size in icoSizes) {
      icoPngs.add(await _render(tester, size));
    }
    File('$root/windows/runner/resources/app_icon.ico')
        .writeAsBytesSync(buildIco(icoPngs, icoSizes));
    written++;

    expect(written, 33);
  });
}
