// Prepares the brand PNGs for use as icons and in-app artwork.
//
//   dart run tool/make_brand_assets.dart
//
// Two jobs the raw exports cannot do themselves:
//
//  * An Android adaptive icon is a 108dp canvas of which only the centre 72dp
//    is guaranteed visible — launchers mask the rest to a circle, squircle or
//    rounded square. The mark fills its export almost edge to edge, so dropped
//    in as-is its shoulders get shaved off. It is trimmed to its true bounding
//    box and re-seated at a safe fraction of a fresh square.
//
//  * The wordmark was exported on solid white, which looks like a printed sheet
//    the moment it sits on anything else. The white is flood-filled away from
//    the border inwards, so the whites *inside* the mark — the sky behind the
//    mountains, the pin — survive, because they are enclosed by the artwork.
import 'dart:io';

import 'package:image/image.dart';

/// Build-time artwork. Deliberately outside `assets/`, so none of it is bundled
/// into the app — the launcher-icon generator reads it from the repository at
/// build time and the shipped binary never carries it. Declaring the whole
/// `assets/brand/` directory instead put 3.5 MB of source PNGs and 1024px icon
/// masters into the APK, none of which the app ever loads.
const _src = 'brand';

/// Runtime artwork. Only what the app actually draws, sized for what it draws
/// it at.
const _out = 'assets/brand';

/// Longest side of the runtime images. They render at 108 and 132 logical
/// pixels, so 512 covers a 3x screen with room to spare.
const _runtimeMax = 512;

void main() {
  Directory(_out).createSync(recursive: true);

  final wordmark = _read('$_src/wordmark_source.png');
  final iconArt = _read('$_src/icon_source.png');

  // ---- Launcher icon -------------------------------------------------------
  // The icon artwork is a full square tile — a whole scene, not a floating
  // mark — so it is seated edge to edge rather than shrunk into the middle.
  // Padding it the way a small glyph needs would leave it swimming in white.
  //
  // Its own rounded corners are transparent, which is what lets a launcher mask
  // it to a circle, a squircle or a rounded square without a visible seam. The
  // 16% inset flutter_launcher_icons applies by default is turned off in
  // pubspec.yaml for the same reason.
  final foreground = _seat(_trim(iconArt), 1024, 1.0);
  _write('$_src/icon_foreground.png', foreground);

  // ---- Full-bleed icon: the tile on white ---------------------------------
  // iOS and the web favicon have no separate background layer, and iOS rejects
  // an icon with transparency outright, so the ground is baked in here. It has
  // to match the Android adaptive background in pubspec.yaml, or the same app
  // ships with two different-looking icons.
  final onWhite = Image(width: 1024, height: 1024, numChannels: 4)
    ..clear(ColorRgb8(0xFF, 0xFF, 0xFF));
  compositeImage(onWhite, foreground);
  _write('$_src/icon_full.png', onWhite);

  // ---- Runtime: the tile, and the wordmark with its paper removed ---------
  // The in-app mark is the same tile as the launcher icon, so what someone taps
  // on their home screen is what greets them on the splash and in the header.
  // The older pin is still in brand/mark_source.png if that ever needs undoing.
  _write('$_out/mark.png', _fit(_trim(iconArt), _runtimeMax));
  _write('$_out/wordmark.png', _fit(_trim(_dropBorderWhite(wordmark)), _runtimeMax));

  stdout.writeln('\nbuild-time icons in $_src/, runtime artwork in $_out/');
}

/// Scales down so the longest side is at most [max]. Never scales up.
Image _fit(Image src, int max) {
  final longest = src.width > src.height ? src.width : src.height;
  if (longest <= max) return src;
  final scale = max / longest;
  return copyResize(
    src,
    width: (src.width * scale).round(),
    height: (src.height * scale).round(),
    interpolation: Interpolation.cubic,
  );
}

Image _read(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('missing $path');
    exit(1);
  }
  final decoded = decodePng(file.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('could not decode $path');
    exit(1);
  }
  return decoded.convert(numChannels: 4);
}

void _write(String path, Image image) {
  File(path).writeAsBytesSync(encodePng(image));
  stdout.writeln('  ${image.width}x${image.height}  $path');
}

/// Crops away fully transparent edges.
Image _trim(Image src) {
  var minX = src.width, minY = src.height, maxX = -1, maxY = -1;

  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      if (src.getPixel(x, y).a > 8) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  if (maxX < 0) return src; // nothing opaque; leave it alone
  return copyCrop(src, x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);
}

/// Centres [src] on a transparent square of [size], scaled so its longest side
/// is [fraction] of that square.
Image _seat(Image src, int size, double fraction) {
  final target = (size * fraction).round();
  final scale = target / (src.width > src.height ? src.width : src.height);
  final resized = copyResize(
    src,
    width: (src.width * scale).round(),
    height: (src.height * scale).round(),
    interpolation: Interpolation.cubic,
  );

  final canvas = Image(width: size, height: size, numChannels: 4);
  compositeImage(
    canvas,
    resized,
    dstX: (size - resized.width) ~/ 2,
    dstY: (size - resized.height) ~/ 2,
  );
  return canvas;
}

/// Flood-fills near-white to transparent, starting from the border.
///
/// Starting at the edges is the whole trick: it reaches the paper the logo was
/// exported on and stops at the artwork, so white areas enclosed by the mark
/// are never touched.
Image _dropBorderWhite(Image src) {
  final out = src.convert(numChannels: 4);
  final w = out.width, h = out.height;
  final seen = List<bool>.filled(w * h, false);
  final queue = <int>[];

  bool isPaper(int x, int y) {
    final p = out.getPixel(x, y);
    return p.r > 242 && p.g > 242 && p.b > 242;
  }

  void consider(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final i = y * w + x;
    if (seen[i]) return;
    seen[i] = true;
    if (!isPaper(x, y)) return;
    queue.add(i);
  }

  for (var x = 0; x < w; x++) {
    consider(x, 0);
    consider(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    consider(0, y);
    consider(w - 1, y);
  }

  while (queue.isNotEmpty) {
    final i = queue.removeLast();
    final x = i % w, y = i ~/ w;
    out.setPixelRgba(x, y, 0, 0, 0, 0);
    consider(x - 1, y);
    consider(x + 1, y);
    consider(x, y - 1);
    consider(x, y + 1);
  }

  return out;
}
