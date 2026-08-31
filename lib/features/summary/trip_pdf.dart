import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:trip_planner/core/constants.dart';
import 'package:trip_planner/core/formatters.dart';
import 'package:trip_planner/data/models/expense_breakdown.dart';
import 'package:trip_planner/data/models/itinerary.dart';
import 'package:trip_planner/data/models/trip_config.dart';
import 'package:trip_planner/domain/packing_builder.dart';

/// Renders a planned trip as a PDF you can send to the people coming with you.
///
/// Everything is laid out from the same figures the summary screen shows, and
/// the arithmetic strings come along with them — a costing nobody can check is
/// a costing nobody should act on, and that is doubly true once it has left the
/// app and is being argued over in a group chat.
///
/// Pure: it takes values and returns bytes. Saving and sharing is the caller's
/// business, which is what lets a test assert on a real document without
/// touching the filesystem.
class TripPdf {
  const TripPdf._();

  /// Brand green, matching the app.
  static const PdfColor _brand = PdfColor.fromInt(0xFF0F6E5C);
  static const PdfColor _brandDark = PdfColor.fromInt(0xFF0A4C40);
  static const PdfColor _ink = PdfColor.fromInt(0xFF0E1A24);
  static const PdfColor _inkSoft = PdfColor.fromInt(0xFF5A6B78);
  static const PdfColor _line = PdfColor.fromInt(0xFFE3E9EE);
  static const PdfColor _surfaceAlt = PdfColor.fromInt(0xFFF2F5F7);

  static Future<Uint8List> build({
    required TripConfig config,
    required ExpenseBreakdown breakdown,
    required List<ItineraryDay> itinerary,
    List<PackSection> packing = const [],
    DateTime? generatedAt,
  }) async {
    // The same faces the app ships, so the document looks like the product
    // rather than like a default PDF. Embedding also sidesteps the standard
    // PDF fonts, which have no glyph for the characters used throughout —
    // ÷, × and the en dash all appear in the arithmetic strings.
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans-400.ttf'));
    final semi = pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans-600.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/PlusJakartaSans-800.ttf'));

    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/brand/mark.png')).buffer.asUint8List(),
    );

    final doc = pw.Document(
      title: 'Triplyst — ${config.destination.name}',
      author: 'Triplyst',
      subject: 'Trip plan and costing',
    );

    final theme = pw.ThemeData.withFont(base: regular, bold: bold).copyWith(
      defaultTextStyle: pw.TextStyle(font: regular, fontSize: 9.5, color: _ink),
    );

