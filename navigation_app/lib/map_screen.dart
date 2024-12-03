import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:navigation_app/api.dart';
import 'dart:math';
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart'; 
import 'dart:html' as html;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';



class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<LatLng> points = [];
  
  LatLng? startPoint; // Punkt początkowy
  LatLng? endPoint;   // Punkt końcowy
  LatLng? stop1;      // Pierwszy przystanek
  LatLng? stop2;      // Drugi przystanek
  LatLng? stop3;      // Trzeci przystanek
  

  // Domyślny profil trasy (np. cycling-road)
  String selectedProfile = 'cycling-road';

  // Dostępne profile tras
  final Map<String, String> profiles = {
    'cycling-regular': 'Rower standardowy',
    'cycling-electric': 'Rower elektryczny',
    'cycling-mountain': 'Rower górski',
    'cycling-road': 'Rower szosowy',
  };

  double? distance; // Dystans w kilometrach
  double? duration; // Czas trwania trasy w minutach

  final MapController mapController = MapController();
  final TextEditingController startLatController = TextEditingController();
  final TextEditingController startLngController = TextEditingController();
  final TextEditingController endLatController = TextEditingController();
  final TextEditingController endLngController = TextEditingController();
  final TextEditingController loopDistanceController = TextEditingController();
  

  final TextEditingController stop1LatController = TextEditingController();
  final TextEditingController stop1LngController = TextEditingController();
  final TextEditingController stop2LatController = TextEditingController();
  final TextEditingController stop2LngController = TextEditingController();
  final TextEditingController stop3LatController = TextEditingController();
  final TextEditingController stop3LngController = TextEditingController();

