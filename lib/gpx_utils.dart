import 'dart:html' as html; // Obsługa funkcji przeglądarki (np. pobieranie plików).
import 'package:flutter/material.dart';

Future<void> saveToGpx_body(dynamic state) async {
   if (state.points.isEmpty) {
    ScaffoldMessenger.of(state.context).showSnackBar(
      const SnackBar(content: Text('Brak punktów trasy - plików nie wygenerowanoe')),
    );  // Wyświetlenie komunikatu o błędzie.
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
  final blob = html.Blob([gpxContent], 'application/gpx+xml'); // Tworzenie obiektu zawierającego dane GPX.
  final url = html.Url.createObjectUrlFromBlob(blob); // Generowanie tymczasowego URL dla pliku.
  final anchor = html.AnchorElement(href: url)  // Tworzenie elementu HTML do pobrania.
    ..target = 'blank'// Otwórz w nowej karcie.
    ..download = 'route.gpx' // Nazwa pliku do pobrania.
    ..click(); // Symulowanie kliknięcia (rozpoczęcie pobierania).
  html.Url.revokeObjectUrl(url); // Usunięcie URL po zakończeniu
}
