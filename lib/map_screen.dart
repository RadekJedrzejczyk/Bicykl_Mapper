import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as coordinates;
import 'gpx_utils.dart';
import 'pdf_utils.dart';
import 'route_generation.dart';
import 'location_picker.dart';
import 'api.dart';

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
  List<coordinates.LatLng> points = [];
  List<coordinates.LatLng> routePoints = [];
  List<coordinates.LatLng> stops = []; // Lista przystanków
  List<String> stopAddresses = []; // Lista adresów przystanków
  //pozostałe zmienne
  late double distance; //dystans trasy
  late double duration; //czas trwania trasy
  late double loopDistance; // Długość pętli w kilometrach
  late String selectedProfile = 'cycling-regular'; // wybrany rodzaj roweru
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
    points.add(coordinates.LatLng(50.29761, 18.67658));
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

  String formatDuration(double minutes) {
    int roundedMinutes =
        minutes.round(); // Round the value to the nearest integer
    int hours = roundedMinutes ~/ 60; // Calculate hours
    int remainingMinutes =
        roundedMinutes % 60; // Calculate the remaining minutes

    if (hours > 0) {
      // jeśli czas poniżej godziny to wyświetl tylko minuty
      return '$hours h $remainingMinutes min';
    } else {
      return '$remainingMinutes min';
    }
  }

// Funkcja pomocnicza do zebrania szczegółów trasy -> route_generation.dart
  Future<void> generateRoute() async {
    generateRoute_body(this);
  }

//Metoda tworząca pętle -> route_generation.dart
  Future<void> generateLoop() async {
    generateLoop_body(this);
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
          // Left panel for controls and information
          Flexible(
            flex: 3, // Adjust flex ratio for desired width
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Information about route, stops, and distance
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
                                    "Czas: ${formatDuration(duration)}",
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
                    child: ElevatedButton(
                      onPressed: points.length >= 2
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
                                  stops.add(result['point']);
                                  stopAddresses.add(result['address']);
                                });
                              }
                            }
                          : null,
                      child: const Text("Dodaj przystanek"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12.0, horizontal: 20.0),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Profile selection buttons
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
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            elevation: 4,
                            minimumSize: const Size(100, 30),
                          ),
                          onPressed: points.length >= 2 ? generateRoute : null,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 6.0),
                            child: Text(
                              "Generuj trasę",
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        //przycisk - generuj pętle
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purpleAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            elevation: 4,
                            minimumSize: const Size(100, 30),
                          ),
                          onPressed: points.length == 1 ? generateLoop : null,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 6.0),
                            child: Text(
                              "Generuj pętlę",
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            elevation: 4,
                            minimumSize: const Size(100, 30),
                          ),
                          onPressed: points.isNotEmpty
                              ? () {
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
                              : null,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 6.0),
                            child: Text(
                              "Usuń dane",
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Button to save the GPX file
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      children: [
                        // Przycisk do zapisania GPX
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            elevation: 4,
                            minimumSize: const Size(100, 30),
                          ),
                          onPressed: points.isNotEmpty
                              ? () async {
                                  await saveToGpx_body(
                                      this); // Funkcja zapisu jako GPX
                                }
                              : null,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 6.0),
                            child: Text(
                              "Zapisz jako GPX",
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10), // Odstęp między przyciskami

                        // Przycisk do zapisania PDF
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue, // Można zmienić kolor
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            elevation: 4,
                            minimumSize: const Size(100, 30),
                          ),
                          onPressed: points.isNotEmpty
                              ? () async {
                                  await saveToPdf_body(
                                      this); // Funkcja zapisu jako PDF
                                }
                              : null,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.0, vertical: 6.0),
                            child: Text(
                              "Zapisz jako PDF",
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
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
                    child: const Icon(Icons.add_location),
                    backgroundColor:
                        points.length < 2 ? Colors.blue : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
