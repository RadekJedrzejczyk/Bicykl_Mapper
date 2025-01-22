import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as coordinates;
import 'gpx_utils.dart';
import 'pdf_utils.dart';
import 'route_generation.dart';
import 'location_picker.dart';
import 'api.dart';
import 'formating_utils.dart';
import 'gui_elements.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late FlutterMap flutterMap;
  //kontrolery
  final MapController mapController = MapController();
  late TextEditingController loopLengthController;
  //inicjalizacja pustych tablic
  List<String> addresses = []; //Lista adresów
  List<coordinates.LatLng> points = []; //początek i koniec
  List<coordinates.LatLng> routePoints = []; //punkty używane do rysowania trasy
  List<coordinates.LatLng> stops = []; // Lista przystanków
  List<String> stopAddresses = []; // Lista adresów przystanków
  //pozostałe zmienne
  late double distance; //dystans trasy
  late double duration; //czas trwania trasy
  late double loopDistance; // Długość pętli w kilometrach
  late String selectedProfile; // wybrany rodzaj roweru
  late Map<String, String> profiles; // wszystkie dostępne rodzaje rowerów

//inicjalizacja wartości domyślnych
  @override
  void initState() {
    super.initState();
    //wartości domyślne
    distance = 0.0;
    duration = 0.0;
    loopDistance = 5.0;
    selectedProfile = 'cycling-regular';
    profiles = {
      'cycling-regular': 'Rower standardowy',
      'cycling-electric': 'Rower elektryczny',
      'cycling-mountain': 'Rower górski',
      'cycling-road': 'Rower szosowy',
    };
    //punkt początkowy - Gliwice
    points.add(const coordinates.LatLng(50.29761, 18.67658));
    reverseGeocode(points[0].latitude, points[0].longitude).then((address) {
      setState(() {
        addresses.add(address);
      });
    });
    //kontrolery
    loopLengthController = TextEditingController(
        text: '$loopDistance'); //ustawia domyślną wartość pętli
  }

//zapobieganie wyciekowi pamięcie - usunięcię kontrolerów
  @override
  void dispose() {
    loopLengthController.dispose();
    super.dispose();
  }

// Funkcja pomocnicza do zebrania szczegółów trasy -> route_generation.dart
  Future<void> generateRoute() async {
    generateRoute_body(this);
  }

