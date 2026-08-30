import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Enforces the layering by reading the imports.
///
/// A structure only stays clean if something fails when it stops being clean.
/// A diagram in a readme does not; this does. Each layer may only import from
/// the layers below it:
///
///   core     → nothing in the app
///   data     → core
///   domain   → core, data/models
///   features → anything
///   shared   → core, data/models, domain
///
/// The rule that earns its keep is `domain` not reaching into `data/sources`:
/// it keeps the cost engine a pure function of its inputs, which is the reason
/// it can be tested without a network or a widget tree.
void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// Layer prefixes a file in the keyed layer is allowed to import from.
  ///
  /// `data/repositories` may reach into `domain` and `data/sources` may not.
  /// That asymmetry is the point: a source fetches and parses, and nothing more,
  /// while a repository is the seam that turns raw rows into something the rest
  /// of the app can use. OpenStreetMap publishes no prices, so a live stop has
  /// to be costed from typical rates for its kind — that is a pricing
  /// assumption, it lives in domain, and the repository is where it gets
  /// applied. Putting it in the Overpass client instead made an HTTP class
  /// responsible for what a waterfall costs to visit.
  const allowed = <String, List<String>>{
    'core': [],
    'data/models': ['core'],
    'data/sources': ['core', 'data/models'],
    'data/repositories': ['core', 'data/models', 'data/sources', 'domain'],
    'domain': ['core', 'data/models'],
    'shared': ['core', 'data/models', 'domain'],
    'app': ['core', 'data', 'domain', 'features', 'shared'],
    'features': ['core', 'data', 'domain', 'features', 'shared', 'app'],
  };

  String? layerOf(String path) {
    final rel = path.replaceAll(r'\', '/').replaceFirst(RegExp('^.*?lib/'), '');
    // Longest prefix wins, so data/models is not read as data.
    final keys = allowed.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final k in keys) {
      if (rel.startsWith('$k/')) return k;
    }
    return null;
  }

  test('no file imports a layer it is not allowed to', () {
    final violations = <String>[];

    for (final file in files) {
      final layer = layerOf(file.path);
      if (layer == null) continue; // main.dart and the like
      final permitted = allowed[layer]!;

      for (final line in file.readAsLinesSync()) {
        final match = RegExp(r"""^\s*import\s+'package:trip_planner/([^']+)'""")
            .firstMatch(line);
        if (match == null) continue;

        final target = match.group(1)!;
        final targetLayer = layerOf('lib/$target');
        if (targetLayer == null) continue;
        if (targetLayer == layer) continue;

        final ok = permitted.any((p) => targetLayer == p || targetLayer.startsWith('$p/'));
        if (!ok) {
          final from = file.path.replaceAll(r'\', '/').replaceFirst(RegExp('^.*?lib/'), '');
          violations.add('$from  ($layer)  ->  $target  ($targetLayer)');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'These imports cross a layer boundary the wrong way:\n'
          '${violations.join('\n')}',
    );
  });

  test('domain stays free of Flutter widgets and the network', () {
    // IconData and Color come from material and are legitimately part of a
    // breakdown line, so the bar is widgets and IO rather than the whole SDK.
    for (final file in files.where((f) => layerOf(f.path) == 'domain')) {
      final src = file.readAsStringSync();
      expect(src.contains("import 'package:http/"), isFalse,
          reason: '${file.path} makes domain depend on the network');
      expect(src.contains("import 'dart:io'"), isFalse,
          reason: '${file.path} makes domain depend on the filesystem');
      expect(src.contains('StatefulWidget'), isFalse,
          reason: '${file.path} puts a widget in the domain layer');
    }
  });

  test('every layer that should exist does', () {
    for (final dir in [
      'lib/core',
      'lib/data/models',
      'lib/data/sources',
      'lib/data/repositories',
      'lib/domain',
      'lib/features',
      'lib/shared/widgets',
      'lib/app',
    ]) {
      expect(Directory(dir).existsSync(), isTrue, reason: '$dir is missing');
    }
  });
}