Future<void> saveToPdf() async {
  final pdf = pw.Document();
  double? totalDistance = distance;  // Zmienna przechowująca całkowity dystans

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
          pw.Text('START: ${points[0].latitude}, ${points[0].longitude}'),
          // Lista przystanków, jeśli istnieją
          if (stop1 != null) 
            pw.Text('Przystanek 1: ${stop1!.latitude}, ${stop1!.longitude}'),
          if (stop2 != null) 
            pw.Text('Przystanek 2: ${stop2!.latitude}, ${stop2!.longitude}'),
          if (stop3 != null) 
            pw.Text('Przystanek 3: ${stop3!.latitude}, ${stop3!.longitude}'),

          // Punkt końcowy
          if (endPoint != null) 
            pw.Text('KONIEC: ${endPoint!.latitude}, ${endPoint!.longitude}'),

          pw.SizedBox(height: 20),
          pw.Text('Dystans: ${totalDistance?.toStringAsFixed(2) ?? 'Brak danych'} km'),
          pw.Text('Czas: ${formatDuration(duration ?? 0)}'),  // Formatowanie czasu
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



Future<void> saveToGpx() async {
  // Sprawdzenie, czy lista punktów trasy jest pusta
  if (points.isEmpty) {
    print("Brak punktów trasy");
    return;
  }

  // Tworzenie struktury XML GPX
  String gpxContent = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="Flutter App">
  <trk>
    <name>Generated Route</name>
    <trkseg>
      ${points.map((point) => '''
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







Future<void> generateRandomRoute(double loopDistance) async {
  if (startPoint == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Proszę wprowadzić punkt początkowy!')),
    );
    return;
  }

  // Ustalanie tolerancji błędu na podstawie dystansu pętli
  double tolerance;
  if (loopDistance < 50) {
    tolerance = 5.0; // Tolerancja 5 km
  } else if (loopDistance <= 100) {
    tolerance = 10.0; // Tolerancja 10 km
  } else {
    tolerance = 20.0; // Tolerancja 20 km
  }

  bool isWithinTolerance = false;

  while (!isWithinTolerance) {
    double radius = loopDistance / 2.5; // Promień pętli
    double angle = Random().nextDouble() * 360; // Losowy kąt
    double radian = angle * (pi / 180); // Konwersja na radiany

    double randomLat = startPoint!.latitude + radius * (1 / 111.32) * sin(radian);
    double randomLng = startPoint!.longitude + radius * (1 / 85.0) * cos(radian);
    LatLng randomPoint = LatLng(randomLat, randomLng);

    double midLat = (startPoint!.latitude + randomPoint.latitude) / 2;
    double midLng = (startPoint!.longitude + randomPoint.longitude) / 2;
    LatLng midpoint = LatLng(midLat, midLng);

    points.clear(); // Czyszczenie poprzedniej trasy

    double totalDistance = 0.0;
    double totalDuration = 0.0;

    try {
      // Trasa 1: Początkowy -> Losowy
      var segment1 = await getCoordinatesForRouteWithDetails(startPoint!, randomPoint);
      totalDistance += segment1['distance'] ?? 0.0;
      totalDuration += segment1['duration'] ?? 0.0;

      // Trasa 2: Losowy -> Średni
      var segment2 = await getCoordinatesForRouteWithDetails(randomPoint, midpoint);
      totalDistance += segment2['distance'] ?? 0.0;
      totalDuration += segment2['duration'] ?? 0.0;

      // Trasa 3: Średni -> Początkowy
      var segment3 = await getCoordinatesForRouteWithDetails(midpoint, startPoint!);
      totalDistance += segment3['distance'] ?? 0.0;
      totalDuration += segment3['duration'] ?? 0.0;

      // Sprawdzanie, czy dystans mieści się w tolerancji
      if ((totalDistance - loopDistance).abs() <= tolerance) {
        isWithinTolerance = true;

        // Aktualizowanie stanu tylko, gdy pętla jest akceptowalna
        setState(() {
          distance = totalDistance;
          duration = totalDuration;

          if (points.isNotEmpty) {
            var bounds = LatLngBounds.fromPoints(points);
            var center = bounds.center;

            // Ustawienie widoku mapy
            mapController.move(center, 10.0); // Dostosuj zoom do swoich potrzeb
          }
        });
      }
    } catch (e) {
      // Obsługa błędów API
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wystąpił problem z generowaniem trasy. Próbuję ponownie...')),
      );
    }
  }
}





// Funkcja pomocnicza do wywołania API i zebrania szczegółów trasy
Future<Map<String, double>> getCoordinatesForRouteWithDetails(LatLng start, LatLng end) async {
  String startStr = '${start.longitude},${start.latitude}';
  String endStr = '${end.longitude},${end.latitude}';

  var response = await http.get(Uri.parse(getRouteUrl(selectedProfile, startStr, endStr).toString()));

  if (response.statusCode == 200) {
    var data = jsonDecode(response.body);

    // Wyciąganie współrzędnych
    var listOfPoints = data['features'][0]['geometry']['coordinates'] as List<dynamic>;
    points.addAll(listOfPoints.map((e) => LatLng(e[1].toDouble(), e[0].toDouble())).toList());

    // Wyciąganie dystansu i czasu
    double distance = data['features'][0]['properties']['segments'][0]['distance'] / 1000;
    double duration = data['features'][0]['properties']['segments'][0]['duration'] / 60;

    return {'distance': distance, 'duration': duration};
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nie udało się pobrać trasy. Spróbuj ponownie.')),
    );
    return {'distance': 0.0, 'duration': 0.0};
  }
}

  // Funkcja do pobrania trasy uwzględniającej przystanki
Future<void> getCoordinates() async {
  if (startPoint == null || endPoint == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Proszę wprowadzić poprawne współrzędne!')),
    );
    return;
  }

  List<LatLng> routePoints = [startPoint!];
  if (stop1 != null) routePoints.add(stop1!);
  if (stop2 != null) routePoints.add(stop2!);
  if (stop3 != null) routePoints.add(stop3!);
  routePoints.add(endPoint!);

  points.clear(); // Czyścimy poprzednie punkty
  double totalDistance = 0.0;
  double totalDuration = 0.0;

  try {
    for (int i = 0; i < routePoints.length - 1; i++) {
      var start = routePoints[i];
      var end = routePoints[i + 1];
      
      String startStr = '${start.longitude},${start.latitude}';
      String endStr = '${end.longitude},${end.latitude}';
      var response = await http.get(Uri.parse(getRouteUrl(selectedProfile, startStr, endStr).toString()));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);

        // Wyciągnięcie współrzędnych segmentu trasy
        var listOfPoints = data['features'][0]['geometry']['coordinates'] as List<dynamic>;
        points.addAll(listOfPoints.map((e) => LatLng(e[1].toDouble(), e[0].toDouble())));

        // Sumowanie dystansu i czasu trwania segmentów
        totalDistance += data['features'][0]['properties']['segments'][0]['distance'] / 1000;
        totalDuration += data['features'][0]['properties']['segments'][0]['duration'] / 60;
      } else {
        throw Exception('Nie udało się pobrać trasy dla segmentu ${i + 1}');
      }
    }

    setState(() {
      distance = totalDistance;
      duration = totalDuration;

      // Dopasowanie widoku mapy do trasy
      if (points.isNotEmpty) {
        var bounds = LatLngBounds.fromPoints(points);
        var center = bounds.center;
        var zoom = 6.0; // Zwiększamy zoom po wyznaczeniu trasy, aby był bardziej szczegółowy
        mapController.move(center, zoom);

      }
    });
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wystąpił problem z generowaniem trasy. Spróbuj ponownie.')),
    );
  }
}


  // Funkcja do czyszczenia trasy
  void clearRoute() {
    setState(() {
      points.clear();
      startPoint = null;
      endPoint = null;
      stop1 = null;
      stop2 = null;
      stop3 = null;
      distance = null;
      duration = null;
    });
  }

Future<void> showCoordinatesDialog(LatLng? point, String title) async {
    final TextEditingController latController = TextEditingController();
    final TextEditingController lngController = TextEditingController();

    if (point != null) {
      latController.text = point.latitude.toString();
      lngController.text = point.longitude.toString();
    }

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: latController,
                decoration: const InputDecoration(labelText: 'Szerokość geograficzna (lat)'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: lngController,
                decoration: const InputDecoration(labelText: 'Długość geograficzna (lng)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Anuluj'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  final lat = double.tryParse(latController.text) ?? 0;
                  final lng = double.tryParse(lngController.text) ?? 0;

                  if (title == "Punkt początkowy") {
                    startPoint = LatLng(lat, lng);
                  } else if (title == "Punkt końcowy") {
                    endPoint = LatLng(lat, lng);
                  } else if (title == "Przystanek 1") {
                    stop1 = LatLng(lat, lng);
                  } else if (title == "Przystanek 2") {
                    stop2 = LatLng(lat, lng);
                  } else if (title == "Przystanek 3") {
                    stop3 = LatLng(lat, lng);
                  }
                });
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String formatDuration(double durationInMinutes) {
    int hours = durationInMinutes ~/ 60;
    int minutes = (durationInMinutes % 60).toInt();
    if (hours > 0) {
      return '$hours godz. $minutes min';
    } else {
      return '$minutes min';
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bicycle Navigation', textAlign: TextAlign.center),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Padding(
  padding: const EdgeInsets.all(8.0),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      // Punkt początkowy
      GestureDetector(
        onTap: () {
          showCoordinatesDialog(startPoint, 'Punkt początkowy');
        },
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          color: Colors.green,
          child: SizedBox(
            width: 100,
            height: 50,
            child: Center(
              child: Text(
                startPoint == null ? 'Start' : 'Zmieniony\nStart',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10), // Odstęp między kafelkami
      // Punkt końcowy
      GestureDetector(
        onTap: () {
          showCoordinatesDialog(endPoint, 'Punkt końcowy');
        },
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          color: Colors.red,
          child: SizedBox(
            width: 100,
            height: 50,
            child: Center(
              child: Text(
                endPoint == null ? 'Koniec' : 'Zmieniony\nKoniec',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    ],
  ),
),
Padding(
  padding: const EdgeInsets.all(8.0),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      // Przystanek 1
      GestureDetector(
        onTap: () {
          showCoordinatesDialog(stop1, 'Przystanek 1');
        },
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.grey), // Obwódka
          ),
          color: Colors.white,
          child: SizedBox(
            width: 90,
            height: 40,
            child: Center(
              child: Text(
                stop1 == null ? 'Przystanek 1' : 'Zm. Przyst. 1',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 5),
      // Przystanek 2
      GestureDetector(
        onTap: () {
          showCoordinatesDialog(stop2, 'Przystanek 2');
        },
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.grey), // Obwódka
          ),
          color: Colors.white,
          child: SizedBox(
            width: 90,
            height: 40,
            child: Center(
              child: Text(
                stop2 == null ? 'Przystanek 2' : 'Zm. Przyst. 2',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 5),
      // Przystanek 3
      GestureDetector(
        onTap: () {
          showCoordinatesDialog(stop3, 'Przystanek 3');
        },
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.grey), // Obwódka
          ),
          color: Colors.white,
          child: SizedBox(
            width: 90,
            height: 40,
            child: Center(
              child: Text(
                stop3 == null ? 'Przystanek 3' : 'Zm. Przyst. 3',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    ],
  ),
),




          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButtonFormField<String>(
              value: selectedProfile,
              onChanged: (value) => setState(() => selectedProfile = value!),
              items: profiles.entries.map((e) {
                return DropdownMenuItem(value: e.key, child: Text(e.value));
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: getCoordinates,
                  child: const Text('Generuj trasę'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    double loopDistance = double.tryParse(loopDistanceController.text) ?? 0;
                    if (loopDistance > 0) {
                      await generateRandomRoute(loopDistance);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Wprowadź poprawny dystans dla pętli!')),
                      );
                    }
                  },
                  child: const Text('Generuj pętlę'),
                ),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: loopDistanceController,
                    decoration: const InputDecoration(labelText: 'Dystans pętli (km)'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ),

          // Mapa
          Expanded(
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: LatLng(50.292961, 18.668930),
                initialZoom: 9.2,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: 'dev.fleaflet.flutter_map.example',
                ),
                MarkerLayer(
              markers: [
                if (startPoint != null)
                  Marker(
                    point: startPoint!,
                    width: 80,
                    height: 80,
                    child: const Icon(Icons.location_on, color: Colors.green, size: 45),
                  ),
                if (endPoint != null)
                  Marker(
                    point: endPoint!,
                    width: 80,
                    height: 80,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 45),
                  ),
                if (stop1 != null)
                  Marker(
                    point: stop1!,
                    width: 80,
                    height: 80,
                    child: const Icon(Icons.location_on, color: Colors.orange, size: 45),
                  ),
                if (stop2 != null)
                  Marker(
                    point: stop2!,
                    width: 80,
                    height: 80,
                    child: const Icon(Icons.location_on, color: Colors.blue, size: 45),
                  ),
                if (stop3 != null)
                  Marker(
                    point: stop3!,
                    width: 80,
                    height: 80,
                    child: const Icon(Icons.location_on, color: Colors.purple, size: 45),
                  ),
              ],
            ),
            // Add PolylineLayer here
      if (points.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        strokeWidth: 4.0,
                        color: Colors.blue,
                      ),
                    ],
                  ),



              ],
            ),
          ), 

          // Fragment dolnego kontenera z przyciskiem "Zakończ trasę"
Container(
  color: Colors.grey[200], // Tło kontenera
  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10), // Mniejsze odstępy
  child: Row( // Zmieniono Column na Row dla bardziej kompaktowego układu
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      if (distance != null && duration != null) 
        Expanded(
          child: Text(
            'Dystans: ${distance!.toStringAsFixed(2)} km, Czas: ${formatDuration(duration!)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            textAlign: TextAlign.left,
          ),
        ),
      ElevatedButton(
        onPressed: clearRoute,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          minimumSize: const Size(90, 40), // Zmniejszono rozmiar przycisku
        ),
        child: const Text('Zakończ trasę', style: TextStyle(color: Colors.white)),
      ),
      ElevatedButton(
  onPressed: () async {
    await saveToGpx();
    await saveToPdf();
  },
  child: const Text('Eksportuj do GPX i PDF'),
),

    ],
  ),
),

        ],
      ),
    );
  }
}