//Metoda tworząca pętle -> route_generation.dart
  Future<void> generateLoop() async {
    generateLoop_body(this);
  }

  Future<void> showAddStopWidget() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPicker(),
      ),
    );
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        stops.add(result['point']);
        stopAddresses.add(result['address']);
      });
    }
  }

  Future<void> clearState() async {
    setState(() {
      points.clear();
      addresses.clear();
      stops.clear();
      stopAddresses.clear();
      routePoints.clear();
      distance = 0.0;
      duration = 0.0;
    });
  }

  Future<void> saveToGpx() async {
    saveToGpx_body(this);
  }

  Future<void> saveToPdf() async {
    saveToPdf_body(this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'BICYCLE NAVIGATION APP',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: Row(
        children: [
          // Lewy panel
          Flexible(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wyświetlanie informacji o przystankach itp.
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Card(
                      elevation: 3,
                      color: Colors.blue[50],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(6.0),
                        title: Text(
                          "Start: ${addresses.isNotEmpty ? addresses[0] : ''}\n"
                          "Koniec: ${addresses.length > 1 ? addresses[1] : ''}",
                          style: const TextStyle(fontSize: 10),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (stops.isNotEmpty) ...[
                              const SizedBox(height: 6.0),
                              const Text(
                                "Przystanki:",
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                              ...stopAddresses.map((stopAddress) => Text(
                                    stopAddress,
                                    style: const TextStyle(fontSize: 10),
                                  )),
                            ],
                            if (distance > 0.0 || duration > 0.0)
                              Row(
                                children: [
                                  const Icon(Icons.directions_bike,
                                      color: Colors.green, size: 12),
                                  const SizedBox(width: 6.0),
                                  Text(
                                    "Dystans: ${distance.toStringAsFixed(2)} km",
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            if (distance > 0.0 || duration > 0.0)
                              Row(
                                children: [
                                  const Icon(Icons.access_time,
                                      color: Colors.orange, size: 12),
                                  const SizedBox(width: 6.0),
                                  Text(
                                    "Czas: ${minutesToHours(duration)}",
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Button for adding stops
                  Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: createElevatedButton(context, "Dodaj przystanek",
                          points.length >= 2, showAddStopWidget, Colors.green)),
                  // Wybieranie rodzaju roweru
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6.0),
                    child: Text(
                      "Wybierz profil roweru",
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: profiles.entries.map((entry) {
                        bool isSelected = selectedProfile == entry.key;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedProfile = entry.key;
                              });
                            },
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6.0),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.blueAccent
                                      : Colors.grey,
                                  width: 2,
                                ),
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6.0),
                                child: Text(
                                  entry.value,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.blueAccent
                                        : Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // Generate and clear buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          flex: 2,
                          //wprowadzanie długości pętli
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: '(km)',
                              labelStyle: TextStyle(fontSize: 10),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            keyboardType: TextInputType.number,
                            controller: loopLengthController,
                            onChanged: (value) {
                              setState(() {
                                loopDistance = double.tryParse(value) ??
                                    5.0; // Domyślnie 5 km, jeśli wpisano błędną wartość
                              });
                            },
                            style: TextStyle(
                              fontSize:
                                  10, // Zmieniono wielkość czcionki na mniejszą
                            ),
                          ),
                        ),
                        //przycisk - generuj trasę
                        createElevatedButton(
                            context,
                            "Generuj trasę",
                            points.length >= 2,
                            generateRoute,
                            Colors.blueAccent),
                        //przycisk - generuj pętle
                        createElevatedButton(
                            context,
                            "Generuj pętlę",
                            points.length == 1,
                            generateLoop,
                            Colors.purpleAccent),
                        //przycisk do usuwania
                        createElevatedButton(context, "Usuń dane",
                            points.isNotEmpty, clearState, Colors.redAccent)
                      ],
                    ),
                  ),
                  // Przycisku zapisu do PDF oraz GPX
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      children: [
                        createElevatedButton(context, "Zapisz jako GPX",
                            points.isNotEmpty, saveToGpx, Colors.orange),
                        const SizedBox(width: 10), // Odstęp między przyciskami
                        createElevatedButton(context, "Zapisz jako PDF",
                            points.isNotEmpty, saveToPdf, Colors.blue)
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right panel for the map
          Flexible(
            flex: 7, // Adjust flex ratio for desired width
            child: Stack(
              children: [
                flutterMap = FlutterMap(
                  options: MapOptions(
                    initialCenter: coordinates.LatLng(50.292961, 18.668930),
                    initialZoom: 11,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    ),
                    if (routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: routePoints,
                            strokeWidth: 4.0,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: points
                          .map(
                            (point) => Marker(
                              point: point,
                              width: 80.0,
                              height: 80.0,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    MarkerLayer(
                      markers: stops
                          .map(
                            (stop) => Marker(
                              point: stop,
                              width: 80.0,
                              height: 80.0,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.green,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
                //przycisk wyboru lokacji
                Positioned(
                  bottom: 20.0,
                  left: 12.0,
                  child: FloatingActionButton(
                      onPressed: points.length < 2
                          ? () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LocationPicker(),
                                ),
                              );
                              if (result != null &&
                                  result is Map<String, dynamic>) {
                                setState(() {
                                  points.add(result['point']);
                                  addresses.add(result['address']);
                                });
                              }
                            }
                          : null,
                      backgroundColor:
                          points.length < 2 ? Colors.blue : Colors.grey,
                      child: const Icon(Icons.add_location)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
