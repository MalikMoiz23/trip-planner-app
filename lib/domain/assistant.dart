import 'dart:math' as math;

import 'package:trip_planner/core/constants.dart';
import 'package:trip_planner/core/formatters.dart';
import 'package:trip_planner/core/fuzzy.dart';
import 'package:trip_planner/core/geo.dart';
import 'package:trip_planner/data/models/destination.dart';
import 'package:trip_planner/data/models/route_info.dart';
import 'package:trip_planner/data/models/trip_config.dart';
import 'package:trip_planner/data/models/trip_stop.dart';
import 'package:trip_planner/domain/expense_calculator.dart';
import 'package:trip_planner/domain/packing_builder.dart';
import 'package:trip_planner/domain/survival.dart';

/// What the assistant worked out that a question was asking for.
enum Intent {
  /// Something has gone wrong right now. Checked before anything else, and
  /// answered from the offline survival guides rather than the catalogue.
  emergency,
  recommend,
  costOnePlace,
  compare,
  howFar,
  whenToGo,
  needs4x4,
  packing,
  appHelp,
  unknown,
}

/// Everything pulled out of one question.
class Ask {
  const Ask({
    required this.intent,
    this.places = const [],
    this.budget,
    this.days,
    this.persons,
    this.month,
    this.category,
    this.wantsCheap = false,
    this.avoids4x4 = false,
    this.guide,
  });

  final Intent intent;

  /// Places named in the question, best match first.
  final List<Destination> places;

  final double? budget;
  final int? days;
  final int? persons;

  /// 1–12 when a month was named.
  final int? month;

  /// One of the canonical categories, when a kind of place was named.
  final String? category;

  final bool wantsCheap;
  final bool avoids4x4;

  /// The survival guide this question is asking for, when it is an emergency.
  final SurvivalGuide? guide;
}

/// One suggestion, with the reason it is being suggested.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.destination,
    required this.estimatedTotal,
    required this.distanceKm,
    required this.reason,
  });

  final Destination destination;
  final double estimatedTotal;
  final double distanceKm;

  /// Why this one, in a phrase. Not decoration — a recommendation nobody can
  /// interrogate is a recommendation nobody should follow.
  final String reason;
}

class AssistantReply {
  const AssistantReply({
    required this.text,
    this.suggestions = const [],
    this.followUps = const [],
    this.guide,
  });

  final String text;
  final List<PlaceSuggestion> suggestions;

  /// Questions worth asking next, so the conversation has somewhere to go.
  final List<String> followUps;

  /// Set when the answer came from an emergency guide, so the chat can offer the
  /// full ordered steps rather than trying to fit them in a bubble.
  final SurvivalGuide? guide;
}

/// Answers trip questions from the app's own data.
///
/// Deliberately not a language model. Every figure it quotes comes from the same
/// catalogue and the same cost engine the rest of the app uses, so it cannot
/// invent a fuel price or a road that does not exist — which is exactly what a
/// small model asked about Pakistani mountain roads does.
///
/// Pure: the places and the trip defaults are passed in, so the whole thing is
/// testable without a repository, a network or a widget tree.
class TripAssistant {
  const TripAssistant._();

  /// Closer than this and it is an afternoon out rather than a trip worth
  /// costing, so it is left out of recommendations.
  static const double _tooCloseToBotherKm = 25;

  /// Estimated cost and distance need somewhere to start from and some
  /// assumptions to cost against.
  static AssistantReply answer(
    String question, {
    required List<Destination> places,
    required TripConfig defaults,
  }) {
    final ask = parse(question, places);

    return switch (ask.intent) {
      Intent.emergency => _emergency(ask),
      Intent.recommend => _recommend(ask, places, defaults),
      Intent.costOnePlace => _cost(ask, defaults),
      Intent.compare => _compare(ask, defaults),
      Intent.howFar => _howFar(ask, defaults),
      Intent.whenToGo => _whenToGo(ask),
      Intent.needs4x4 => _needs4x4(ask),
      Intent.packing => _packing(ask, defaults),
      Intent.appHelp => _appHelp(question),
      Intent.unknown => _dontKnow(question),
    };
  }

  // =========================================================================
  // Reading the question
  // =========================================================================

  static Ask parse(String question, List<Destination> places) {
    final q = normalize(question);
    final words = q.split(' ');

    final named = _placesIn(question, places);
    final budget = _budgetIn(question.toLowerCase(), words);
    final days = _daysIn(q, words);
    final persons = _personsIn(q, words);
    final month = _monthIn(words);
    final category = _categoryIn(q);

    final cheap = _any(q, [
      'cheap', 'cheapest', 'budget', 'affordable', 'low cost', 'economical',
      'save money', 'inexpensive',
    ]);
    // Written as a pattern rather than a word list: people say "without a
    // jeep", "without jeep" and "no 4x4" and all three mean the same thing.
    final avoid4x4 = RegExp(
      r'(without|no|dont have|do not have|havent got)\s+(a\s+|an\s+)?(4x4|jeep|four wheel)'
      r'|normal car|small car|sedan|car only|ordinary car',
    ).hasMatch(q);

    // Emergencies are read before anything else, because a question asked by
    // someone in trouble must never be answered as though it were browsing.
    // The one collision worth guarding is fuel: "how is fuel calculated" is a
    // question about the app, "the fuel ended" is a person at the roadside.
    final guide = _emergencyIn(question, q);

    Intent intent;
    if (guide != null) {
      intent = Intent.emergency;
    } else if (_any(q, ['pack', 'packing', 'bring', 'take with', 'what to wear'])) {
      intent = Intent.packing;
    } else if (_any(q, ['how far', 'distance', 'how many km', 'how long to drive',
        'how much driving'])) {
      intent = Intent.howFar;
    } else if (_any(q, ['best time', 'when to go', 'when should', 'which month',
        'best month', 'season', 'open in', 'closed in'])) {
      intent = Intent.whenToGo;
    } else if (_any(q, ['4x4', 'jeep', 'four wheel', 'suv needed']) &&
        !avoid4x4 &&
        named.isNotEmpty) {
      // Only when a place is named and they are not ruling jeeps out. "Where
      // can I go without a jeep" is a recommendation with a filter on it.
      intent = Intent.needs4x4;
    } else if (named.length >= 2 &&
        _any(q, ['or', 'vs', 'versus', 'compare', 'better', 'which one'])) {
      intent = Intent.compare;
    } else if (_any(q, ['how much', 'cost', 'budget for', 'price', 'expensive',
        'afford', 'total for'])) {
      // "how much for Hunza" is a costing; "how much can I do for 50k" is a
      // recommendation. A named place decides which.
      intent = named.isNotEmpty ? Intent.costOnePlace : Intent.recommend;
    } else if (_any(q, ['how does', 'how do i', 'how is', 'how are', 'what is this app',
        'where do prices', 'prices', 'come from', 'why does', 'export', 'pdf', 'save trip', 'dark mode',
        'help', 'accurate', 'where does the data', 'fuel', 'petrol', 'diesel',
        'mileage', 'calculated', 'work out'])) {
      intent = Intent.appHelp;
    } else if (_any(q, ['where should', 'recommend', 'suggest', 'ideas', 'somewhere',
        'places to', 'where can', 'best place', 'good place', 'options']) ||
        category != null ||
        budget != null ||
        month != null ||
        cheap) {
      intent = Intent.recommend;
    } else if (named.isNotEmpty) {
      // A bare place name is almost always "tell me about this".
      intent = Intent.costOnePlace;
    } else {
      intent = Intent.unknown;
    }

    return Ask(
      intent: intent,
      places: named,
      budget: budget,
      days: days,
      persons: persons,
      month: month,
      category: category,
      wantsCheap: cheap,
      avoids4x4: avoid4x4,
      guide: guide,
    );
  }

  /// The survival guide a question is asking for, or null when it is an
  /// ordinary trip question that merely shares a word with one.
  ///
  /// "Fuel", "petrol" and "fire" all appear in perfectly calm questions about
  /// what a trip costs and what the app does. So a keyword hit is necessary and
  /// not sufficient: anything phrased as a question about how something is
  /// worked out, or about a price or a plan, is not an emergency.
  static SurvivalGuide? _emergencyIn(String question, String normalized) {
    final hit = Survival.match(question);
    if (hit == null) return null;
    if (_any(normalized, _notAnEmergency)) return null;
    return hit;
  }

  static const List<String> _notAnEmergency = [
    'how is', 'how does', 'how do you', 'how are', 'calculated', 'calculate',
    'work out', 'worked out', 'this app', 'the app', 'where do prices',
    'where does', 'estimate', 'estimated', 'price', 'prices', 'rate', 'rates',
    'per litre', 'average', 'mileage', 'budget', 'recommend', 'suggest',
    'cheapest', 'how much', 'plan a trip', 'best time', 'which month',
  ];

  /// Substring match, but padded so a short word cannot match inside a longer
  /// one. Without the padding "for hunza" contains "or " and every costing
  /// question was read as a comparison.
  static bool _any(String haystack, List<String> needles) {
    final padded = ' $haystack ';
    return needles.any((n) => padded.contains(n.contains(' ') ? n : ' $n '));
  }

  /// Words that turn up in questions and happen to collide with place names or
  /// their aliases. "Capital" is in Islamabad's labels; "jeep" is in a stop's.
  /// Neither is naming a place when someone types it.
  static const Set<String> _neverAPlaceName = {
    'capital', 'prices', 'price', 'costs', 'budget', 'money', 'rupees',
    'people', 'person', 'persons', 'family', 'friends', 'couple',
    'without', 'cheapest', 'cheaper', 'weekend', 'holiday', 'trip', 'travel',
    'somewhere', 'anywhere', 'places', 'place', 'should', 'would', 'could',
    'january', 'february', 'march', 'april', 'june', 'july', 'august',
    'september', 'october', 'november', 'december', 'summer', 'winter',
    'spring', 'autumn', 'monsoon', 'season', 'month', 'months',
    'north', 'south', 'east', 'west', 'northern', 'southern',
    'mountain', 'mountains', 'valley', 'valleys', 'lakes', 'beach', 'beaches',
    'hills', 'desert', 'historical', 'nights', 'about', 'there', 'which',
  };

