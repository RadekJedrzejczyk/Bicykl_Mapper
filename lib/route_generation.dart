import 'package:latlong2/latlong.dart' as coordinates;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'api.dart';
import 'formating_utils.dart';

Future<void> generateRoute_body(dynamic state) async {
  if (!state.points.isNotEmpty) {
    throw StateError(
        'Nie można wygenerować trasy. - Proszę dodać dwa punkty na mapie.');
  }
  final coordinates.LatLng start = state.points[0];
  final coordinates.LatLng end =
      state.points[state.points.length - 1]; // Ostatni punkt to koniec
  final List<coordinates.LatLng> stopsMap = state.stops;
  List<coordinates.LatLng> routePointsTemp = []; //temporary
  double totalDistance = 0.0;
  double totalDuration = 0.0;

  // Jeżeli mamy przynajmniej jeden przystanek
  List<coordinates.LatLng> allStops = [start] + stopsMap + [end];

  for (int i = 0; i < allStops.length - 1; i++) {
    final startPoint = allStops[i];
    final endPoint = allStops[i + 1];

    final url = getRouteUrl(state.selectedProfile, pointToString(startPoint),
        pointToString(endPoint));

    var response = await http.get(url);
    checkResponseCode(response);

    var data = jsonDecode(response.body);
    var listOfPoints =
        data['features'][0]['geometry']['coordinates'] as List<dynamic>;

    // Zamiana punktów z listy na odpowiedni format LatLng
    routePointsTemp.addAll(listOfPoints
        .map((e) => coordinates.LatLng(e[1].toDouble(), e[0].toDouble()))
        .toList());

    // Obliczanie dystansu i czasu
    double segmentDistance =
        data['features'][0]['properties']['segments'][0]['distance'] / 1000;
    double segmentDuration =
        data['features'][0]['properties']['segments'][0]['duration'] / 60;

    totalDistance += segmentDistance;
    totalDuration += segmentDuration;
  }

  state.setState(() {
    state.routePoints = routePointsTemp;
    state.distance = totalDistance;
    state.duration = totalDuration;
    state.fitMapCamera();
  });
}

