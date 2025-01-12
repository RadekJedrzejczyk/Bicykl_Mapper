import 'package:flutter/material.dart'; // Główna biblioteka do tworzenia aplikacji Flutter.
import 'package:flutter_map/flutter_map.dart'; // Biblioteka do renderowania map w aplikacjach Flutter.
import 'package:latlong2/latlong.dart'; // Obsługa współrzędnych geograficznych (latitude, longitude).
import 'package:flutter/rendering.dart'; // Renderowanie widoków w Flutter.
import 'package:flutter/services.dart'; // Obsługa systemu, np. schowka, plików.

import 'package:navigation_app/pdf_utils.dart';
import 'package:navigation_app/random_route_methods.dart';
import 'package:navigation_app/coordinates_dialog.dart';
import 'package:navigation_app/getcoordinates_method.dart';
import 'package:navigation_app/gpx_utils.dart';

class MapScreen extends StatefulWidget { // Definicja widżetu typu Stateful (ze stanem).
  const MapScreen({super.key}); // Konstruktor klasy.
  @override
  State<MapScreen> createState() => _MapScreenState(); // Utworzenie stanu dla widżetu.
}

class _MapScreenState extends State<MapScreen> {// Klasa definiująca stan MapScreen.
  List<LatLng> points = [];// Lista punktów geograficznych na mapie.
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

   final MapController mapController = MapController(); // Kontroler mapy.
  final TextEditingController startLatController = TextEditingController(); // Kontroler tekstu dla szerokości punktu początkowego.
  final TextEditingController startLngController = TextEditingController(); // Kontroler tekstu dla długości punktu początkowego.
  final TextEditingController endLatController = TextEditingController(); // Kontroler tekstu dla szerokości punktu końcowego.
  final TextEditingController endLngController = TextEditingController(); // Kontroler tekstu dla długości punktu końcowego.
  final TextEditingController loopDistanceController = TextEditingController(); // Kontroler tekstu dla dystansu pętli.

  final TextEditingController stop1LatController = TextEditingController(); // Szerokość pierwszego przystanku.
  final TextEditingController stop1LngController = TextEditingController(); // Długość pierwszego przystanku.
  final TextEditingController stop2LatController = TextEditingController(); // Szerokość drugiego przystanku.
  final TextEditingController stop2LngController = TextEditingController(); // Długość drugiego przystanku.
  final TextEditingController stop3LatController = TextEditingController(); // Szerokość trzeciego przystanku.
  final TextEditingController stop3LngController = TextEditingController(); // Długość trzeciego przystanku.

  // Funkcje zapisujące do pdf i gtx
Future<void> saveToPdf() async {
  await saveToPdf_body(this);
}
Future<void> saveToGpx() async {
 await saveToGpx_body(this);
}

   // Funkcja generująca losową trasę
Future<void> generateRandomRoute(double loopDistance) async {
 generateRandomRoute_body(loopDistance,this);
}

  // Funkcja do pobrania trasy uwzględniającej przystanki
Future<void> getCoordinates() async {
 await  getCoordinates_body(this); 
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

  // Okno dialogowe do wprowadzania koordynatów
Future<void> showCoordinatesDialog(LatLng? point, String title) async {
  await showCoordinatesDialog_body(point,  title,  this);
  }

   // Funkcja formatująca czas z minut na godziny, minuty i sekundy
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