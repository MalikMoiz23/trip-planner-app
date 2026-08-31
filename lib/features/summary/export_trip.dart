import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:trip_planner/data/models/expense_breakdown.dart';
import 'package:trip_planner/data/models/itinerary.dart';
import 'package:trip_planner/data/models/trip_config.dart';
import 'package:trip_planner/domain/packing_builder.dart';
import 'package:trip_planner/features/summary/trip_pdf.dart';

/// What happened when someone asked for a PDF, in terms the UI can report.
enum ExportOutcome { shared, failed }

class ExportResult {
  const ExportResult(this.outcome, {this.message});

  final ExportOutcome outcome;

  /// Set on failure, phrased for a person rather than a log.
  final String? message;

  bool get ok => outcome == ExportOutcome.shared;
}

/// Builds the PDF, writes it somewhere the system can read, and opens the share
/// sheet so it can go to WhatsApp, Drive, email or the Files app.
///
/// The file goes to the app's temporary directory rather than Downloads: that
/// needs no storage permission on any Android version, and the share sheet is
/// what actually decides where a copy ends up. The OS clears temporary files on
/// its own schedule, which is right for something already delivered elsewhere.
Future<ExportResult> exportTripAsPdf({
  required TripConfig config,
  required ExpenseBreakdown breakdown,
  required List<ItineraryDay> itinerary,
  List<PackSection> packing = const [],
}) async {
  try {
    final bytes = await TripPdf.build(
      config: config,
      breakdown: breakdown,
      itinerary: itinerary,
      packing: packing,
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${TripPdf.fileName(config)}');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        // Some targets ignore files and take only text, so the subject line
        // carries enough to be useful on its own.
        subject: 'Trip to ${config.destination.name} — '
            '${config.days} days, ${config.persons} travellers',
      ),
    );

    return const ExportResult(ExportOutcome.shared);
  } on Exception catch (e) {
    return ExportResult(
      ExportOutcome.failed,
      message: 'The PDF could not be created. $e',
    );
  }
}
