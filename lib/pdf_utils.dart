//import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
//import 'package:pdf/pdf.dart';
//import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'dart:html' as html; 

Future<void> saveToPdf_body(dynamic state) async {
  final pdf = pw.Document();
  double? totalDistance = state.distance;  // Zmienna przechowująca całkowity dystans

  // Dodawanie treści do pliku PDF
  pdf.addPage(pw.Page(
    build: (pw.Context context) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // 1. Informacje o trasie
          pw.Text(
            'Wygenerowana Trasa Rowery',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Data generowania: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
          ),
          pw.Text('Profil trasy: Rower szosowy'),
          pw.SizedBox(height: 20),

          // 2. Szczegóły trasy
          pw.Text(
            'Plan trasy:',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),

          // Lista punktów
          pw.Text('START: ${state.points[0].latitude}, ${state.points[0].longitude}'),
          // Lista przystanków, jeśli istnieją
          if (state.stop1 != null) 
            pw.Text('Przystanek 1: ${state.stop1!.latitude}, $state.{stop1!.longitude}'),
          if (state.stop2 != null) 
            pw.Text('Przystanek 2: ${state.stop2!.latitude}, ${state.stop2!.longitude}'),
          if (state.stop3 != null) 
            pw.Text('Przystanek 3: ${state.stop3!.latitude}, ${state.stop3!.longitude}'),

          // Punkt końcowy
          if (state.endPoint != null) 
            pw.Text('KONIEC: ${state.endPoint!.latitude}, ${state.endPoint!.longitude}'),

          pw.SizedBox(height: 20),
          pw.Text('Dystans: ${totalDistance?.toStringAsFixed(2) ?? 'Brak danych'} km'),
          pw.Text('Czas: ${state.formatDuration(state.duration ?? 0)}'),  // Formatowanie czasu
          pw.SizedBox(height: 20),

          // 3. Mapa trasy - zrezygnowano z dodawania mapy
          // Jeśli chcesz dodać mapę, musisz wygenerować obrazek mapy i umieścić go w tym miejscu
          // pw.Text('Mapa trasy', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          // pw.SizedBox(height: 10),
          // Tutaj możesz dodać kod wstawiający obrazek mapy, jeśli go posiadasz

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

