import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as coordinates;
import 'api.dart';
import 'gui_elements.dart';

class LocationPicker extends StatefulWidget {
  const LocationPicker({super.key});

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  coordinates.LatLng? selectedPoint;
  late String? address;

//wartości domyślne
  @override
  void initState() {
    super.initState();
    selectedPoint = const coordinates.LatLng(50.292961, 18.668930);
    reverseGeocode(50.292961, 18.668930).then((adres) {
      setState(() {
        address = adres;
      });
    });
  }

  Future<void> popNavigator() async {
    if (selectedPoint != null && address != null) {
      Navigator.pop(context, {
        'point': selectedPoint,
        'address': address,
      });
    }
  }

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
          createElevatedButton(
              context, 'Zakończ wybór', true, popNavigator, Colors.white,
              foregroundColor: Colors.black,
              fontSize: 14,
              horizontalTextPadding: 35,
              verticalTextPadding: 12)
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