    final when = generatedAt ?? DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          margin: const pw.EdgeInsets.fromLTRB(36, 34, 36, 40),
        ),
        header: (context) =>
            context.pageNumber == 1 ? pw.SizedBox() : _runningHeader(config, semi),
        footer: (context) => _footer(context, when, regular),
        build: (context) => [
          _hero(config, breakdown, logo, bold, semi, regular),
          pw.SizedBox(height: 18),
          _headline(breakdown, bold, semi, regular),
          pw.SizedBox(height: 18),
          _route(config, breakdown, semi, regular),
          pw.SizedBox(height: 18),
          _costTable(breakdown, semi, regular, bold),
          pw.SizedBox(height: 18),
          _assumptions(config, breakdown, semi, regular),
          if (itinerary.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _itinerary(itinerary, semi, regular),
          ],
          if (packing.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _packing(packing, semi, regular),
          ],
          if (breakdown.warnings.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _warnings(breakdown, semi, regular),
          ],
          pw.SizedBox(height: 16),
          _disclaimer(regular),
        ],
      ),
    );

    return doc.save();
  }

  /// A sensible name for the file in a downloads folder.
  static String fileName(TripConfig config) {
    final place = config.destination.name
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final d = config.startDate;
    final stamp = '${d.year}-${_two(d.month)}-${_two(d.day)}';
    return 'Triplyst-$place-$stamp.pdf';
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  // -------------------------------------------------------------------------

  static pw.Widget _hero(
    TripConfig config,
    ExpenseBreakdown b,
    pw.MemoryImage logo,
    pw.Font bold,
    pw.Font semi,
    pw.Font regular,
  ) {
    final route = config.stops.map((s) => s.destination.name).join('  →  ');

    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: const pw.BoxDecoration(
        gradient: pw.LinearGradient(
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
          colors: [_brandDark, _brand],
        ),
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 42,
            height: 42,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(9)),
            ),
            padding: const pw.EdgeInsets.all(2),
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Triplyst',
                    style: pw.TextStyle(font: bold, fontSize: 15, color: PdfColors.white)),
                pw.SizedBox(height: 2),
                pw.Text(
                  route,
                  style: pw.TextStyle(font: bold, fontSize: 20, color: PdfColors.white),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  '${fullDate(config.startDate)} – ${fullDate(config.endDate)}   ·   '
                  '${plural(config.days, 'day', 'days')}   ·   '
                  '${plural(config.persons, 'traveller', 'travellers')}   ·   '
                  'from ${config.originName}',
                  style: pw.TextStyle(
                    font: regular,
                    fontSize: 9.5,
                    color: PdfColor.fromInt(0xCCFFFFFF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _headline(ExpenseBreakdown b, pw.Font bold, pw.Font semi, pw.Font regular) {
    pw.Widget cell(String label, String value, {bool lead = false}) => pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: lead ? _brand : _surfaceAlt,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  label.toUpperCase(),
                  style: pw.TextStyle(
                    font: semi,
                    fontSize: 7,
                    letterSpacing: 0.8,
                    color: lead ? PdfColor.fromInt(0xCCFFFFFF) : _inkSoft,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: lead ? 17 : 13,
                    color: lead ? PdfColors.white : _ink,
                  ),
                ),
              ],
            ),
          ),
        );

    return pw.Row(
      children: [
        cell('Total for the trip', money(b.total), lead: true),
        pw.SizedBox(width: 8),
        cell('Per person', money(b.perPerson)),
        pw.SizedBox(width: 8),
        cell('Per day', money(b.perDay)),
        pw.SizedBox(width: 8),
        cell('Each, per day', money(b.perPersonPerDay)),
      ],
    );
  }

  static pw.Widget _route(
    TripConfig config,
    ExpenseBreakdown b,
    pw.Font semi,
    pw.Font regular,
  ) {
    final names = [
      config.originName,
      for (final s in config.stops) s.destination.name,
      config.originName,
    ];

    return _section(
      'The route',
      semi,
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < b.legKms.length && i + 1 < names.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text('${names[i]}  →  ${names[i + 1]}',
                        style: pw.TextStyle(font: regular, fontSize: 9.5)),
                  ),
                  pw.Text(km(b.legKms[i]),
                      style: pw.TextStyle(font: semi, fontSize: 9.5)),
                ],
              ),
            ),
          pw.Divider(color: _line, height: 12),
          _kv('Driving in total', '${km(b.travelKm)}  ·  ${durationText(b.totalDriveTime)}',
              semi, regular),
          if (b.attractionsKm > 0)
            _kv('Day trips from your bases', km(b.attractionsKm), semi, regular),
          _kv('Distance all in', km(b.totalKm), semi, regular),
          if (config.isSelfDriving)
            _kv('Fuel',
                '${litres(b.litres)} at ${moneyExact(config.fuelPrice)}/L  ·  '
                    '${money(b.costPerKm)} per km',
                semi, regular),
          if (b.routeEstimated)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                'At least one leg could not be routed, so its distance is a '
                'terrain-corrected straight line rather than a measured road.',
                style: pw.TextStyle(font: regular, fontSize: 8, color: _inkSoft),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _costTable(
    ExpenseBreakdown b,
    pw.Font semi,
    pw.Font regular,
    pw.Font bold,
  ) {
    final rows = b.lines.where((l) => l.amount > 0).toList()
      ..sort((a, c) => c.amount.compareTo(a.amount));

    return _section(
      'Where the money goes',
      semi,
      pw.Table(
        columnWidths: const {
          0: pw.FlexColumnWidth(2.6),
          1: pw.FlexColumnWidth(5.4),
          2: pw.FlexColumnWidth(1.6),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _surfaceAlt),
            children: [
              _th('Category', semi),
              _th('How it was worked out', semi),
              _th('Amount', semi, right: true),
            ],
          ),
          for (final line in rows)
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _line)),
              ),
              children: [
                _td(line.label, semi),
                _td(line.detail, regular, soft: true),
                _td(money(line.amount), semi, right: true),
              ],
            ),
          pw.TableRow(
            children: [
              _td('Total', bold),
              _td('', regular),
              _td(money(b.total), bold, right: true),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _assumptions(
    TripConfig config,
    ExpenseBreakdown b,
    pw.Font semi,
    pw.Font regular,
  ) {
    final vehicle = AppDefaults.vehicleById(config.vehicleId);
    return _section(
      'What this assumes',
      semi,
      pw.Column(children: [
        _kv('Travelling by',
            config.isSelfDriving
                ? '${vehicle.label} · ${config.mileage.toStringAsFixed(1)} km/L · '
                    '${config.fuel.label}'
                : 'Public transport',
            semi, regular),
        _kv('Sleeping in',
            '${config.stayStyle.label} · ${plural(b.rooms, b.unitLabel, '${b.unitLabel}s')} · '
                '${plural(b.nights, 'night', 'nights')}',
            semi, regular),
        _kv('Eating',
            '${config.foodStyle.label} · '
                '${config.mealPlan.countBySlot().entries.map((e) => '${e.value}× '
                    '${e.key.label.toLowerCase()} at '
                    '${money(config.mealPlan.priceOf(e.key))}').join(' · ')}',
            semi, regular),
        _kv('Contingency', '${config.bufferPercent.toStringAsFixed(0)}% on top', semi, regular),
        if (config.selectedAttractions.isNotEmpty)
          _kv('Stops chosen',
              config.selectedAttractions.map((a) => a.name).join(', '), semi, regular),
      ]),
    );
  }

  static pw.Widget _itinerary(List<ItineraryDay> days, pw.Font semi, pw.Font regular) {
    return _section(
      'Day by day',
      semi,
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final day in days)
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.only(left: 10),
              decoration: const pw.BoxDecoration(
                border: pw.Border(left: pw.BorderSide(color: _brand, width: 2)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Day ${day.dayNumber}  ·  ${dayMonth(day.date)}  ·  ${day.title}',
                    style: pw.TextStyle(font: semi, fontSize: 10, color: _brand),
                  ),
                  pw.SizedBox(height: 3),
                  for (final item in day.items)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('•  ', style: pw.TextStyle(font: regular, fontSize: 9)),
                          pw.Expanded(
                            child: pw.RichText(
                              text: pw.TextSpan(children: [
                                pw.TextSpan(
                                  text: item.title,
                                  style: pw.TextStyle(font: semi, fontSize: 9),
                                ),
                                pw.TextSpan(
                                  text: '   ${item.subtitle}',
                                  style: pw.TextStyle(
                                      font: regular, fontSize: 8.5, color: _inkSoft),
                                ),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _packing(List<PackSection> sections, pw.Font semi, pw.Font regular) {
    return _section(
      'What to take',
      semi,
      pw.Wrap(
        spacing: 18,
        runSpacing: 10,
        children: [
          for (final section in sections)
            pw.Container(
              width: 155,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(section.title,
                      style: pw.TextStyle(font: semi, fontSize: 9, color: _brand)),
                  pw.SizedBox(height: 2),
                  for (final item in section.items)
                    pw.Text('☐  ${item.label}',
                        style: pw.TextStyle(font: regular, fontSize: 8.5)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _warnings(ExpenseBreakdown b, pw.Font semi, pw.Font regular) {
    return _section(
      'Worth knowing before you go',
      semi,
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final w in b.warnings)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(w.title, style: pw.TextStyle(font: semi, fontSize: 9)),
                  pw.Text(w.detail,
                      style: pw.TextStyle(font: regular, fontSize: 8.5, color: _inkSoft)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _disclaimer(pw.Font regular) => pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: const pw.BoxDecoration(
          color: _surfaceAlt,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Text(
          'Every price here is an editable estimate, not a live rate. Fuel, hotel, food '
          'and ticket figures start from typical values and were adjusted in the app; '
          'nothing is fetched from a booking service. Distances come from '
          'OpenStreetMap and OSRM. Confirm the fuel price and any booking before '
          'committing money to this plan.',
          style: pw.TextStyle(font: regular, fontSize: 8, color: _inkSoft),
        ),
      );

  // ---- small pieces --------------------------------------------------------

  static pw.Widget _section(String title, pw.Font semi, pw.Widget child) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(font: semi, fontSize: 12, color: _ink)),
          pw.SizedBox(height: 7),
          child,
        ],
      );

  static pw.Widget _kv(String k, String v, pw.Font semi, pw.Font regular) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2.5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 130,
              child: pw.Text(k, style: pw.TextStyle(font: regular, fontSize: 9, color: _inkSoft)),
            ),
            pw.Expanded(child: pw.Text(v, style: pw.TextStyle(font: semi, fontSize: 9))),
          ],
        ),
      );

  static pw.Widget _th(String text, pw.Font semi, {bool right = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(
          text.toUpperCase(),
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(font: semi, fontSize: 7, letterSpacing: 0.7, color: _inkSoft),
        ),
      );

  static pw.Widget _td(String text, pw.Font font, {bool right = false, bool soft = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(
          text,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(font: font, fontSize: 8.5, color: soft ? _inkSoft : _ink),
        ),
      );

  static pw.Widget _runningHeader(TripConfig config, pw.Font semi) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _line)),
        ),
        child: pw.Text(
          'Triplyst  ·  ${config.destination.name}',
          style: pw.TextStyle(font: semi, fontSize: 8, color: _inkSoft),
        ),
      );

  static pw.Widget _footer(pw.Context context, DateTime when, pw.Font regular) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Planned with Triplyst on ${fullDate(when)}',
                style: pw.TextStyle(font: regular, fontSize: 7.5, color: _inkSoft)),
            pw.Text('${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(font: regular, fontSize: 7.5, color: _inkSoft)),
          ],
        ),
      );
}
