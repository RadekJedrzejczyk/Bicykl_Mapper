import 'dart:convert';
import 'package:http/http.dart' as http;


const String apiKey2 = '5b3ce3597851110001cf6248d62e8dbe4aac4352890577b585a0a3e6';
const String baseUrl = 'https://api.openrouteservice.org/v2/directions/';
const String baseUrl2 = 'https://api.openrouteservice.org/geocode/reverse';
const String apiKey = '5b3ce3597851110001cf6248f55d7a31499e40848c6848d7de8fa6248f';

/// Funkcja generująca URL dla wybranego profilu (typu roweru)
Uri getRouteUrl(String profile, String startPoint, String endPoint) {
  return Uri.parse('$baseUrl$profile?api_key=$apiKey&start=$startPoint&end=$endPoint');
}

/// Funkcja do geokodowania wstecznego (zamiana współrzędnych na adres)
Future<String> reverseGeocode(double latitude, double longitude) async {
  // URL API geokodowania wstecznego
  final uri = Uri.parse('$baseUrl2?api_key=$apiKey2&point.lon=$longitude&point.lat=$latitude');

  final response = await http.get(uri);

  if (response.statusCode == 200) {
    var data = jsonDecode(response.body);

    if (data['features'] != null && data['features'].isNotEmpty) {
      var address = data['features'][0]['properties']['label'];
      return address; // Zwracamy adres
    } else {
      return 'Adres nieznany';
    }
  } else {
    throw Exception('Nie udało się pobrać adresu');
  }
}
