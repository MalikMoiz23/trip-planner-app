/// Typo- and transliteration-tolerant text matching.
///
/// Urdu and the regional languages have no single agreed romanisation, so the
/// same place is spelled several ways in everyday use: Thandiani / Thandyani,
/// Panj Peer / Panjpeer / Panj Pir, Saif-ul-Malook / Saiful Malok. Exact string
/// matching fails on all of them, and so does the public geocoder. Everything
/// here exists to make those spellings collide.
library;

import 'dart:math' as math;

/// Words that describe a *kind* of place rather than name one. Users type them
/// ("Thandyani Top", "Panj Peer Rocks") but the underlying record often omits
/// them, so they are stripped from both sides before comparing.
const Set<String> _genericTokens = {
  'top', 'tops', 'rock', 'rocks', 'point', 'view', 'viewpoint', 'lake', 'lakes',
  'valley', 'vally', 'pass', 'fort', 'qila', 'kila', 'park', 'waterfall',
  'waterfalls', 'fall', 'falls', 'national', 'meadow', 'meadows', 'base',
  'camp', 'peak', 'hill', 'hills', 'station', 'bazaar', 'bazar', 'market',
  'mosque', 'masjid', 'tomb', 'shrine', 'mazar', 'resort', 'town', 'city',
  'village', 'area', 'road', 'trip', 'tour', 'place', 'spot', 'the', 'of',
  'and', 'ka', 'ki', 'e', 'ul', 'al', 'plains', 'plain', 'plateau', 'desert',
  'glacier', 'river', 'spring', 'beach', 'island', 'museum', 'palace', 'gali',
};

/// Digraphs folded to a single consonant. Aspirated consonants are written
/// inconsistently in romanised Urdu, so `th`/`t`, `kh`/`k` and friends have to
/// compare equal.
const Map<String, String> _digraphs = {
  'kh': 'k',
  'gh': 'g',
  'ph': 'f',
  'th': 't',
  'dh': 'd',
  'bh': 'b',
  'ch': 'c',
  'sh': 's',
  'zh': 'z',
  'ck': 'k',
  'qu': 'k',
};

const Set<String> _vowelish = {'a', 'e', 'i', 'o', 'u', 'y'};

/// Lowercase, strip accents and punctuation, collapse whitespace.
String normalize(String input) {
  final lower = input.toLowerCase().trim();
  final buffer = StringBuffer();
  var lastWasSpace = false;

  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    final folded = _deaccent[ch] ?? ch;
    if (_isLetterOrDigit(folded)) {
      buffer.write(folded);
      lastWasSpace = false;
    } else if (!lastWasSpace) {
      buffer.write(' ');
      lastWasSpace = true;
    }
  }
  return buffer.toString().trim();
}

const Map<String, String> _deaccent = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ā': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', 'ē': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', 'ī': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'ō': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', 'ū': 'u',
  'ñ': 'n', 'ç': 'c', 'ş': 's', 'ğ': 'g',
};

bool _isLetterOrDigit(String ch) {
  final c = ch.codeUnitAt(0);
  return (c >= 97 && c <= 122) || (c >= 48 && c <= 57);
}

/// Removes generic place-kind words. Returns the input untouched when removing
/// them would leave nothing behind — "Lake" alone is still a query.
String stripGenerics(String normalized) {
  final tokens = normalized.split(' ').where((t) => t.isNotEmpty).toList();
  final kept = tokens.where((t) => !_genericTokens.contains(t)).toList();
  if (kept.isEmpty) return normalized;
  return kept.join(' ');
}

/// An aggressive phonetic key: aspirated digraphs folded, every vowel (and `y`)
/// reduced to one symbol, runs of the same letter collapsed, spaces dropped.
///
/// "Thandyani" and "Thandiani" both become `tandana`, which is the whole point.
/// It over-merges by design — callers treat equality here as strong evidence,
/// not proof, and rank by edit distance on top.
String foldKey(String input) {
  var s = normalize(input).replaceAll(' ', '');
  if (s.isEmpty) return s;

  for (final entry in _digraphs.entries) {
    s = s.replaceAll(entry.key, entry.value);
  }

  final buffer = StringBuffer();
  String? previous;
  for (final ch in s.split('')) {
    final mapped = _vowelish.contains(ch) ? 'a' : ch;
    if (mapped != previous) buffer.write(mapped);
    previous = mapped;
  }
  return buffer.toString();
}

