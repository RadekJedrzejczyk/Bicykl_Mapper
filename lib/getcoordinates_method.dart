import 'package:latlong2/latlong.dart';  // Obsługa współrzędnych geograficznych (latitude, longitude).
import 'dart:convert'; // Import do obsługi konwersji danych w formacie JSON.
import 'package:flutter/material.dart'; // Główna biblioteka do tworzenia aplikacji Flutter.
import 'package:http/http.dart' as http; // Do wysyłania żądań HTTP.
import 'package:flutter_map/flutter_map.dart'; // Biblioteka do renderowania map w aplikacjach Flutter.
import 'package:navigation_app/api.dart'; // Import niestandardowego pliku API (zawiera nasze metody).

// Funkcja do pobrania trasy uwzględniającej przystanki
Future<void> getCoordinates_body(dynamic state) async {
  
  if (state.startPoint == null || state.endPoint == null) {
    ScaffoldMessenger.of(state.context).showSnackBar(
      const SnackBar(content: Text('Proszę wprowadzić poprawne współrzędne!')),
    );
    return;
  }

  // Tworzenie listy punktów uwzględniającej przystanki
  List<LatLng> routePoints = [state.startPoint!];
  if (state.stop1 != null) routePoints.add(state.stop1!);
  if (state.stop2 != null) routePoints.add(state.stop2!);
  if (state.stop3 != null) routePoints.add(state.stop3!);
  routePoints.add(state.endPoint!);

  state.points.clear(); // Czyścimy poprzednie punkty
  double totalDistance = 0.0;
  double totalDuration = 0.0;

  try {
    // Iteracja po parach punktów na trasie
    for (int i = 0; i < routePoints.length - 1; i++) {
      var start = routePoints[i]; // Punkt początkowy
      var end = routePoints[i + 1];
      
      // Formatowanie
      String startStr = '${start.longitude},${start.latitude}';
      String endStr = '${end.longitude},${end.latitude}';
      //Zapytanie do api
      var response = await http.get(Uri.parse(getRouteUrl(state.selectedProfile, startStr, endStr).toString()));
 // Dekodowanie odpowiedzi 
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);

        // Wyciągnięcie współrzędnych segmentu trasy
        var listOfPoints = data['features'][0]['geometry']['coordinates'] as List<dynamic>;
        state.points.addAll(listOfPoints.map((e) => LatLng(e[1].toDouble(), e[0].toDouble())));

        // Sumowanie dystansu i czasu trwania segmentów
        totalDistance += data['features'][0]['properties']['segments'][0]['distance'] / 1000;
        totalDuration += data['features'][0]['properties']['segments'][0]['duration'] / 60;
      } else {
        throw Exception('Nie udało się pobrać trasy dla segmentu ${i + 1}');
      }
    }
// Aktualizacja dystansu i czasu
    state.setState(() {
      state.distance = totalDistance;
      state.duration = totalDuration;

      // Dopasowanie widoku mapy do trasy
      if (state.points.isNotEmpty) {
        var bounds = LatLngBounds.fromPoints(state.points);
        var center = bounds.center;
        var zoom = 6.0; // Zwiększamy zoom po wyznaczeniu trasy, aby był bardziej szczegółowy
        state.mapController.move(center, zoom);

      }
    });
  } catch (e) {
    ScaffoldMessenger.of(state.context).showSnackBar(
      const SnackBar(content: Text('Wystąpił problem z generowaniem trasy. Spróbuj ponownie.')),
    );
  }
}