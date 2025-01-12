import 'package:latlong2/latlong.dart';  // Obsługa współrzędnych geograficznych (latitude, longitude).
import 'package:flutter/material.dart'; // Główna biblioteka do tworzenia aplikacji Flutter.

Future<void> showCoordinatesDialog_body(LatLng? point, String title, dynamic state) async {
    final TextEditingController latController = TextEditingController();
    final TextEditingController lngController = TextEditingController();

    if (point != null) {
      latController.text = point.latitude.toString(); // Wyświetlenie istniejącej szerokości geograficznej
      lngController.text = point.longitude.toString();
    }

     // Wyświetlanie okna dialogowego
    await showDialog(
      context: state.context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: latController,
                decoration: const InputDecoration(labelText: 'Szerokość geograficzna (lat)'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: lngController,
                decoration: const InputDecoration(labelText: 'Długość geograficzna (lng)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Anuluj'),
            ),
            TextButton(
              onPressed: () {
                state.setState(() {
                  final lat = double.tryParse(latController.text) ?? 0; // Parsowanie szerokości
                  final lng = double.tryParse(lngController.text) ?? 0;
 // Przypisanie współrzędnych w zależności od tytułu okna dialogowego
                  if (title == "Punkt początkowy") {
                    state.startPoint = LatLng(lat, lng);
                  } else if (title == "Punkt końcowy") {
                    state.endPoint = LatLng(lat, lng);
                  } else if (title == "Przystanek 1") {
                    state.stop1 = LatLng(lat, lng);
                  } else if (title == "Przystanek 2") {
                    state.stop2 = LatLng(lat, lng);
                  } else if (title == "Przystanek 3") {
                    state.stop3 = LatLng(lat, lng);
                  }
                });
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }