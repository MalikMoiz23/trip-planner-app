import 'package:url_launcher/url_launcher.dart';

/// Handing an emergency off to the phone's own apps.
///
/// Everything here returns false rather than throwing. A dialler that will not
/// open is a problem to tell the user about calmly, with the number still on
/// screen to type by hand — not an exception thrown at someone who is already
/// having a bad day.
class Launch {
  const Launch._();

  /// Opens the dialler with the number filled in. Deliberately not `tel:` with
  /// an auto-dial: the person presses the green button, so a pocket tap never
  /// calls Rescue 1122.
  static Future<bool> dial(String number) =>
      _open(Uri(scheme: 'tel', path: number));

  /// Opens a coordinate in whatever maps app is installed.
  ///
  /// `geo:` is the Android standard and lets the user pick their app. The
  /// `?q=lat,lng(label)` form drops a labelled pin rather than merely centring
  /// the view, which matters when the pin is the petrol pump you are trying to
  /// reach. Falls back to a Google Maps web link where `geo:` is unhandled.
  static Future<bool> map(double lat, double lng, {String? label}) async {
    final coords = '$lat,$lng';
    final tag = label == null ? '' : '($label)';
    if (await _open(Uri.parse('geo:$coords?q=$coords$tag'))) return true;
    return _open(Uri.parse('https://www.google.com/maps/search/?api=1&query=$coords'));
  }

  /// Opens the SMS composer with the message ready to send.
  ///
  /// Used to pass on a position: a text needs far less signal than a call and
  /// keeps retrying on its own until one bar appears.
  static Future<bool> sms(String body, {String? to}) => _open(
        Uri(scheme: 'sms', path: to ?? '', queryParameters: {'body': body}),
      );

  static Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }
}
