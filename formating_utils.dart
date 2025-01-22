import 'package:latlong2/latlong.dart' as coordinates;

String pointToString(coordinates.LatLng point) {
  return '${point.longitude},${point.latitude}';
}

String minutesToHours(double minutes) {
  int roundedMinutes =
      minutes.round(); // Round the value to the nearest integer
  int hours = roundedMinutes ~/ 60; // Calculate hours
  int remainingMinutes = roundedMinutes % 60; // Calculate the remaining minutes

  if (hours > 0) {
    // jeśli czas poniżej godziny to wyświetl tylko minuty
    return '$hours h $remainingMinutes min';
  } else {
    return '$remainingMinutes min';
  }
}
