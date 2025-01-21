import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as coordinates;
import 'api.dart';
import 'dart:math';
import 'gpx_utils.dart';
import 'pdf_utils.dart';
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
  List<coordinates.LatLng> points = [];
  late FlutterMap flutterMap;
  List<String> addresses = [];
  List<coordinates.LatLng> routePoints = [];
  List<coordinates.LatLng> stops = [];  // Lista przystanków
  List<String> stopAddresses = [];  // Lista adresów przystanków
  final MapController mapController = MapController();
  double distance = 0.0;
  double loopDistance = 5.0; // Domyślna długość pętli w kilometrach

  double duration = 0.0;

  // Profil roweru - domyślny
  String selectedProfile = 'cycling-regular';

  final Map<String, String> profiles = {
    'cycling-regular': 'Rower standardowy',
    'cycling-electric': 'Rower elektryczny',
    'cycling-mountain': 'Rower górski',
    'cycling-road': 'Rower szosowy',
  };

String formatDuration(double minutes) {
  int roundedMinutes = minutes.round();  // Round the value to the nearest integer
  int hours = roundedMinutes ~/ 60;  // Calculate hours
  int remainingMinutes = roundedMinutes % 60;  // Calculate the remaining minutes

  if (hours > 0) {
    return '${hours}h ${remainingMinutes} min'; // Hours and minutes format
  } else {
    return '${remainingMinutes} min';  // Only minutes if no hours
  }
}

  // Funkcja pomocnicza do wywołania API i zebrania szczegółów trasy
// Funkcja pomocnicza do wywołania API i zebrania szczegółów trasy
Future<void> generateRoute() async {
  if (points.isNotEmpty) {
    final start = points[0];
    final end = points[points.length - 1];  // Ostatni punkt to koniec

    List<coordinates.LatLng> routePointsTemp = [];
    double totalDistance = 0.0;
    double totalDuration = 0.0;

    // Jeżeli mamy przynajmniej jeden przystanek
    List<coordinates.LatLng> allStops = [start] + stops + [end];

    for (int i = 0; i < allStops.length - 1; i++) {
      final startPoint = allStops[i];
      final endPoint = allStops[i + 1];

      final url = getRouteUrl(selectedProfile, '${startPoint.longitude},${startPoint.latitude}', '${endPoint.longitude},${endPoint.latitude}');

      var response = await http.get(url);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        var listOfPoints = data['features'][0]['geometry']['coordinates'] as List<dynamic>;

        // Zamiana punktów z listy na odpowiedni format LatLng
        routePointsTemp.addAll(listOfPoints
            .map((e) => coordinates.LatLng(e[1].toDouble(), e[0].toDouble()))
            .toList());

        // Obliczanie dystansu i czasu
        double segmentDistance = data['features'][0]['properties']['segments'][0]['distance'] / 1000;
        double segmentDuration = data['features'][0]['properties']['segments'][0]['duration'] / 60;

        totalDistance += segmentDistance;
        totalDuration += segmentDuration;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się pobrać trasy.')),
        );
        return;  // Zakończ, jeśli któraś trasa nie powiedzie się
      }
    }

    setState(() {
      routePoints = routePointsTemp;
      distance = totalDistance;
      duration = totalDuration;
    });
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Proszę dodać dwa punkty na mapie.')),
    );
  }
}


