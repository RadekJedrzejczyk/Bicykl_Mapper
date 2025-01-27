import 'package:universal_html/html.dart'
    as html; // Obsługa funkcji przeglądarki (np. pobieranie plików).

Future<void> saveToGpx_body(dynamic state) async {
  if (state.routePoints.isEmpty) {
    throw StateError(
        'Nie można wygenerować trasy. - Proszę dodać dwa punkty na mapie.');
  }

  // Tworzenie struktury XML GPX
  String gpxContent = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Flutter App">
  <trk>
    <name>Generated Route</name>
    <trkseg>
''';

  // Dodanie każdego punktu trasy do pliku GPX
  for (var point in state.routePoints) {
    gpxContent += '''
      <trkpt lat="${point.latitude}" lon="${point.longitude}">
        <ele>0.0</ele> <!-- Wysokość (możesz to dostosować jeśli masz dane o wysokości) -->
      </trkpt>
''';
  }

  // Zakończenie struktury GPX
  gpxContent += '''
    </trkseg>
  </trk>
</gpx>''';

  // Tworzenie pliku GPX do pobrania w przeglądarce
  final blob = html.Blob([gpxContent],
      'application/gpx+xml'); // Tworzenie obiektu zawierającego dane GPX.
  final url = html.Url.createObjectUrlFromBlob(
      blob); // Generowanie tymczasowego URL dla pliku.
  final anchor =
      html.AnchorElement(href: url) // Tworzenie elementu HTML do pobrania.
        ..target = 'blank' // Otwórz w nowej karcie.
        ..download = 'route.gpx' // Nazwa pliku do pobrania.
        ..click(); // Symulowanie kliknięcia (rozpoczęcie pobierania).
  html.Url.revokeObjectUrl(url); // Usunięcie URL po zakończeniu
}
