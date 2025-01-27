import 'package:flutter_test/flutter_test.dart';
import '../lib/formating_utils.dart';
import 'package:latlong2/latlong.dart' as coordinates;

void main() {
  test("Point to string method", () {
    coordinates.LatLng examplePoint = coordinates.LatLng(15.2, -21);
    expect(pointToString(examplePoint), '-21.0,15.2');
  });

  test("Konwersja minut na godziny", () {
    expect(minutesToHours(54.1), '54 min');
    expect(minutesToHours(66.2), '1 h 6 min');
  });
}
