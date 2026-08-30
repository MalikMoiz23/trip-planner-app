import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pins the identity to the places the operating system actually reads.
///
/// The app name lives in five files that have nothing to do with each other —
/// an Android manifest, an iOS plist, a web page, a web manifest and the Dart
/// entry point. Renaming four of five is the normal outcome, and the one that
/// gets missed is invisible until the app is installed on a device.
void main() {
  const name = 'Triplyst';

  String read(String path) {
    final f = File(path);
    expect(f.existsSync(), isTrue, reason: '$path is missing');
    return f.readAsStringSync();
  }

  group('the app is called $name everywhere the OS looks', () {
    test('android launcher label', () {
      expect(
        read('android/app/src/main/AndroidManifest.xml'),
        contains('android:label="$name"'),
      );
    });

    test('ios display name and bundle name', () {
      final plist = read('ios/Runner/Info.plist');
      expect(plist, contains('<key>CFBundleDisplayName</key>'));
      expect(plist, contains('<string>$name</string>'));
      // The flutter create default must be gone from both keys.
      expect(plist.contains('trip_planner'), isFalse,
          reason: 'a default name is still in Info.plist');
    });

    test('web title and pwa manifest', () {
      expect(read('web/index.html'), contains('<title>$name</title>'));
      final manifest = read('web/manifest.json');
      expect(manifest, contains('"name": "$name"'));
      expect(manifest, contains('"short_name": "$name"'));
    });

    test('the running app announces itself by the same name', () {
      expect(read('lib/app/app.dart'), contains("title: '$name'"));
    });
  });

  group('brand artwork', () {
    test('every image the app draws is on disk and declared', () {
      // Two separate failures, and each one alone is silent. A missing file is
      // swallowed by an errorBuilder and ships as a blank space. A file that
      // exists but is not declared in pubspec passes every filesystem test —
      // tests read the disk, the app reads the bundle — and is missing only
      // once installed on a device.
      final pubspec = read('pubspec.yaml');
      for (final path in ['assets/brand/mark.png', 'assets/brand/wordmark.png']) {
        final f = File(path);
        expect(f.existsSync(), isTrue, reason: '$path is missing');
        expect(f.lengthSync(), greaterThan(1024), reason: '$path looks empty');
        expect(pubspec, contains('- $path'),
            reason: '$path is not declared, so it will not ship');
      }
    });

    test('build-time icon masters are kept out of the bundle', () {
      // These are read by the icon generator from the repository. Bundling them
      // put 3.5 MB into the APK that the app never opens.
      for (final path in ['brand/icon_foreground.png', 'brand/icon_full.png']) {
        expect(File(path).existsSync(), isTrue, reason: '$path is missing');
      }
      final pubspec = read('pubspec.yaml');
      expect(pubspec.contains('- assets/brand/\n'), isFalse,
          reason: 'declaring the directory would sweep the masters back in');
      expect(pubspec, contains('image_path: "brand/icon_full.png"'));
    });

    test('runtime artwork is sized for what it is drawn at', () {
      // Both render around 110-130 logical pixels. Shipping the 1254px export
      // would be roughly six times the bytes for no visible difference.
      for (final path in ['assets/brand/mark.png', 'assets/brand/wordmark.png']) {
        final bytes = File(path).readAsBytesSync();
        // IHDR width and height are big-endian 32-bit at offsets 16 and 20.
        final w = bytes.buffer.asByteData().getUint32(16);
        final h = bytes.buffer.asByteData().getUint32(20);
        final longest = w > h ? w : h;
        expect(longest, lessThanOrEqualTo(512), reason: '$path is ${w}x$h');
        expect(longest, greaterThanOrEqualTo(256), reason: '$path is too small to be sharp');
      }
    });

    test('launcher icons were generated for android and ios', () {
      expect(
        Directory('android/app/src/main/res/mipmap-xxxhdpi').existsSync(),
        isTrue,
      );
      expect(
        File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml').existsSync(),
        isTrue,
        reason: 'the adaptive icon wrapper is what modern launchers read',
      );
      expect(
        File('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png')
            .existsSync(),
        isTrue,
      );
    });

    test('the adaptive background matches the brand green', () {
      final colors = File('android/app/src/main/res/values/colors.xml');
      expect(colors.existsSync(), isTrue);
      expect(colors.readAsStringSync().toLowerCase(), contains('#0f6e5c'));
    });

    test('the iOS icon carries no alpha, which the App Store rejects', () {
      final icon = File(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
      );
      final bytes = icon.readAsBytesSync();
      // PNG colour type sits at byte 25 of the IHDR chunk: 2 is RGB, 6 is RGBA.
      expect(bytes[25], isNot(6), reason: 'the 1024 icon still has an alpha channel');
    });
  });
}
