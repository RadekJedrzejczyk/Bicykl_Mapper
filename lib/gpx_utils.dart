import 'dart:html' as html; 

Future<void> saveToGpx_body(dynamic state) async {
  if (state.points.isEmpty) {
    print("Brak punktów trasy");
    return;
  }

  // Tworzenie struktury XML GPX
  String gpxContent = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Flutter App">
  <trk>
    <name>Generated Route</name>
    <trkseg>
Future<void> saveToGpx(dynamic state) async {
      ${state.points.map((point) => '''
      <trkpt lat="${point.latitude}" lon="${point.longitude}">
        <ele>0.0</ele> <!-- Wysokość (możesz to dostosować jeśli masz dane o wysokości) -->
      </trkpt>''').join('\n')}
    </trkseg>
  </trk>
</gpx>''';

  // Tworzenie pliku GPX do pobrania w przeglądarce
  final blob = html.Blob([gpxContent], 'application/gpx+xml');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..target = 'blank'
    ..download = 'route.gpx'
    ..click();
  html.Url.revokeObjectUrl(url); // Usunięcie URL po zakończeniu
}