Future<void> generateLoop() async {
  if (points.length == 1) {
    final startPoint = points[0];

    // Funkcja pomocnicza do losowania punktu w spiralnym układzie
    coordinates.LatLng generateSpiralPoint(coordinates.LatLng center, double radius, double angle) {
      const double earthRadiusKm = 6371.0; // Promień Ziemi
      double angleInRadians = angle * pi / 180;

      // Ustalanie przesunięcia w kierunku radialnym
      double dx = radius * cos(angleInRadians); 
      double dy = radius * sin(angleInRadians);

      // Nowe współrzędne
      double lat = center.latitude + (dy / earthRadiusKm) * (180 / pi);
      double lng = center.longitude + (dx / earthRadiusKm) * (180 / pi) / cos(center.latitude * pi / 180);

      return coordinates.LatLng(lat, lng);
    }

    // Funkcja pomocnicza do obliczania odległości między dwoma punktami geograficznymi
    double calculateDistance(coordinates.LatLng p1, coordinates.LatLng p2) {
      const double earthRadiusKm = 6371.0;
      double dLat = (p2.latitude - p1.latitude) * pi / 180;
      double dLng = (p2.longitude - p1.longitude) * pi / 180;
      double a = sin(dLat / 2) * sin(dLat / 2) + cos(p1.latitude * pi / 180) * cos(p2.latitude * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
      double c = 2 * atan2(sqrt(a), sqrt(1 - a));
      return earthRadiusKm * c; // Dystans w kilometrach
    }

    bool checkIfValidDistance(coordinates.LatLng p1, coordinates.LatLng p2, double minDistanceKm) {
      double distance = calculateDistance(p1, p2);
      return distance >= minDistanceKm;
    }

    // Generowanie punktów spiralnych
    List<coordinates.LatLng> spiralPoints = [];
    double initialDistance = loopDistance / 3;
    double spiralRadius = initialDistance;
    double angleIncrement = 22;  // Kąt, o jaki przesuwa się spirala
    double angle = 0;

    // Generowanie 3 punktów spiralnych
    for (int i = 0; i < 3; i++) {
      // Wygeneruj punkt
      coordinates.LatLng spiralPoint = generateSpiralPoint(startPoint, spiralRadius, angle);

      // Upewnij się, że punkt nie znajduje się zbyt blisko poprzedniego
      if (i == 0 || checkIfValidDistance(spiralPoints.last, spiralPoint, loopDistance / 10)) {
        spiralPoints.add(spiralPoint);

        // Zmniejsz promień, aby punkty były coraz bliżej punktu początkowego
        spiralRadius -= loopDistance / 20;  // Malejmy promień po każdym punkcie

        // Zwiększ kąt do kolejnego obrotu spirali
        angle += angleIncrement;
      } else {
        i--;  // Jeśli punkt jest za blisko poprzedniego, próbuj ponownie
      }
    }

    // Na tym etapie mamy już wygenerowane punkty spiralne

    bool isDistanceValid(double totalDistance, double expectedDistance) {
      // Oczekiwana długość trasy i tolerancja
      double tolerance = 0.5;
      return totalDistance <= expectedDistance * (1 + tolerance) && totalDistance >= expectedDistance * (1 - tolerance);
    }

    double totalDistance = 0;
    List<List<coordinates.LatLng>> allRoutePoints = [];
    coordinates.LatLng currentPoint = startPoint;

    // Wykonaj trasę z każdego punktu do kolejnego
    for (int i = 0; i < spiralPoints.length; i++) {
      coordinates.LatLng nextPoint = spiralPoints[i];

      final urlToNextPoint = getRouteUrl(
        selectedProfile,
        '${currentPoint.longitude},${currentPoint.latitude}',
        '${nextPoint.longitude},${nextPoint.latitude}',
      );
      final responseToNextPoint = await http.get(urlToNextPoint);

      if (responseToNextPoint.statusCode == 200) {
        final dataToNextPoint = jsonDecode(responseToNextPoint.body);
        final pointsToNextPoint = dataToNextPoint['features'][0]['geometry']['coordinates'] as List<dynamic>;

        allRoutePoints.add(pointsToNextPoint.map((e) => coordinates.LatLng(e[1].toDouble(), e[0].toDouble())).toList());

        totalDistance += dataToNextPoint['features'][0]['properties']['segments'][0]['distance'] / 1000;

        // Aktualizuj bieżący punkt
        currentPoint = nextPoint;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się wyznaczyć trasy między punktami.')) 
        );
        return;
      }
    }

    // Na koniec wyznacz trasę do punktu początkowego, aby zakończyć spiralę
    final urlToStart = getRouteUrl(
      selectedProfile,
      '${currentPoint.longitude},${currentPoint.latitude}',
      '${startPoint.longitude},${startPoint.latitude}',
    );
    final responseToStart = await http.get(urlToStart);

    if (responseToStart.statusCode == 200) {
      final dataToStart = jsonDecode(responseToStart.body);
      final pointsToStart = dataToStart['features'][0]['geometry']['coordinates'] as List<dynamic>;

      allRoutePoints.add(pointsToStart.map((e) => coordinates.LatLng(e[1].toDouble(), e[0].toDouble())).toList());

      totalDistance += dataToStart['features'][0]['properties']['segments'][0]['distance'] / 1000;

      double expectedDistance = loopDistance;

      // Sprawdzamy, czy całkowity dystans jest odpowiedni
      if (!isDistanceValid(totalDistance, expectedDistance)) {
        // Jeśli dystans jest za długi lub za krótki, zaczynamy generowanie punktów od nowa
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dystans trasy nie jest odpowiedni, spróbujmy ponownie.')),
        );
        generateLoop(); // Rekursja w przypadku nieakceptowalnego dystansu
        return;
      }

      // Zapisz trasę i zaktualizuj dane
      setState(() {
        routePoints = allRoutePoints.expand((x) => x).toList();
        distance = totalDistance; // Przypisujemy całkowitą długość trasy
        duration = allRoutePoints.fold(0, (sum, route) => sum + route.length) / 60;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się wyznaczyć trasy do punktu startowego.'))
      );
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Proszę dodać dokładnie jeden punkt.'))
    );
  }
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
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                              ...stopAddresses.map((stopAddress) => Text(
                                stopAddress,
                                style: const TextStyle(fontSize: 10),
                              )),
                            ],
                            if (distance > 0.0 || duration > 0.0)
                              Row(
                                children: [
                                  const Icon(Icons.directions_bike, color: Colors.green, size: 12),
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
                                  const Icon(Icons.access_time, color: Colors.orange, size: 12),
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
                              if (result != null && result is Map<String, dynamic>) {
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
                        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
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
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                              margin: const EdgeInsets.symmetric(horizontal: 4.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6.0),
                                border: Border.all(
                                  color: isSelected ? Colors.blueAccent : Colors.grey,
                                  width: 2,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6.0),
                                child: Text(
                                  entry.value,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSelected ? Colors.blueAccent : Colors.black,
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
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: '(km)',
                              labelStyle: TextStyle(fontSize: 10),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              setState(() {
                                loopDistance = double.tryParse(value) ?? 5.0; // Domyślnie 5 km, jeśli wpisano błędną wartość
                              });
                            },
                            style: TextStyle(
                              fontSize: 10, // Zmieniono wielkość czcionki na mniejszą
                            ),
                          ),
                        ),
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
                            padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                            child: Text(
                              "Generuj trasę",
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
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
                            padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
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
                            padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
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
        onPressed: points.isNotEmpty ? () async {
          await saveToGpx_body(this); // Funkcja zapisu jako GPX
        } : null,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
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
          backgroundColor: Colors.blue,  // Można zmienić kolor
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          elevation: 4,
          minimumSize: const Size(100, 30),
        ),
        onPressed: points.isNotEmpty ? () async {
          await saveToPdf_body(this);  // Funkcja zapisu jako PDF
        } : null,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
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
               flutterMap =  FlutterMap(
                  options: MapOptions(
                    initialCenter: coordinates.LatLng(50.292961, 18.668930),
                    initialZoom: 11,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
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
                            if (result != null && result is Map<String, dynamic>) {
                              setState(() {
                                points.add(result['point']);
                                addresses.add(result['address']);
                              });
                            }
                          }
                        : null,
                    child: const Icon(Icons.add_location),
                    backgroundColor: points.length < 2 ? Colors.blue : Colors.grey,
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

class LocationPicker extends StatefulWidget {
  const LocationPicker({super.key});

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  coordinates.LatLng? selectedPoint;
  String? address;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Wybierz lokalizację"),
        backgroundColor: Colors.white, // Zmieniony kolor appbara
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            flex: 10,
            child: _osmWidget(),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selectedPoint != null && address != null) {
                Navigator.pop(context, {
                  'point': selectedPoint,
                  'address': address,
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white, // Kolor tła przycisku
              foregroundColor: Colors.black, // Kolor tekstu
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0), // Zaokrąglone rogi
              ),
              padding: const EdgeInsets.symmetric(horizontal: 35.0, vertical: 12.0), // Padding wewnętrzny
              elevation: 5, // Dodanie cienia
            ),
            child: const Text(
              'Zakończ wybór',
              style: TextStyle(
                fontSize: 14, // Zwiększona czcionka
                fontWeight: FontWeight.bold, // Pogrubienie tekstu
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _osmWidget() {
    return FlutterMap(
      options: MapOptions(
        initialCenter: coordinates.LatLng(50.292961, 18.668930),
        initialZoom: 12.0,
        onTap: (tapLoc, position) async {
          setState(() {
            selectedPoint = position;
          });

          address = await reverseGeocode(position.latitude, position.longitude);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
        ),
        MarkerLayer(
          markers: [
            Marker(
              width: 80.0,
              height: 80.0,
              point: selectedPoint ?? coordinates.LatLng(50.292961, 18.668930),
              child: const Icon(
                Icons.location_on,
                color: Colors.blueAccent,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