Future<void> generateLoop_body(dynamic state) async {
  try {
    if (state.points.length != 1) {
      throw StateError(
          "Nie można wygenerować trasy. - Należy dodać tylko jeden punkt.");
    }
    final startPoint = state.points[0];

    // Generowanie punktów spiralnych
    List<coordinates.LatLng> spiralPoints = [];
    double initialDistance = state.loopDistance / 3;
    double spiralRadius = initialDistance;
    double angleIncrement = 22; // Kąt, o jaki przesuwa się spirala
    double angle = 0;

    // Generowanie 3 punktów spiralnych
    for (int i = 0; i < 3; i++) {
      // Wygeneruj punkt
      coordinates.LatLng spiralPoint =
          generateSpiralPoint(startPoint, spiralRadius, angle);

      // Upewnij się, że punkt nie znajduje się zbyt blisko poprzedniego
      if (i == 0 ||
          checkMinimumSeparation(
              spiralPoints.last, spiralPoint, state.loopDistance / 10)) {
        spiralPoints.add(spiralPoint);

        // Zmniejsz promień, aby punkty były coraz bliżej punktu początkowego
        spiralRadius -=
            state.loopDistance / 20; // Malejmy promień po każdym punkcie

        // Zwiększ kąt do kolejnego obrotu spirali
        angle += angleIncrement;
      } else {
        i--; // Jeśli punkt jest za blisko poprzedniego, próbuj ponownie
      }
    }

    // Na tym etapie mamy już wygenerowane punkty spiralne
    double totalDistance = 0;
    double totalTime = 0;
    List<List<coordinates.LatLng>> allRoutePoints = [];
    coordinates.LatLng currentPoint = startPoint;

    // Wykonaj trasę z każdego punktu do kolejnego
    for (int i = 0; i < spiralPoints.length; i++) {
      coordinates.LatLng nextPoint = spiralPoints[i];

      final urlToNextPoint = getRouteUrl(state.selectedProfile,
          pointToString(currentPoint), pointToString(nextPoint));
      final responseToNextPoint = await http.get(urlToNextPoint);

      checkResponseCode(responseToNextPoint);
      final dataToNextPoint = jsonDecode(responseToNextPoint.body);
      final pointsToNextPoint = dataToNextPoint['features'][0]['geometry']
          ['coordinates'] as List<dynamic>;

      allRoutePoints.add(pointsToNextPoint
          .map((e) => coordinates.LatLng(e[1].toDouble(), e[0].toDouble()))
          .toList());

      totalDistance += dataToNextPoint['features'][0]['properties']['segments']
              [0]['distance'] /
          1000;
      totalTime = dataToNextPoint['features'][0]['properties']['segments'][0]
              ['duration'] /
          60;

      // Aktualizuj bieżący punkt
      currentPoint = nextPoint;
    }

    final urlToStart = getRouteUrl(state.selectedProfile,
        pointToString(currentPoint), pointToString(startPoint));
    final responseToStart = await http.get(urlToStart);

    checkResponseCode(responseToStart);

    final dataToStart = jsonDecode(responseToStart.body);
    final pointsToStart =
        dataToStart['features'][0]['geometry']['coordinates'] as List<dynamic>;

    allRoutePoints.add(pointsToStart
        .map((e) => coordinates.LatLng(e[1].toDouble(), e[0].toDouble()))
        .toList());

    totalDistance += dataToStart['features'][0]['properties']['segments'][0]
            ['distance'] /
        1000;
    totalTime += dataToStart['features'][0]['properties']['segments'][0]
            ['duration'] /
        60;

    double expectedDistance = state.loopDistance;

    // Sprawdzamy, czy całkowity dystans jest odpowiedni - zapisujemy jeśli tak, restartujemy metodę jeśli nie
    if (isDistanceValid(totalDistance, expectedDistance)) {
      state.setState(() {
        state.routePoints = allRoutePoints.expand((x) => x).toList();
        state.distance = totalDistance;
        state.duration = totalTime;
        state.fitMapCamera();
      });
    } else {
      state.generateLoop();
    }
  } catch (e) {
    rethrow;
  }
}

// Funkcja pomocnicza do losowania punktu w spiralnym układzie
coordinates.LatLng generateSpiralPoint(
    coordinates.LatLng center, double radius, double angle) {
  const double earthRadiusKm = 6371.0; // Promień Ziemi
  double angleInRadians = angle * pi / 180;

  // Ustalanie przesunięcia w kierunku radialnym
  double dx = radius * cos(angleInRadians);
  double dy = radius * sin(angleInRadians);

  // Nowe współrzędne
  double lat = center.latitude + (dy / earthRadiusKm) * (180 / pi);
  double lng = center.longitude +
      (dx / earthRadiusKm) * (180 / pi) / cos(center.latitude * pi / 180);
  return coordinates.LatLng(lat, lng);
}

// Funkcja pomocnicza do obliczania odległości między dwoma punktami geograficznymi
double calculateDistance(coordinates.LatLng p1, coordinates.LatLng p2) {
  const double earthRadiusKm = 6371.0;
  double dLat = (p2.latitude - p1.latitude) * pi / 180;
  double dLng = (p2.longitude - p1.longitude) * pi / 180;
  double a = sin(dLat / 2) * sin(dLat / 2) +
      cos(p1.latitude * pi / 180) *
          cos(p2.latitude * pi / 180) *
          sin(dLng / 2) *
          sin(dLng / 2);
  double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c; // Dystans w kilometrach
}

bool isDistanceValid(double totalDistance, double expectedDistance,
    {double tolerance = 0.5}) {
  return totalDistance <= expectedDistance * (1 + tolerance) &&
      totalDistance >= expectedDistance * (1 - tolerance);
}

bool checkMinimumSeparation(
    coordinates.LatLng p1, coordinates.LatLng p2, double minDistanceKm) {
  double distance = calculateDistance(p1, p2);
  return distance >= minDistanceKm;
}
