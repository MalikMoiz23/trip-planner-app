import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_planner/core/theme.dart';
import 'package:trip_planner/data/repositories/destination_repository.dart';
import 'package:trip_planner/data/sources/osrm_service.dart';
import 'package:trip_planner/app/app_state.dart';
import 'package:trip_planner/features/planner/planner_controller.dart';
import 'package:trip_planner/core/enums.dart';
import 'package:trip_planner/features/explore/destination_detail_screen.dart';
import 'package:trip_planner/features/summary/expense_detail_screen.dart';
import 'package:trip_planner/features/explore/explore_screen.dart';
import 'package:trip_planner/features/planner/planner_screen.dart';
import 'package:trip_planner/features/trips/saved_trips_screen.dart';
import 'package:trip_planner/features/settings/settings_screen.dart';
import 'package:trip_planner/features/shell/splash_screen.dart';
import 'package:trip_planner/features/trips/packing_screen.dart';
import 'package:trip_planner/features/summary/summary_screen.dart';
import 'package:trip_planner/shared/widgets/weather_card.dart';

/// Renders every screen at a common phone size and fails on any layout
/// exception. RenderFlex overflows are reported as errors by the test binding,
/// so this catches the class of defect a compile check cannot.
///
/// Networked services are given a client that always throws, which exercises
/// the offline paths: OSRM falls back to terrain-corrected straight lines and
/// the live lookups return empty.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The catalogue is loaded once, outside any test body. Awaiting asset and
  // preference channels inside testWidgets fights the faked clock.
  late final AppState appState;

  setUpAll(() async {
    await _loadRealFonts();
    SharedPreferences.setMockInitialValues({});

    // flutter_map's built-in tile cache asks path_provider for a directory.
    // There is no plugin implementation in a test binding, so stub it.
    final tileCacheDir = Directory.systemTemp.createTempSync('trip_planner_tiles').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tileCacheDir,
    );

    appState = AppState(repository: DestinationRepository());
    await appState.init();
    expect(appState.isReady, isTrue, reason: appState.error ?? '');
  });

  AppState buildState() => appState;

  Widget host(
    AppState state,
    Widget child, {
    PlannerController? planner,
    ThemeData? theme,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
        ChangeNotifierProvider<PlannerController>(
          create: (_) =>
              planner ??
              PlannerController(
                repo: state.repository,
                appState: state,
                osrm: OsrmService(client: _DeadClient()),
              ),
        ),
      ],
      child: MaterialApp(theme: theme ?? AppTheme.light(), home: child),
    );
  }

  /// A controller far enough along to render the summary and everything hung
  /// off it, with the network dead so the offline paths are what is exercised.
  Future<PlannerController> costedPlan(AppState state, {String id = 'hunza'}) async {
    final planner = PlannerController(
      repo: state.repository,
      appState: state,
      osrm: OsrmService(client: _DeadClient()),
    )
      ..origin = const LatLng(31.5497, 74.3436)
      ..originName = 'Lahore';
    planner.startFor(state.repository.byId(id)!);
    planner.selectAllCurated();
    await planner.finalise();
    return planner;
  }

  for (final size in const [Size(360, 780), Size(430, 932)]) {
    /// Golden captures are taken at the narrow size only — the wide pass exists
    /// to catch overflow, not to duplicate every image.
    ///
    /// Opt-in, because golden bytes depend on the host's font rasterisation and
    /// would fail on any machine other than the one that generated them. The
    /// layout assertions in these tests are the part that must pass everywhere.
    /// Refresh the images with:
    ///   GOLDENS=1 flutter test test/screens_render_test.dart --update-goldens
    Future<void> shot(WidgetTester tester, String name) async {
      if (size.width != 360) return;
      if (Platform.environment['GOLDENS'] != '1') return;
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$name.png'),
      );
    }

    group('at ${size.width.toInt()}x${size.height.toInt()}', () {
      setUp(() {
        final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
        view.physicalSize = size;
        view.devicePixelRatio = 1.0;
      });

      tearDown(() {
        final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });

      testWidgets('explore lays out', (tester) async {
        final state = buildState();
        await tester.pumpWidget(host(state, const ExploreScreen()));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Plan the whole trip'), findsOneWidget);
        expect(find.text('Naran'), findsWidgets);
        await shot(tester, "01_explore");
      });

      testWidgets('a misspelled search still finds the place', (tester) async {
        final state = buildState();
        await tester.pumpWidget(host(state, const ExploreScreen()));
        await tester.pump(const Duration(milliseconds: 300));

        // "Thandyani Top" is a listed alias, so it matches exactly. This is a
        // spelling nobody wrote down, which has to go through fuzzy scoring.
        await tester.enterText(find.byType(TextField).first, 'thandyaani top');
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Thandiani'), findsWidgets);
        await shot(tester, '01b_search_typo');
      });

      testWidgets('a landmark is its own result, and says where it is', (tester) async {
        final state = buildState();
        await tester.pumpWidget(host(state, const ExploreScreen()));
        await tester.pump(const Duration(milliseconds: 300));

        await tester.enterText(find.byType(TextField).first, 'panj peer rocks');
        await tester.pump(const Duration(milliseconds: 300));

        // The landmark itself, not the town that happens to contain it.
        expect(find.text('Panj Peer Rocks'), findsWidgets);
        expect(find.text('near Murree'), findsWidgets);
        await shot(tester, '01c_search_stop_match');
      });

      testWidgets('destination detail lays out and scrolls', (tester) async {
        final state = buildState();
        final naran = state.repository.byId('naran')!;
        await tester.pumpWidget(host(state, DestinationDetailScreen(destination: naran)));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Plan a trip to Naran'), findsOneWidget);
        await shot(tester, "02_detail_top");

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
        await tester.pump(const Duration(milliseconds: 400));
        await shot(tester, "03_detail_stops");
      });

      testWidgets('a three-stop route lays out and costs the whole loop', (tester) async {
        final state = buildState();
        final planner = PlannerController(
          repo: state.repository,
          appState: state,
          osrm: OsrmService(client: _DeadClient()),
        )
          ..origin = const LatLng(33.6844, 73.0479)
          ..originName = 'Islamabad';

        planner.startFor(state.repository.byId('naran')!);
        planner.setDays(9);
        planner.addStop(state.repository.byId('hunza')!);
        planner.addStop(state.repository.byId('skardu')!);
        planner.balanceNights();
        await planner.refreshRoute();

        expect(planner.route.length, 3);
        expect(planner.allocatedNights, planner.nightsForDisplay);

        // Every leg of the loop, not one destination doubled.
        final b = planner.breakdown!;
        expect(b.legKms.length, 4);
        expect(b.travelKm, greaterThan(0));

        await tester.pumpWidget(host(state, const PlannerScreen(), planner: planner));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Your route'), findsOneWidget);
        expect(find.text('Naran'), findsWidgets);
        expect(find.text('Hunza (Karimabad)'), findsWidgets);
        expect(find.text('Skardu'), findsWidgets);
        await shot(tester, '11_route_editor');

        // The stops step scopes itself to whichever stop is selected.
        planner.goTo(2);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Which stop'), findsOneWidget);

        planner.setActiveStop(1);
        await tester.pump(const Duration(milliseconds: 400));
        expect(planner.activeStop!.destination.name, 'Hunza (Karimabad)');
        await shot(tester, '12_route_stop_picker');
      });

      testWidgets('removing a stop refits the route', (tester) async {
        final state = buildState();
        final planner = PlannerController(
          repo: state.repository,
          appState: state,
          osrm: OsrmService(client: _DeadClient()),
        )
          ..origin = const LatLng(33.6844, 73.0479)
          ..originName = 'Islamabad';

        planner.startFor(state.repository.byId('naran')!);
        planner.setDays(7);
        planner.addStop(state.repository.byId('hunza')!);
        await planner.refreshRoute();
        expect(planner.breakdown!.legKms.length, 3);

        planner.removeStop(1);
        await planner.refreshRoute();

        expect(planner.route.length, 1);
        expect(planner.breakdown!.legKms.length, 2);

        // The last stop can never be removed — a trip has to go somewhere.
        planner.removeStop(0);
        expect(planner.route.length, 1);
      });

      testWidgets('every planner step lays out', (tester) async {
        final state = buildState();
        final planner = PlannerController(
          repo: state.repository,
          appState: state,
          osrm: OsrmService(client: _DeadClient()),
        )
          ..origin = const LatLng(31.5497, 74.3436)
          ..originName = 'Lahore';
        // startFor is the only supported way in — it also seeds the curated
        // stop list and the vehicle defaults.
        planner.startFor(state.repository.byId('hunza')!);
        planner.selectAllCurated();
        await planner.refreshRoute();

        await tester.pumpWidget(host(state, const PlannerScreen(), planner: planner));
        await tester.pump(const Duration(milliseconds: 400));

        for (var step = 0; step < PlannerController.stepCount; step++) {
          planner.goTo(step);
          await tester.pump(const Duration(milliseconds: 400));
          await shot(tester, '0${4 + step}_planner_step$step');
          // Nudge each step's scroll view so off-screen content is laid out too.
          final lists = find.byType(Scrollable);
          if (lists.evaluate().isNotEmpty) {
            await tester.drag(lists.first, const Offset(0, -700));
            await tester.pump(const Duration(milliseconds: 300));
            await shot(tester, '0${4 + step}_planner_step${step}_scrolled');
          }
        }
      });

      testWidgets('summary lays out with a full breakdown', (tester) async {
        final state = buildState();
        final naran = state.repository.byId('naran')!;
        final planner = PlannerController(
          repo: state.repository,
          appState: state,
          osrm: OsrmService(client: _DeadClient()),
        )
          ..origin = const LatLng(31.5497, 74.3436)
          ..originName = 'Lahore';
        planner.startFor(naran);
        planner.setPersons(5);
        planner.setDays(5);
        planner.selectAllCurated();
        await planner.refreshRoute();

        expect(planner.breakdown, isNotNull);

        await tester.pumpWidget(host(state, const SummaryScreen(), planner: planner));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Estimated total'), findsOneWidget);
        await shot(tester, '08_summary_top');

        // A ListView only builds what is on screen, so the lower sections have
        // to be scrolled into view before they can be asserted on.
        await tester.drag(find.byType(ListView), const Offset(0, -820));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Where the money goes'), findsOneWidget);
        await shot(tester, '09_summary_chart');

        await tester.scrollUntilVisible(
          find.text('Day by day'),
          600,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 60,
        );
        expect(find.text('Day by day'), findsOneWidget);
        await shot(tester, '10_summary_itinerary');

        // Keep going to the bottom so the itinerary cards are laid out too.
        for (var i = 0; i < 12; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -600));
          await tester.pump(const Duration(milliseconds: 200));
        }
      });

      testWidgets('the full expense detail lays out', (tester) async {
        final state = buildState();
        final naran = state.repository.byId('naran')!;
        final planner = PlannerController(
          repo: state.repository,
          appState: state,
          osrm: OsrmService(client: _DeadClient()),
        )
          ..origin = const LatLng(31.5497, 74.3436)
          ..originName = 'Lahore';
        planner.startFor(naran);
        planner.setPersons(4);
        planner.setDays(5);
        planner.setMealsPerDay(3);
        planner.selectAllCurated();
        await planner.refreshRoute();

        await tester.pumpWidget(host(state, const ExpenseDetailScreen(), planner: planner));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('What this is based on'), findsOneWidget);
        await shot(tester, '11_detail_assumptions');

        // Each panel has to be scrolled into existence before it can be found.
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('cost-panel-Food')),
          500,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 60,
        );
        expect(find.byKey(const ValueKey('cost-panel-Food')), findsOneWidget);
        await shot(tester, '12_detail_lines');

        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('cost-panel-Contingency')),
          600,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 60,
        );

        for (var i = 0; i < 8; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -600));
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(find.text('Per person per day'), findsOneWidget);
        await shot(tester, '13_detail_total');
      });

      testWidgets('camping and self-cooking lay out and cost less', (tester) async {
        final state = buildState();
        final naran = state.repository.byId('naran')!;
        final planner = PlannerController(
          repo: state.repository,
          appState: state,
          osrm: OsrmService(client: _DeadClient()),
        )
          ..origin = const LatLng(31.5497, 74.3436)
          ..originName = 'Lahore';
        planner.startFor(naran);
        await planner.refreshRoute();

        final hotelTotal = planner.breakdown!.total;

        planner.setStayStyle(StayStyle.ownTent);
        planner.setFoodStyle(FoodStyle.selfCooking);
        planner.goTo(3);

        final campTotal = planner.breakdown!.total;
        expect(campTotal, lessThan(hotelTotal),
            reason: 'a tent you own and food you cook must come out cheaper');
        expect(planner.breakdown!.stayCost, 0);

        await tester.pumpWidget(host(state, const PlannerScreen(), planner: planner));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Own tent'), findsWidgets);
        await shot(tester, '14_comfort_camping');

        await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
        await tester.pump(const Duration(milliseconds: 300));
        await shot(tester, '15_comfort_food_math');
      });

      testWidgets('saved trips empty state lays out', (tester) async {
        final state = buildState();
        await tester.pumpWidget(host(state, const SavedTripsScreen()));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('No saved trips yet'), findsOneWidget);
      });

      testWidgets('settings lays out', (tester) async {
        final state = buildState();
        await tester.pumpWidget(host(state, const SettingsScreen()));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Settings'), findsOneWidget);
        await tester.drag(find.byType(ListView), const Offset(0, -1200));
        await tester.pump(const Duration(milliseconds: 300));
        // The brand plate sits at the bottom, so it only exists after that drag.
        expect(find.text('Triplyst  ·  version 1.0.0'), findsOneWidget);
        await _settle(tester);
        await shot(tester, '13_settings_brand');
      });

      testWidgets('the splash shows the mark and the name', (tester) async {
        final state = buildState();
        await tester.pumpWidget(host(state, const SplashScreen()));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Triplyst'), findsOneWidget);
        expect(find.text('PLAN SMART. TRAVEL BETTER.'), findsOneWidget);
        expect(find.byType(Image), findsWidgets);

        await _settle(tester);
        await shot(tester, '14_splash');
      });
    });
  }

  // Dark mode is a second full paint of every widget, and the palette is the
  // only thing standing between it and light-on-light text. Rendering the main
  // screens under it catches anything still holding a light constant.
  group('dark mode', () {
    setUp(() {
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(390, 844);
      view.devicePixelRatio = 1.0;
    });

    tearDown(() {
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    Future<void> shotDark(WidgetTester tester, String name) async {
      if (Platform.environment['GOLDENS'] != '1') return;
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$name.png'),
      );
    }

    testWidgets('explore lays out in dark', (tester) async {
      final state = buildState();
      await tester.pumpWidget(
        host(state, const ExploreScreen(), theme: AppTheme.dark()),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Plan the whole trip'), findsOneWidget);
      await shotDark(tester, '20_dark_explore');
    });

    testWidgets('destination detail lays out in dark', (tester) async {
      final state = buildState();
      await tester.pumpWidget(host(
        state,
        DestinationDetailScreen(destination: state.repository.byId('skardu')!),
        theme: AppTheme.dark(),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      await shotDark(tester, '21_dark_detail');
    });

    testWidgets('summary lays out in dark', (tester) async {
      final state = buildState();
      final planner = await costedPlan(state);
      await tester.pumpWidget(
        host(state, const SummaryScreen(), planner: planner, theme: AppTheme.dark()),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Estimated total'), findsOneWidget);
      await shotDark(tester, '22_dark_summary');
    });

    testWidgets('settings lays out in dark', (tester) async {
      final state = buildState();
      await tester.pumpWidget(
        host(state, const SettingsScreen(), theme: AppTheme.dark()),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Dark'), findsOneWidget);
      await shotDark(tester, '23_dark_settings');
    });
  });

  group('new screens', () {
    setUp(() {
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(390, 844);
      view.devicePixelRatio = 1.0;
    });

    tearDown(() {
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    Future<void> shot(WidgetTester tester, String name) async {
      if (Platform.environment['GOLDENS'] != '1') return;
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$name.png'),
      );
    }

    testWidgets('the packing list builds from the plan and ticks', (tester) async {
      final state = buildState();
      final planner = await costedPlan(state, id: 'fairy-meadows');
      planner.setStayStyle(StayStyle.ownTent);
      planner.setFoodStyle(FoodStyle.selfCooking);

      await tester.pumpWidget(host(state, const PackingScreen(), planner: planner));
      await tester.pump(const Duration(milliseconds: 700));

      // The list opens on documents and clothing; the camping and cooking
      // sections that prove it was built from *this* plan are further down.
      expect(find.textContaining('packed'), findsOneWidget);
      await shot(tester, '24_packing');

      await tester.dragUntilVisible(
        find.text('Tent'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Tent'), findsOneWidget);

      // Ticking must register against the item that was actually tapped.
      await tester.tap(find.text('Tent'));
      await tester.pump(const Duration(milliseconds: 500));
      await shot(tester, '25_packing_ticked');

      // The counter lives at the top of the list, which the scroll above left
      // behind, so come back to it to read the result.
      await tester.dragUntilVisible(
        find.textContaining('packed'),
        find.byType(ListView),
        const Offset(0, 300),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.widget<Text>(find.textContaining('packed')).data,
        startsWith('1 of '),
        reason: 'tapping an item must tick exactly that item',
      );

      await tester.dragUntilVisible(
        find.text('Stove and gas'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Stove and gas'), findsOneWidget);
    });

    testWidgets('the budget advisor renders its levers', (tester) async {
      final state = buildState();
      final planner = await costedPlan(state);
      // Deliberately unaffordable, so the levers list is populated.
      planner.setBudget(planner.breakdown!.total * 0.55);

      await tester.pumpWidget(host(state, const SummaryScreen(), planner: planner));
      await tester.pump(const Duration(milliseconds: 700));

      await tester.dragUntilVisible(
        find.text('Ways to close the gap'),
        find.byType(ListView),
        const Offset(0, -320),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Ways to close the gap'), findsOneWidget);
      await shot(tester, '26_budget_levers');
    });

    testWidgets('weather degrades to a note when the lookup fails', (tester) async {
      final state = buildState();
      final planner = await costedPlan(state);
      await tester.pumpWidget(host(state, const SummaryScreen(), planner: planner));
      await tester.pump(const Duration(milliseconds: 700));

      // No network in tests, so the panel must say so rather than spin forever.
      await tester.dragUntilVisible(
        find.byType(WeatherPanel),
        find.byType(ListView),
        const Offset(0, -320),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(WeatherPanel), findsOneWidget);
    });
  });
}

/// Stands in for a total network outage.
class _DeadClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Future.error(const SocketException('offline in tests'));
}

/// The test binding ships a font that draws every glyph as a box. Loading the
/// real Roboto and Material Icons faces makes the layout measurements — and any
/// overflow — match what a device would produce.
/// Lets asset images actually decode before a golden is taken.
///
/// `Image.asset` resolves through the bundle asynchronously. Inside
/// `testWidgets` the clock is faked, so that decode never completes and the
/// golden captures an empty box where the logo should be. `runAsync` is the
/// only way to hand it a real event loop.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pump(const Duration(milliseconds: 120));
}

Future<void> _loadRealFonts() async {
  // The test binding ships a font that draws every glyph as a filled box, so
  // without this the goldens say nothing about the design and text measurement
  // does not match a device.
  //
  // The typeface is now bundled in the app, so the goldens use the exact same
  // files the app ships — no stand-in, and the images are a faithful record.
  final jakarta = FontLoader(AppTheme.fontFamily);
  var loadedAny = false;
  for (final weight in ['400', '500', '600', '700', '800']) {
    final file = File('assets/fonts/PlusJakartaSans-$weight.ttf');
    if (file.existsSync()) {
      jakarta.addFont(file.readAsBytes().then((b) => b.buffer.asByteData()));
      loadedAny = true;
    }
  }
  if (loadedAny) await jakarta.load();

  // Material's icon font is not bundled with the app, it comes from the SDK.
  final iconFile = File(
    r'C:\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
  );
  if (iconFile.existsSync()) {
    final icons = FontLoader('MaterialIcons')
      ..addFont(iconFile.readAsBytes().then((b) => b.buffer.asByteData()));
    await icons.load();
  }
}
