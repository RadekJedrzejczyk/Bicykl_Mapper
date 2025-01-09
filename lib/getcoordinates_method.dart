import 'package:latlong2/latlong.dart';
//import 'package:flutter/rendering.dart';
//import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:navigation_app/api.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';


Future<void> getCoordinates_body(dynamic state) async {
  if (state.startPoint == null || state.endPoint == null) {
    ScaffoldMessenger.of(state.context).showSnackBar(
      const SnackBar(content: Text('Proszę wprowadzić poprawne współrzędne!')),
    );
    return;
  }

  List<LatLng> routePoints = [state.startPoint!];
  if (state.stop1 != null) routePoints.add(state.stop1!);
  if (state.stop2 != null) routePoints.add(state.stop2!);
  if (state.stop3 != null) routePoints.add(state.stop3!);
  routePoints.add(state.endPoint!);

  state.points.clear(); // Czyścimy poprzednie punkty
  double totalDistance = 0.0;
  double totalDuration = 0.0;

  try {
    for (int i = 0; i < routePoints.length - 1; i++) {
      var start = routePoints[i];
      var end = routePoints[i + 1];
      
      String startStr = '${start.longitude},${start.latitude}';
      String endStr = '${end.longitude},${end.latitude}';
      var response = await http.get(Uri.parse(getRouteUrl(state.selectedProfile, startStr, endStr).toString()));

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