  /// Places named in the question.
  static List<Destination> _placesIn(String question, List<Destination> places) {
    final q = normalize(question);
    if (q.length < 3) return const [];

    final words = q.split(' ');

    final scored = <(Destination, double)>[];
    for (final place in places) {
      var best = 0.0;
      for (final label in place.searchLabels) {
        final n = normalize(label);

        // The whole name appearing in the question is the strong signal.
        if (n.length >= 4 && q.contains(n)) {
          best = math.max(best, 1.0);
          continue;
        }

        // Otherwise a single word may still name the place, misspelled. This is
        // held to a much tighter rule than the search box, because here a loose
        // match hijacks the whole answer: "where can I go without a jeep" found
        // "Raikot Bridge Jeep Stand" and replied about that instead, and "what
        // is the capital of France" found Islamabad.
        final tokens = n.split(' ');
        for (var i = 0; i < tokens.length; i++) {
          final token = tokens[i];

          // A short token only counts as the name when it *leads* the name.
          // "Swat" is a real place and must match; "Jeep" inside "Raikot Bridge
          // Jeep Stand" must not, and the position is what separates them.
          if (token.length < 5 && i != 0) continue;
          if (token.length < 4) continue;

          for (final word in words) {
            if (word.length < 4) continue;
            if (_neverAPlaceName.contains(word)) continue;
            if (token == word || foldKey(token) == foldKey(word)) {
              best = math.max(best, 0.95);
            }
          }
        }
      }
      if (best >= 0.9) scored.add((place, best));
    }

    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      if (byScore != 0) return byScore;
      // Prefer a town over one of its own stops when both match.
      return (a.$1.isSpot ? 1 : 0).compareTo(b.$1.isSpot ? 1 : 0);
    });

    // Deduplicate: a town and its promoted stop can both match one word.
    final out = <Destination>[];
    for (final (place, _) in scored) {
      if (out.any((e) => e.id == place.id)) continue;
      out.add(place);
      if (out.length >= 3) break;
    }
    return out;
  }

  /// Money in a question, written the way people write it: 50000, 50k, 50 k,
  /// "50 thousand", "1 lakh", "1.5 lakh".
  static double? _budgetIn(String q, List<String> words) {
    final lakh = RegExp(r'(\d+(?:\.\d+)?)\s*(?:lakh|lac)').firstMatch(q);
    if (lakh != null) return double.parse(lakh.group(1)!) * 100000;

    final k = RegExp(r'(\d+(?:\.\d+)?)\s*(?:k\b|thousand)').firstMatch(q);
    if (k != null) return double.parse(k.group(1)!) * 1000;

    // A bare number only reads as money when it is large enough to be money.
    for (final w in words) {
      final n = int.tryParse(w);
      if (n != null && n >= 5000) return n.toDouble();
    }
    return null;
  }

  static int? _daysIn(String q, List<String> words) {
    if (q.contains('weekend')) return 2;
    if (RegExp(r'\ba week\b').hasMatch(q)) return 7;
    if (RegExp(r'\btwo weeks\b').hasMatch(q)) return 14;

    final m = RegExp(r'(\d+)\s*(?:day|days|nights?)').firstMatch(q);
    if (m != null) {
      final n = int.parse(m.group(1)!);
      // "3 nights" is a 4 day trip.
      return q.contains('night') ? n + 1 : n;
    }
    for (final entry in _numberWords.entries) {
      if (RegExp('\\b${entry.key} (?:day|days)\\b').hasMatch(q)) return entry.value;
    }
    return null;
  }

  static int? _personsIn(String q, List<String> words) {
    final m = RegExp(r'(\d+)\s*(?:person|persons|people|pax|adults?|of us|friends|family)')
        .firstMatch(q);
    if (m != null) return int.parse(m.group(1)!);

    final family = RegExp(r'family of (\d+)').firstMatch(q);
    if (family != null) return int.parse(family.group(1)!);

    if (RegExp(r'\b(?:alone|solo|by myself)\b').hasMatch(q)) return 1;
    if (RegExp(r'\b(?:couple|honeymoon|two of us|me and my wife|me and my husband)\b')
        .hasMatch(q)) {
      return 2;
    }
    for (final entry in _numberWords.entries) {
      if (RegExp('\\b${entry.key} (?:people|persons|of us|friends)\\b').hasMatch(q)) {
        return entry.value;
      }
    }
    return null;
  }

  static const Map<String, int> _numberWords = {
    'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
  };

  static int? _monthIn(List<String> words) {
    const months = {
      'january': 1, 'jan': 1, 'february': 2, 'feb': 2, 'march': 3, 'mar': 3,
      'april': 4, 'apr': 4, 'may': 5, 'june': 6, 'jun': 6, 'july': 7, 'jul': 7,
      'august': 8, 'aug': 8, 'september': 9, 'sep': 9, 'sept': 9,
      'october': 10, 'oct': 10, 'november': 11, 'nov': 11,
      'december': 12, 'dec': 12,
    };
    for (final w in words) {
      final m = months[w];
      if (m != null) return m;
    }
    // Seasons map onto a representative month.
    final joined = words.join(' ');
    if (joined.contains('summer')) return 7;
    if (joined.contains('winter')) return 1;
    if (joined.contains('monsoon')) return 8;
    if (joined.contains('spring')) return 4;
    if (joined.contains('autumn') || joined.contains('fall')) return 10;
    return null;
  }

  static String? _categoryIn(String q) {
    const map = {
      'Lakes': ['lake', 'lakes'],
      'Beaches': ['beach', 'beaches', 'sea', 'coast', 'island'],
      'Mountains': ['mountain', 'mountains', 'peak', 'snow', 'glacier', 'trek', 'hiking'],
      'Valleys': ['valley', 'valleys', 'green', 'forest'],
      'Hills': ['hill station', 'hills', 'hill'],
      'Historical': ['historical', 'history', 'fort', 'mosque', 'ruins', 'heritage',
        'shrine', 'museum', 'cultural'],
      'Desert': ['desert', 'dunes'],
      'City': ['city', 'cities', 'urban'],
    };
    for (final entry in map.entries) {
      if (entry.value.any(q.contains)) return entry.key;
    }
    return null;
  }

  // =========================================================================
  // Answering
  // =========================================================================

  /// Costs a trip to [place] under the given assumptions, using the real engine
  /// with an estimated road distance.
  static ({double total, double distanceKm}) _estimate(
    Destination place,
    TripConfig defaults, {
    int? days,
    int? persons,
  }) {
    final d = days ?? math.max(place.recommendedDays, 2);
    final p = persons ?? defaults.persons;
    final straight = haversineKm(defaults.origin, place.point);
    final roadKm = straight * place.roadFactor;

    final leg = RouteInfo(
      distanceKm: roadKm,
      duration: Duration(
        minutes: ((roadKm / AppDefaults.fallbackAverageSpeedKmh) * 60).round(),
      ),
      estimated: true,
    );

    final config = defaults.copyWith(
      stops: [TripStop(destination: place, nights: d > 1 ? d - 1 : 0)],
      days: d,
      persons: p,
      mealPlan: defaults.mealPlan.resized(d),
    );

    final breakdown = ExpenseCalculator.compute(
      config: config,
      legs: [leg, leg],
    );
    return (total: breakdown.total, distanceKm: roadKm);
  }

  static AssistantReply _recommend(
    Ask ask,
    List<Destination> places,
    TripConfig defaults,
  ) {
    final month = ask.month;
    final days = ask.days;
    final persons = ask.persons ?? defaults.persons;

    // Towns only. Suggesting a single viewpoint as a whole trip reads oddly,
    // and the towns carry the curated stops anyway.
    var pool = places.where((p) => !p.isSpot).toList();

    if (ask.category != null) {
      // A town counts if it *is* that kind of place or if it has one nearby.
      // Almost no town is categorised "Lakes" — the lakes are the stops around
      // it — so matching on the town's own category alone answered "somewhere
      // with lakes" with nothing at all.
      pool = pool
          .where((p) =>
              p.category == ask.category ||
              p.attractions.any((a) => _stopMatchesCategory(a.category, ask.category!)))
          .toList();
    }
    if (month != null) {
      pool = pool.where((p) => p.bestMonths.contains(month)).toList();
    }
    if (ask.avoids4x4) {
      pool = pool.where((p) => !p.requires4x4).toList();
    }
    if (days != null) {
      // A place that wants six days is a poor answer to a weekend.
      pool = pool.where((p) => p.recommendedDays <= days + 1).toList();
    }

    if (pool.isEmpty) {
      return AssistantReply(
        text: _noMatchText(ask),
        followUps: const [
          'Where can I go for a weekend?',
          'Somewhere with lakes',
          'Cheapest places for 3 days',
        ],
      );
    }

    final scored = <PlaceSuggestion>[];
    for (final place in pool) {
      final e = _estimate(place, defaults, days: days, persons: persons);
      if (ask.budget != null && e.total > ask.budget!) continue;

      // Somewhere you already are is not a trip. The catalogue holds the big
      // cities, so a recommendation from Islamabad was suggesting Islamabad at
      // zero kilometres and topping the cheapest list with it.
      if (e.distanceKm < _tooCloseToBotherKm) continue;

      final reasons = <String>[
        if (month != null) 'open in ${monthName(month)}',
        if (place.altitudeM >= 2500) '${place.altitudeM} m up',
        if (!place.requires4x4) 'no jeep needed' else 'needs a 4x4',
        '${place.attractions.length} places to see',
      ];

      scored.add(PlaceSuggestion(
        destination: place,
        estimatedTotal: e.total,
        distanceKm: e.distanceKm,
        reason: reasons.take(3).join('  ·  '),
      ));
    }

    if (scored.isEmpty) {
      return AssistantReply(
        text: 'Nothing in the guide comes in under ${money(ask.budget!)} for '
            '${plural(persons, 'person', 'people')}'
            '${days != null ? ' over ${plural(days, 'day', 'days')}' : ''}. '
            'The cheapest option is around '
            '${money(_cheapestTotal(pool, defaults, days, persons))}. '
            'Fewer days, camping instead of a hotel, or cooking rather than eating '
            'out are the three changes that move a total most.',
        followUps: const [
          'Cheapest places for a weekend',
          'Where can I camp?',
        ],
      );
    }

    // Cheapest first when money was mentioned, otherwise nearest — a shorter
    // drive is the thing most people actually want when they have not said.
    if (ask.wantsCheap || ask.budget != null) {
      scored.sort((a, b) => a.estimatedTotal.compareTo(b.estimatedTotal));
    } else {
      scored.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    }

    final top = scored.take(5).toList();
    final parts = <String>[
      if (ask.category != null) ask.category!.toLowerCase(),
      if (month != null) 'open in ${monthName(month)}',
      if (days != null) 'for ${plural(days, 'day', 'days')}',
      if (ask.budget != null) 'under ${money(ask.budget!)}',
      if (ask.avoids4x4) 'reachable without a jeep',
    ];

    return AssistantReply(
      text: '${top.length} '
          '${top.length == 1 ? 'place' : 'places'}'
          '${parts.isEmpty ? '' : ' — ${parts.join(', ')}'}, '
          '${ask.wantsCheap || ask.budget != null ? 'cheapest' : 'nearest'} first. '
          'Totals are for ${plural(persons, 'person', 'people')} and assume a '
          'straight-line distance until you open one and it gets routed properly.',
      suggestions: top,
      followUps: [
        'How much for ${top.first.destination.name}?',
        if (month == null) 'Which of these is best in December?',
        'What should I pack for ${top.first.destination.name}?',
      ],
    );
  }

  /// Whether a stop's own kind belongs to one of the broad categories people
  /// ask by. A stop is tagged "Lake" or "Waterfall"; the question says "lakes".
  static bool _stopMatchesCategory(String stopCategory, String category) {
    const map = {
      'Lakes': ['Lake', 'Waterfall', 'Spring', 'River'],
      'Beaches': ['Beach', 'Island'],
      'Mountains': ['Peak', 'Pass', 'Trek', 'Glacier', 'Viewpoint', 'Meadow', 'Plateau'],
      'Valleys': ['Valley', 'Meadow', 'Nature', 'Park'],
      'Hills': ['Viewpoint', 'Walk', 'Resort'],
      'Historical': ['Historical', 'Culture', 'Bazaar'],
      'Desert': ['Desert'],
      'City': ['Bazaar', 'Food', 'Historical'],
    };
    return map[category]?.contains(stopCategory) ?? false;
  }

  static double _cheapestTotal(
    List<Destination> pool,
    TripConfig defaults,
    int? days,
    int persons,
  ) {
    var best = double.infinity;
    for (final p in pool) {
      final e = _estimate(p, defaults, days: days, persons: persons);
      if (e.total < best) best = e.total;
    }
    return best;
  }

  static String _noMatchText(Ask ask) {
    final bits = <String>[
      if (ask.category != null) 'category ${ask.category}',
      if (ask.month != null) 'open in ${monthName(ask.month!)}',
      if (ask.days != null) 'suited to ${plural(ask.days!, 'day', 'days')}',
      if (ask.avoids4x4) 'reachable without a jeep',
    ];
    return 'Nothing in the guide matches ${bits.join(' and ')}. '
        '${ask.month != null ? 'A lot of the north is snow-closed outside May to '
            'October, so winter narrows the list to the plains, the coast and the '
            'lower hill stations. ' : ''}'
        'Try dropping one of those.';
  }

  static AssistantReply _cost(Ask ask, TripConfig defaults) {
    if (ask.places.isEmpty) return _dontKnow('');

    final place = ask.places.first;
    final days = ask.days ?? math.max(place.recommendedDays, 2);
    final persons = ask.persons ?? defaults.persons;
    final e = _estimate(place, defaults, days: days, persons: persons);

    return AssistantReply(
      text: '${place.name} for ${plural(persons, 'person', 'people')} over '
          '${plural(days, 'day', 'days')} comes to about '
          '${money(e.total)} — roughly ${money(e.total / persons)} each, '
          '${money(e.total / days)} a day.\n\n'
          'That is about ${km(e.distanceKm)} each way from ${defaults.originName}, '
          'at ${defaults.mileage.toStringAsFixed(1)} km/L and '
          '${moneyExact(defaults.fuelPrice)} a litre, with a '
          '${defaults.stayStyle.label.toLowerCase()} and '
          '${defaults.foodStyle.label.toLowerCase()}. '
          'Open it in the planner to route the road properly and change any of '
          'those assumptions.',
      suggestions: [
        PlaceSuggestion(
          destination: place,
          estimatedTotal: e.total,
          distanceKm: e.distanceKm,
          reason: '${plural(days, 'day', 'days')}  ·  '
              '${plural(persons, 'person', 'people')}',
        ),
      ],
      followUps: [
        'What should I pack for ${place.name}?',
        'When is the best time for ${place.name}?',
        'Somewhere cheaper than ${place.name}',
      ],
    );
  }

  static AssistantReply _compare(Ask ask, TripConfig defaults) {
    final a = ask.places[0];
    final b = ask.places[1];
    final days = ask.days;
    final persons = ask.persons ?? defaults.persons;

    final ea = _estimate(a, defaults, days: days, persons: persons);
    final eb = _estimate(b, defaults, days: days, persons: persons);

    final cheaper = ea.total <= eb.total ? a : b;
    final gap = (ea.total - eb.total).abs();

    return AssistantReply(
      text: '${a.name} is about ${money(ea.total)} and ${km(ea.distanceKm)} away; '
          '${b.name} is about ${money(eb.total)} and ${km(eb.distanceKm)}.\n\n'
          '${cheaper.name} is the cheaper of the two by ${money(gap)}. '
          '${a.requires4x4 != b.requires4x4 ? '${a.requires4x4 ? a.name : b.name} '
              'needs a 4x4 and ${a.requires4x4 ? b.name : a.name} does not, which '
              'may matter more than the money. ' : ''}'
          '${a.name} is best ${_monthsPhrase(a)}; ${b.name} ${_monthsPhrase(b)}.',
      suggestions: [
        PlaceSuggestion(
          destination: a,
          estimatedTotal: ea.total,
          distanceKm: ea.distanceKm,
          reason: _monthsPhrase(a),
        ),
        PlaceSuggestion(
          destination: b,
          estimatedTotal: eb.total,
          distanceKm: eb.distanceKm,
          reason: _monthsPhrase(b),
        ),
      ],
      followUps: [
        'How much for ${a.name} for 5 days?',
        'What should I pack for ${cheaper.name}?',
      ],
    );
  }

  static String _monthsPhrase(Destination d) {
    if (d.bestMonths.isEmpty) return 'open year round';
    if (d.bestMonths.length >= 11) return 'open year round';
    final names = d.bestMonths.map(shortMonthName).toList();
    return 'best ${names.first} to ${names.last}';
  }

  static AssistantReply _howFar(Ask ask, TripConfig defaults) {
    if (ask.places.isEmpty) {
      return const AssistantReply(
        text: 'Name a place and I will work out the distance from where you are. '
            'Try "how far is Skardu".',
        followUps: ['How far is Hunza?', 'How far is Naran?'],
      );
    }

    final place = ask.places.first;
    final straight = haversineKm(defaults.origin, place.point);
    final road = straight * place.roadFactor;
    final hours = road / AppDefaults.fallbackAverageSpeedKmh;

    return AssistantReply(
      text: '${place.name} is about ${km(road)} from ${defaults.originName} by road, '
          'roughly ${hours.toStringAsFixed(0)} hours of driving each way.\n\n'
          'That figure is a straight line of ${km(straight)} corrected by '
          '${place.roadFactor.toStringAsFixed(2)}× for the terrain. Open it in the '
          'planner and the real road gets measured, which is usually within a few '
          'per cent of this.'
          '${hours > AppDefaults.longDrivingDayHours ? '\n\nThat is beyond a '
              'comfortable single day, so budget for a night on the way.' : ''}',
      suggestions: [
        PlaceSuggestion(
          destination: place,
          estimatedTotal: _estimate(place, defaults).total,
          distanceKm: road,
          reason: '${hours.toStringAsFixed(0)} h each way',
        ),
      ],
      followUps: ['How much for ${place.name}?', 'When should I go to ${place.name}?'],
    );
  }

  static AssistantReply _whenToGo(Ask ask) {
    if (ask.places.isEmpty) {
      final month = ask.month;
      if (month == null) {
        return const AssistantReply(
          text: 'Name a place and I will tell you its season, or name a month and '
              'I will tell you where is open.',
          followUps: ['Where is open in January?', 'When should I go to Hunza?'],
        );
      }
      return AssistantReply(
        text: 'Ask me "where can I go in ${monthName(month)}" and I will list the '
            'places that are open then.',
        followUps: ['Where can I go in ${monthName(month)}?'],
      );
    }

    final place = ask.places.first;
    final months = place.bestMonths;
    final closed = [
      for (var m = 1; m <= 12; m++)
        if (!months.contains(m)) shortMonthName(m),
    ];

    return AssistantReply(
      text: '${place.name} is ${_monthsPhrase(place)}.\n\n'
          '${closed.isEmpty ? 'It is worth going at any time of year.' : 'Outside '
              'that — ${closed.join(', ')} — expect it to be cold, wet or '
              'snow-closed.'}'
          '${place.altitudeM >= 3000 ? ' At ${place.altitudeM} m, nights drop below '
              'freezing even in summer.' : ''}'
          '\n\nThe destination screen shows real weather for your dates, measured '
          'at these coordinates rather than inherited from the nearest town.',
      followUps: [
        'How much for ${place.name}?',
        'What should I pack for ${place.name}?',
      ],
    );
  }

  static AssistantReply _needs4x4(Ask ask) {
    if (ask.places.isEmpty) {
      return const AssistantReply(
        text: 'Name a place and I will tell you whether the road in wants a 4x4. '
            'Or ask "where can I go without a jeep".',
        followUps: [
          'Where can I go without a jeep?',
          'Does Fairy Meadows need a 4x4?',
        ],
      );
    }

    final place = ask.places.first;
    final jeepStops =
        place.attractions.where((a) => a.requires4x4).map((a) => a.name).toList();

    return AssistantReply(
      text: place.requires4x4
          ? 'Yes — the road into ${place.name} expects a 4x4, and a small car will '
              'struggle or be turned back.'
              '${jeepStops.isEmpty ? '' : ' Beyond that, '
                  '${jeepStops.join(', ')} '
                  '${jeepStops.length == 1 ? 'needs' : 'need'} a jeep as well, '
                  'usually hired locally rather than driven yourself.'}'
          : '${place.name} itself is reachable in an ordinary car.'
              '${jeepStops.isEmpty ? ' None of its nearby stops need a jeep either.' : ' '
                  'But ${jeepStops.join(', ')} '
                  '${jeepStops.length == 1 ? 'does' : 'do'} — those are usually a '
                  'hired jeep from the town, and the planner adds that fare when '
                  'you select them.'}',
      followUps: ['Where can I go without a jeep?', 'How much for ${place.name}?'],
    );
  }

  static AssistantReply _packing(Ask ask, TripConfig defaults) {
    if (ask.places.isEmpty) {
      return const AssistantReply(
        text: 'Name a place and I will build a list from the altitude, the month '
            'and how you are travelling. Try "what should I pack for Skardu in '
            'December".',
        followUps: ['What should I pack for Hunza?'],
      );
    }

    final place = ask.places.first;
    final days = ask.days ?? math.max(place.recommendedDays, 2);
    final start = ask.month == null
        ? defaults.startDate
        : DateTime(defaults.startDate.year, ask.month!, 15);

    final config = defaults.copyWith(
      stops: [TripStop(destination: place, nights: days > 1 ? days - 1 : 0)],
      days: days,
      startDate: start,
      mealPlan: defaults.mealPlan.resized(days),
    );

    final sections = PackingBuilder.build(config: config);
    final critical = sections
        .expand((s) => s.items)
        .where((i) => i.critical)
        .map((i) => i.label)
        .toList();

    return AssistantReply(
      text: 'For ${place.name} in ${monthName(start.month)}, over '
          '${plural(days, 'day', 'days')}, the list comes to '
          '${sections.expand((s) => s.items).length} items across '
          '${plural(sections.length, 'section', 'sections')}.\n\n'
          '${critical.isEmpty ? '' : 'The ones that matter most: '
              '${critical.take(6).join(', ')}.\n\n'}'
          'It is built from the altitude, the month, whether you are camping and '
          'whether any stop needs a jeep — so it changes with the plan rather than '
          'being a fixed list. Open the trip and tap Packing list for the whole '
          'thing with tick boxes.',
      followUps: [
        'When should I go to ${place.name}?',
        'Does ${place.name} need a 4x4?',
      ],
    );
  }

  /// Something has gone wrong. Answer with the one action that matters and put
  /// the ordered steps one tap away.
  ///
  /// Deliberately short. A chat bubble is the wrong place for fifteen numbered
  /// steps, and a person in trouble scrolling a transcript to find step four is
  /// a person the app has failed.
  static AssistantReply _emergency(Ask ask) {
    final guide = ask.guide!;
    return AssistantReply(
      text: '${guide.title}.\n\n${guide.firstThing}\n\n'
          '${guide.steps.length} steps follow, in order. ${guide.callFor}',
      guide: guide,
      followUps: [
        for (final other in _relatedTo(guide.kind)) Survival.forKind(other).title,
      ],
    );
  }

  /// Situations that tend to arrive together. Someone out of fuel at dusk in
  /// the mountains needs three of these, not one.
  static List<Emergency> _relatedTo(Emergency kind) => switch (kind) {
        Emergency.fuel => [Emergency.noSignal, Emergency.night],
        Emergency.fire => [Emergency.cold, Emergency.night],
        Emergency.lost => [Emergency.noSignal, Emergency.night, Emergency.water],
        Emergency.stuck => [Emergency.night, Emergency.cold],
        Emergency.breakdown => [Emergency.noSignal, Emergency.fuel],
        Emergency.blocked => [Emergency.night, Emergency.storm],
        Emergency.cold => [Emergency.fire, Emergency.night],
        Emergency.heat => [Emergency.water, Emergency.injury],
        Emergency.altitude => [Emergency.injury, Emergency.noSignal],
        Emergency.water => [Emergency.heat, Emergency.lost],
        Emergency.night => [Emergency.fire, Emergency.cold],
        Emergency.storm => [Emergency.blocked, Emergency.night],
        Emergency.bite => [Emergency.injury, Emergency.noSignal],
        Emergency.injury => [Emergency.noSignal, Emergency.bite],
        Emergency.noSignal => [Emergency.lost, Emergency.night],
      };

  static AssistantReply _appHelp(String question) {
    final q = normalize(question);

    if (_any(q, ['fuel', 'petrol', 'diesel', 'mileage', 'km/l'])) {
      return const AssistantReply(
        text: 'Fuel is worked out from the distance and your vehicle, not guessed: '
            'total kilometres ÷ your km per litre = litres, × the pump price. All '
            'four numbers are shown so you can check the result.\n\n'
            'Pakistan reprices petrol daily, so the figure the app ships with goes '
            'stale fast. Set today\'s price in the Rates tab — it moves the whole '
            'total.',
        followUps: ['Where do the prices come from?', 'How accurate are the distances?'],
      );
    }
    if (_any(q, ['price', 'prices', 'cost', 'accurate', 'where does the data',
        'where do prices'])) {
      return const AssistantReply(
        text: 'Every price is an editable estimate, not a live rate. Hotel, food '
            'and ticket figures start from typical values and are all overridable; '
            'nothing is fetched from a booking service, because no free one exists.\n\n'
            'Distances and maps come from OpenStreetMap and OSRM, and the weather '
            'from Open-Meteo. All free, no keys, no account. Treat the total as a '
            'planning figure and confirm anything you are about to pay.',
        followUps: ['How is fuel calculated?', 'How accurate are the distances?'],
      );
    }
    if (_any(q, ['distance', 'km', 'route', 'google'])) {
      return const AssistantReply(
        text: 'Distance is the real road, routed through OSRM, and the app takes '
            'the shortest of the routes it offers rather than the fastest. It will '
            'not match Google exactly — different road data and different routing, '
            'usually within a few per cent.\n\n'
            'If a leg cannot be routed the app falls back to a straight line times '
            'a terrain factor and labels the figure as estimated, so you always '
            'know which kind of number you are looking at.',
        followUps: ['How is fuel calculated?', 'Where do the prices come from?'],
      );
    }
    if (_any(q, ['pdf', 'export', 'share', 'send'])) {
      return const AssistantReply(
        text: 'Open a trip through to the summary and tap Export as PDF. It builds '
            'the whole plan — costs, the route leg by leg, the day-by-day itinerary '
            'and the packing list — then opens the share sheet so it can go to '
            'WhatsApp, Drive or Files.',
        followUps: ['How do I save a trip?'],
      );
    }
    if (_any(q, ['save', 'saved', 'my trips'])) {
      return const AssistantReply(
        text: 'Tap Save this trip on the summary, or the bookmark in the top bar. '
            'Saved trips live under My trips, stored on this device with the exact '
            'rates they were costed under — so reopening one later shows what you '
            'planned, not what today\'s prices would make it.',
        followUps: ['How do I export a PDF?'],
      );
    }
    if (_any(q, ['dark mode', 'theme', 'light mode'])) {
      return const AssistantReply(
        text: 'The Rates tab has a theme setting: follow the system, or force light '
            'or dark. It follows your phone by default.',
      );
    }

    return const AssistantReply(
      text: 'I can explain how the costing works, where the data comes from, how '
          'accurate the distances are, and how to save or export a trip. Ask about '
          'any of those.',
      followUps: [
        'How is fuel calculated?',
        'Where do the prices come from?',
        'How do I export a PDF?',
      ],
    );
  }

  static AssistantReply _dontKnow(String question) => const AssistantReply(
        text: 'I did not follow that. I work from this app\'s own data rather than '
            'the open internet, so I am good at a narrow set of things:\n\n'
            '• recommending places by month, budget, days or kind\n'
            '• costing a specific trip\n'
            '• distances and driving times\n'
            '• seasons and whether a road needs a 4x4\n'
            '• what to pack\n'
            '• how the app works\n\n'
            'Try one of the questions below.',
        followUps: [
          'Where can I go for a weekend?',
          'How much for Hunza for 4 people?',
          'Somewhere with lakes in June',
          'Where can I go without a jeep?',
        ],
      );
}
