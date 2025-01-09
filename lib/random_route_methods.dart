import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:navigation_app/api.dart';
import 'dart:math';


Future<void> generateRandomRoute_body(double loopDistance, dynamic state) async {
  if (state.startPoint == null) {
    ScaffoldMessenger.of(state.context).showSnackBar(
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

    double randomLat = state.startPoint!.latitude + radius * (1 / 111.32) * sin(radian);
    double randomLng = state.startPoint!.longitude + radius * (1 / 85.0) * cos(radian);
    LatLng randomPoint = LatLng(randomLat, randomLng);

    double midLat = (state.startPoint!.latitude + randomPoint.latitude) / 2;
    double midLng = (state.startPoint!.longitude + randomPoint.longitude) / 2;
    LatLng midpoint = LatLng(midLat, midLng);

    state.points.clear(); // Czyszczenie poprzedniej trasy

    double totalDistance = 0.0;
    double totalDuration = 0.0;

    try {
      // Trasa 1: Początkowy -> Losowy
      var segment1 = await getCoordinatesForRouteWithDetails(state.startPoint!, randomPoint,state);
      totalDistance += segment1['distance'] ?? 0.0;
      totalDuration += segment1['duration'] ?? 0.0;

      // Trasa 2: Losowy -> Średni
      var segment2 = await getCoordinatesForRouteWithDetails(randomPoint, midpoint,state);
      totalDistance += segment2['distance'] ?? 0.0;
      totalDuration += segment2['duration'] ?? 0.0;

      // Trasa 3: Średni -> Początkowy
      var segment3 = await getCoordinatesForRouteWithDetails(midpoint, state.startPoint!,state);
      totalDistance += segment3['distance'] ?? 0.0;
      totalDuration += segment3['duration'] ?? 0.0;

      // Sprawdzanie, czy dystans mieści się w tolerancji
      if ((totalDistance - loopDistance).abs() <= tolerance) {
        isWithinTolerance = true;

        // Aktualizowanie stanu tylko, gdy pętla jest akceptowalna
        state.setState(() {
          state.distance = totalDistance;
          state.duration = totalDuration;

          if (state.points.isNotEmpty) {
            var bounds = LatLngBounds.fromPoints(state.points);
            var center = bounds.center;

            // Ustawienie widoku mapy
            state.mapController.move(center, 10.0); // Dostosuj zoom do swoich potrzeb
          }
        });
      }
    } catch (e) {
      // Obsługa błędów API
      ScaffoldMessenger.of(state.context).showSnackBar(
        const SnackBar(content: Text('Wystąpił problem z generowaniem trasy. Próbuję ponownie...')),
      );
    }
  }
}

// Funkcja pomocnicza do wywołania API i zebrania szczegółów trasy
Future<Map<String, double>> getCoordinatesForRouteWithDetails(LatLng start, LatLng end, dynamic state) async {
  String startStr = '${start.longitude},${start.latitude}';
  String endStr = '${end.longitude},${end.latitude}';

  var response = await http.get(Uri.parse(getRouteUrl(state.selectedProfile, startStr, endStr).toString()));

  if (response.statusCode == 200) {
    var data = jsonDecode(response.body);

    // Wyciąganie współrzędnych
    var listOfPoints = data['features'][0]['geometry']['coordinates'] as List<dynamic>;
    state.points.addAll(listOfPoints.map((e) => LatLng(e[1].toDouble(), e[0].toDouble())).toList());

    // Wyciąganie dystansu i czasu
    double distance = data['features'][0]['properties']['segments'][0]['distance'] / 1000;
    double duration = data['features'][0]['properties']['segments'][0]['duration'] / 60;

    return {'distance': distance, 'duration': duration};
  } else {
    ScaffoldMessenger.of(state.context).showSnackBar(
      const SnackBar(content: Text('Nie udało się pobrać trasy. Spróbuj ponownie.')),
    );
    return {'distance': 0.0, 'duration': 0.0};
  }
}