/// Optimal string alignment distance: insertions, deletions, substitutions and
/// adjacent transpositions, each costing one.
///
/// Transpositions matter here because swapped letters are the commonest typo of
/// all — "Panjpere" for "Panjpeer" is one slip, not two. Scoring it as two
/// pushed real matches under the threshold. That case needs the row from *two*
/// steps back, so three rolling rows are kept rather than two.
///
/// Bounded: a pair that cannot come within [maxDistance] exits early rather
/// than filling the whole matrix.
int editDistance(String a, String b, {int maxDistance = 99}) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  if ((a.length - b.length).abs() > maxDistance) return maxDistance + 1;

  final n = b.length;
  var twoAgo = List<int>.filled(n + 1, 0);
  var oneAgo = List<int>.generate(n + 1, (i) => i);
  var current = List<int>.filled(n + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    var rowBest = i;
    for (var j = 1; j <= n; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var value = math.min(
        math.min(current[j - 1] + 1, oneAgo[j] + 1),
        oneAgo[j - 1] + cost,
      );
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        value = math.min(value, twoAgo[j - 2] + 1);
      }
      current[j] = value;
      if (value < rowBest) rowBest = value;
    }
    if (rowBest > maxDistance) return maxDistance + 1;

    final recycled = twoAgo;
    twoAgo = oneAgo;
    oneAgo = current;
    current = recycled;
  }
  return oneAgo[n];
}

/// 1.0 for identical, 0.0 for nothing in common.
double similarity(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1;
  if (a.isEmpty || b.isEmpty) return 0;
  final longest = math.max(a.length, b.length);
  final distance = editDistance(a, b, maxDistance: longest);
  return 1.0 - (distance / longest);
}

/// How well `query` matches one candidate string, from 0 to 1.
double scoreCandidate(String query, String candidate) {
  final qn = normalize(query);
  final cn = normalize(candidate);
  if (qn.isEmpty || cn.isEmpty) return 0;
  if (qn == cn) return 1.0;

  var best = 0.0;

  void consider(String q, String c, double ceiling) {
    if (q.isEmpty || c.isEmpty) return;
    if (q == c) {
      best = math.max(best, ceiling);
      return;
    }
    if (c.startsWith(q)) {
      best = math.max(best, ceiling - 0.02);
      return;
    }
    if (c.contains(q) && q.length >= 3) {
      best = math.max(best, ceiling - 0.05);
      return;
    }
    if (q.contains(c) && c.length >= 4) {
      best = math.max(best, ceiling - 0.08);
      return;
    }
  }

  consider(qn, cn, 0.97);
  final qs = stripGenerics(qn);
  final cs = stripGenerics(cn);
  consider(qs, cs, 0.94);

  // Phonetic agreement. Only trusted from four symbols up, below which the key
  // is too lossy to mean much.
  final qf = foldKey(qs);
  final cf = foldKey(cs);
  if (qf.length >= 4 && cf.length >= 4) {
    if (qf == cf) {
      best = math.max(best, 0.91);
    } else if (cf.startsWith(qf) || cf.contains(qf)) {
      best = math.max(best, 0.85);
    }
  }

  // Per-token best pairing, so "peer panj" still finds "Panj Peer Rocks".
  final qTokens = qs.split(' ').where((t) => t.length > 1).toList();
  final cTokens = cs.split(' ').where((t) => t.length > 1).toList();
  if (qTokens.isNotEmpty && cTokens.isNotEmpty) {
    var sum = 0.0;
    for (final qt in qTokens) {
      var tokenBest = 0.0;
      for (final ct in cTokens) {
        tokenBest = math.max(tokenBest, similarity(qt, ct));
        tokenBest = math.max(tokenBest, similarity(foldKey(qt), foldKey(ct)) * 0.95);
      }
      sum += tokenBest;
    }
    best = math.max(best, (sum / qTokens.length) * 0.9);
  }

  best = math.max(best, similarity(qf, cf) * 0.85);
  return best.clamp(0.0, 1.0);
}

/// Best score across several labels — a record's name plus its aliases.
({double score, String label}) scoreLabels(String query, Iterable<String> labels) {
  var best = 0.0;
  var bestLabel = '';
  for (final label in labels) {
    final score = scoreCandidate(query, label);
    if (score > best) {
      best = score;
      bestLabel = label;
    }
  }
  return (score: best, label: bestLabel);
}

/// Below this a match is noise rather than a suggestion.
const double fuzzyThreshold = 0.62;

/// Progressively looser rewrites of a query, for a geocoder that only does
/// near-exact matching. "Thandyani Top" yields "Thandyani" — which Nominatim
/// does find, while the original returns nothing.
///
/// Capped deliberately: the public Nominatim instance asks for about one
/// request per second, so this is a handful of attempts, not a sweep.
List<String> queryVariants(String query, {int limit = 4}) {
  final out = <String>[];

  void add(String candidate) {
    final trimmed = candidate.trim();
    if (trimmed.length < 3) return;
    if (out.any((e) => e.toLowerCase() == trimmed.toLowerCase())) return;
    out.add(trimmed);
  }

  final raw = query.trim();
  add(raw);

  // Same words, minus the place-kind ones, with the user's own casing kept.
  final words = raw.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final meaningful =
      words.where((w) => !_genericTokens.contains(normalize(w))).toList();
  if (meaningful.length != words.length && meaningful.isNotEmpty) {
    add(meaningful.join(' '));
  }

  // Then simply shorter: drop trailing words one at a time.
  for (var take = meaningful.length - 1; take >= 1; take--) {
    add(meaningful.take(take).join(' '));
    if (out.length >= limit) break;
  }
  if (words.length > 1) add(words.first);

  return out.take(limit).toList();
}
