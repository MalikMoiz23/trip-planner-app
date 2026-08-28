# Trip Planner

A Flutter trip-cost planner for travel in Pakistan. Pick a destination, set the days
and the number of people, and get the whole trip costed — fuel, rooms, food, entry
tickets, jeep fares — broken down per person and per day, with a day-by-day itinerary.

Built entirely on free, key-less services. There is no paid API, no account, and no
backend anywhere in it.

## What it does

- **32 curated destinations** with 132 nearby stops — Naran, Hunza, Skardu, Fairy
  Meadows, Swat, Kumrat, Neelum, Chitral, Thandiani, Rawalakot, Phander, Khaplu,
  Bahawalpur, Thatta, Gwadar and more — each with coordinates, altitude, best months,
  terrain notes, entry fees and visit durations.
- **Typo-tolerant search** across all four provinces plus GB and AJK. "Thandyaani
  top", "panjpeer", "muree", "neelam valley" and "skardo" all land on the right
  place. See [Search](#search) for how.
- **Live search** for anything not in the catalogue, via OpenStreetMap.
- **Real road distance** from your GPS location to the destination, and the drive time.
- **Nearby attractions**, curated plus a live OpenStreetMap lookup within 35 km.
  Adding a stop adds its detour distance, its tickets and its jeep or boat fare to
  the total.
- **Full cost breakdown** — total, per person, per day, per person per day — with a
  stacked bar and a value table showing where every rupee goes.
- **Day-by-day itinerary**, packing stops to a ceiling of 9 sightseeing hours a day
  and splitting the drive across two days when one leg runs past 9 hours.
- **Advisories** — too few days for the plan, out-of-season month, 4x4 needed, more
  people than vehicle seats, high altitude, and how much of the total rests on
  estimated rather than curated prices.
- **Saved trips**, stored locally with the exact rates they were costed under.

## Search

Romanised Urdu has no single agreed spelling, and the public geocoder matches
near-exactly. Measured against Nominatim directly:

| Query | Nominatim alone | This app |
|---|---|---|
| `Thandyani Top` | 0 results | Thandiani |
| `Panj Peer Rocks` | 0 results | Murree — *has Panj Peer Rocks* |
| `Panj Pir` | 1, Urdu name only (`پنج پیر`) | Murree — *has Panj Peer Rocks* |

Three mechanisms, cheapest first:

1. **Alias lists.** Every destination and stop carries its common alternate
   spellings — 430 of them in the bundled data.
2. **Fuzzy scoring** (`lib/core/fuzzy.dart`). Place-kind words like *Top*, *Rocks*
   and *Lake* are stripped from both sides; a phonetic fold collapses aspirated
   digraphs and every vowel, so `Thandyani` and `Thandiani` become the same key; the
   remainder is ranked by optimal-string-alignment distance, which counts a swapped
   pair of letters as one typo rather than two. Results are ranked, and the UI says
   so when nothing matched exactly.
3. **Query relaxation** for the live geocoder. The original query goes first; if it
   returns nothing, place-kind words are dropped and the query is progressively
   shortened, capped at four attempts to respect the ~1 request/second policy.

A rewritten query is held to a resemblance check that the original is not: the
geocoder's own ranking can legitimately connect "Kotli Sattian Rocks" to Panjpeer
Rocks, but blind shortening turns "Neela Sandh Waterfall" into "Neela" and returns
*Neela Botho*, a different place. Hits from a rewritten query must still score
against what was typed, and the UI states which query it actually ran.

Matching against a stop rather than a destination is labelled — searching
"panj peer rocks" returns Murree with *has Panj Peer Rocks* under it, because an
unexplained result reads as a bug.

## The cost model

Distance is modelled as a drive out to a base town and back, with each chosen stop
as a return day trip from that base. That is how these valleys are actually toured —
you keep one hotel and radiate out — and it never undercounts the way a single
point-to-point line would.

```
totalKm      = 2 x oneWayKm + Σ (2 x detour to each chosen stop)
fuel         = totalKm / mileage x pricePerLitre          (own vehicle)
transport    = (2 x oneWayKm) x ratePerKm x persons       (public transport)
rooms        = ceil(persons / occupancy)
stay         = (days - 1) x rooms x ratePerRoomNight
food         = days x persons x ratePerPersonDay
tickets      = Σ entryFee x persons
localFares   = Σ jeepFare x persons  (+ a daily allowance on public transport)
subtotal     = fuel/transport + stay + food + tickets + localFares + tolls
total        = subtotal x (1 + buffer%)
```

Everything else — per person, per day, per person per day — divides out of `total`.

## Services used

| Purpose | Service | Cost |
|---|---|---|
| Road distance and duration | [OSRM](https://project-osrm.org) demo server | Free, no key |
| Place search, reverse geocoding | [Nominatim](https://nominatim.org) | Free, no key |
| Nearby attractions | [Overpass API](https://overpass-api.de) | Free, no key |
| Map tiles | OpenStreetMap raster tiles | Free, no key |

Map data © OpenStreetMap contributors.

All four are public shared instances bound by usage policies: requests are debounced,
cached, and sent with an identifying `User-Agent`. If OSRM cannot be reached, distance
falls back to great-circle distance times a per-destination terrain factor and the UI
labels the figure **Estimated** rather than presenting it as measured.

OpenStreetMap carries names and coordinates but no prices, so a stop found by live
lookup is costed from typical rates for its kind of place — a lake gate fee, a jeep up
to a meadow, a boat out to an island — via `lib/logic/rate_estimator.dart`. Without
this, a trip planned around searched places came out as travel-only. Those figures are
labelled **Est.** on the stop and called out in the breakdown's advisories, and typing
a real number in clears the flag. Nodes named only in Urdu script are skipped rather
than shown as mojibake.

## Read this before trusting a number

**Every price in this app is an editable assumption, not a live rate.** Fuel, hotel,
food and ticket figures ship as starting estimates and are all overridable in the
planner and in the Rates tab. Nothing is fetched from a booking service. Update the
fuel price to what you are actually paying before relying on a total.

Destination coordinates are approximate town and landmark centroids — accurate enough
for a distance estimate, not for navigation.

## Running it

```bash
flutter pub get
flutter run                 # attached device or emulator
flutter run -d chrome       # in a browser
```

`flutter run` reads stdin for its `r` / `R` / `q` keys, so it must be started from an
interactive terminal — launched from a non-interactive shell it sees EOF and quits
immediately.

## Tests

```bash
flutter analyze             # 0 issues
flutter test                # 59 tests
```

- `test/search_test.dart` — fuzzy matching, query relaxation, the rate estimator, and
  every misspelling in the tables above resolved against the real catalogue.
- `test/expense_calculator_test.dart` — the cost model and itinerary builder, including
  that the breakdown lines always sum to the total.
- `test/widget_test.dart` — validates the bundled catalogue: unique ids, sane
  coordinates, months in range, no negative fees.
- `test/screens_render_test.dart` — renders every screen at 360x780 and 430x932 and
  fails on any layout exception, with all network clients stubbed to throw so the
  offline paths are the ones under test. This is what catches `RenderFlex` overflows.

Screenshots live in `test/goldens/`. Golden *comparison* is opt-in because the bytes
depend on host font rasterisation:

```bash
GOLDENS=1 flutter test test/screens_render_test.dart --update-goldens
```

## Layout

```
lib/
  core/          theme, palette, formatters, geo maths, constants
  models/        destination, attraction, trip config, breakdown, itinerary
  services/      OSRM, Nominatim, Overpass, geolocation, local storage
  logic/         expense calculator, itinerary builder
  state/         AppState (catalogue, saved trips, rates), PlannerController
  ui/            screens and widgets
assets/data/     destinations.json — the bundled catalogue
```

The cost engine in `lib/logic/expense_calculator.dart` is a pure function with no
Flutter or network dependency, which is why it can be tested directly.

## Adding a destination

Append to `assets/data/destinations.json`. `roadFactor` is the straight-line-to-road
multiplier used only when routing is unavailable — around 1.25 on the plains, 1.75 in
the mountains. Put every spelling you have heard used into `aliases`, on the
destination and on each stop; that list is the cheapest and most reliable half of
search. `test/widget_test.dart` will reject a malformed entry and `test/search_test.dart`
will reject a missing `aliases` key.

## Notes

- Destination artwork is a per-category gradient with a watermark glyph rather than
  photography, so it renders identically offline and never shows a broken image. The
  JSON schema supports an `imageUrl` if you want to add real photos.
- The typeface (Plus Jakarta Sans, SIL Open Font License) is bundled in
  `assets/fonts/`, not fetched at runtime. Fetching it caused two bugs: the font
  arrived after first layout, so intrinsically-sized widgets like the category chips
  were measured in one face and painted in a wider one and clipped their labels; and
  with no network the web build rendered no text at all. Bundling also means the
  goldens use the exact files the app ships.
- A dark palette is defined and contrast-validated but not switched on; `themeMode`
  is pinned to light in `lib/app.dart`.
- Chart colours are a categorical palette validated for lightness band, chroma floor,
  adjacent colour-vision-deficiency separation and surface contrast. The three slots
  that fall below 3:1 on the light surface are relieved by direct value labels and a
  table view.
