import 'package:flutter_test/flutter_test.dart';
import '../lib/route_generation.dart';
import 'package:latlong2/latlong.dart' as coordinates;

void main() {
  test("Obliczanie i sprawdzanie odległości", () {
    coordinates.LatLng point1 =
        const coordinates.LatLng(50.2602534, 19.0137982);
    coordinates.LatLng point2 =
        const coordinates.LatLng(50.2644984, 19.0174587);
    expect(calculateDistance(point1, point2),
        allOf(greaterThanOrEqualTo(0.5), lessThanOrEqualTo(1)));
    expect(isDistanceValid(-100, -50), false);
    expect(isDistanceValid(100, 95), true);
    expect(checkMinimumSeparation(point1, point2, 0.1), true);
    expect(checkMinimumSeparation(point1, point1, 0.1), false);
  });
}
