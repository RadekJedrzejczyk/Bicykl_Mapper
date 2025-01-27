import 'package:pdf/widgets.dart'
    as pw; // Biblioteka do tworzenia dokumentów PDF.
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import 'formating_utils.dart';
import 'dart:typed_data'; // uint
import 'snapshot_utils.dart';
import 'package:printing/printing.dart';

// Funkcja generująca PDF z informacjami o trasie
Future<void> saveToPdf_body(dynamic state) async {
  if (state.routePoints.isEmpty) {
    throw StateError('Brak trasy - nie wygenerowano pliku pdf');
  }

  final font = await PdfGoogleFonts.notoSansRegular();
  pw.TextStyle defaultStyle = pw.TextStyle(font: font);

  final pdf = pw.Document();
  double? totalDistance = state.distance; // Całkowity dystans
  state.setState(() {
    state.fitMapCamera();
  });
  Uint8List? mapImage =
      await Snapshoter.snapshotTarget(state, state.flutterMap);

  // Wybór tłumaczenia nazwy profilu rowerowego
  String bikeProfile = state.selectedProfile ?? 'Brak danych';

  // Dodawanie treści do pliku PDF
  pdf.addPage(pw.Page(
    build: (pw.Context context) {
      return pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start, // Wyrównanie elementów do lewej
        children: [
          // 1. Informacje o trasie
          pw.Text(
            'Wygenerowana Trasa', // Usunięcie polskich znaków
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10), // Odstęp
          pw.Text(
            'Data generowania: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
          ),
          pw.Text('Profil roweru: ${bikeProfile}', style: defaultStyle),
          pw.SizedBox(height: 20),

          // 2. Szczegóły trasy
          pw.Text('Plan trasy:', // Usunięcie polskich znaków
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),

          // Adres startowy
          if (state.addresses.isNotEmpty)
            pw.Text('Adres startowy: ${state.addresses[0]}',
                style: defaultStyle),

          // Adresy przystanków
          if (state.stopAddresses.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            for (int i = 0; i < state.stopAddresses.length; i++)
              pw.Text('Adres Przystanku ${i + 1}: ${state.stopAddresses[i]}',
                  style: defaultStyle),
          ],

          // Adres końcowy, jeśli dostępny
          if (state.routePoints.isNotEmpty && state.routePoints.length > 1)
            pw.Text('Adres końcowy: ${state.addresses.last}',
                style: defaultStyle),
          pw.Text(
            'Dystans: ${totalDistance?.toStringAsFixed(2) ?? 'Brak danych'} km',
          ),

          // Formatowanie czasu
          pw.Text('Czas: ${minutesToHours(state.duration)}'),
          pw.SizedBox(height: 20),
          pw.Text('Mapa trasy:'),

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
