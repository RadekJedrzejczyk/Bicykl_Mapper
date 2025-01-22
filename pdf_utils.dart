import 'package:pdf/widgets.dart'
    as pw; // Biblioteka do tworzenia dokumentów PDF.
import 'package:intl/intl.dart'; // Umożliwia formatowanie dat i godzin.
import 'dart:html' as html;
import 'formating_utils.dart';
import 'dart:typed_data'; // uint
import 'package:flutter/material.dart';
import 'snapshot_utils.dart';

// Mapa do tłumaczenia nazw profili rowerowych na język polski
const Map<String, String> profileNameMap = {
  'cycling-regular': 'Rower standardowy',
  'cycling-electric': 'Rower elektryczny',
  'cycling-mountain': 'Rower górski',
  'cycling-road': 'Rower szosowy',
};

// Funkcja zamieniająca polskie znaki na ich odpowiedniki bez znaków diakrytycznych
String replacePolishCharacters(String text) {
  Map<String, String> polishToNonPolish = {
    'ą': 'a',
    'ć': 'c',
    'ę': 'e',
    'ł': 'l',
    'ń': 'n',
    'ó': 'o',
    'ś': 's',
    'ż': 'z',
    'ź': 'z',
    'Ą': 'A',
    'Ć': 'C',
    'Ę': 'E',
    'Ł': 'L',
    'Ń': 'N',
    'Ó': 'O',
    'Ś': 'S',
    'Ż': 'Z',
    'Ź': 'Z',
  };

  polishToNonPolish.forEach((key, value) {
    text = text.replaceAll(key, value);
  });
  return text;
}

// Funkcja generująca PDF z informacjami o trasie
Future<void> saveToPdf_body(dynamic state) async {
  if (state.routePoints.isEmpty) {
    ScaffoldMessenger.of(state.context).showSnackBar(
      const SnackBar(
          content: Text('Brak punktów trasy - plików nie wygenerowano')),
    ); // Wyświetlenie komunikatu o błędzie
    return;
  }

  final pdf = pw.Document();
  double? totalDistance = state.distance; // Całkowity dystans
  Uint8List? mapImage =
      await Snapshoter.snapshotTarget(state, state.flutterMap);

  // Wybór tłumaczenia nazwy profilu rowerowego
  String bikeProfile = profileNameMap[state.selectedProfile] ?? 'Brak danych';

  // Dodawanie treści do pliku PDF
  pdf.addPage(pw.Page(
    build: (pw.Context context) {
      return pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start, // Wyrównanie elementów do lewej
        children: [
          // 1. Informacje o trasie
          pw.Text(
            replacePolishCharacters(
                'Wygenerowana Trasa'), // Usunięcie polskich znaków
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10), // Odstęp
          pw.Text(
            replacePolishCharacters(
                'Data generowania: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
          ),
          pw.Text('Profil roweru: ${replacePolishCharacters(bikeProfile)}'),
          pw.SizedBox(height: 20),

          // 2. Szczegóły trasy
          pw.Text(
            replacePolishCharacters('Plan trasy:'), // Usunięcie polskich znaków
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),

          // Adres startowy
          if (state.addresses.isNotEmpty)
            pw.Text(replacePolishCharacters(
                'Adres startowy: ${state.addresses[0]}')),

          // Adresy przystanków
          if (state.stopAddresses.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            for (int i = 0; i < state.stopAddresses.length; i++)
              pw.Text(replacePolishCharacters(
                  'Adres Przystanku ${i + 1}: ${state.stopAddresses[i]}')),
          ],

          // Adres końcowy, jeśli dostępny
          if (state.routePoints.isNotEmpty && state.routePoints.length > 1)
            pw.Text(replacePolishCharacters(
                'Adres końcowy: ${state.addresses.last}')),
          pw.Text(
            replacePolishCharacters(
                'Dystans: ${totalDistance?.toStringAsFixed(2) ?? 'Brak danych'} km'),
          ),

          // Formatowanie czasu
          pw.Text(replacePolishCharacters(
              'Czas: ${minutesToHours(state.duration)}')),
          pw.SizedBox(height: 20),
          pw.Text(replacePolishCharacters('Mapa trasy:')),
          if (mapImage != null)
            pw.Image(pw.MemoryImage(mapImage), fit: pw.BoxFit.contain),
        ],
      );
    },
  ));

  // Zapisanie pliku PDF jako bajty
  final bytes = await pdf.save();

  // Tworzenie pliku w przeglądarce do pobrania
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..target = 'blank'
    ..download = 'route.pdf'
    ..click();
  html.Url.revokeObjectUrl(url); // Usunięcie URL po zakończeniu
}
