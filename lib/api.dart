import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const String baseUrl =
    'https://api.openrouteservice.org/v2/directions/'; //generowanie trasy
const String baseUrl2 =
    'https://api.openrouteservice.org/geocode/reverse'; //współrzędnae na adres
const String apiKey =
    '5b3ce3597851110001cf6248f55d7a31499e40848c6848d7de8fa6248f';
const String apiKey2 =
    '5b3ce3597851110001cf6248d62e8dbe4aac4352890577b585a0a3e6';

/// Funkcja generująca URL dla wybranego profilu (typu roweru)
Uri getRouteUrl(String profile, String startPoint, String endPoint) {
  return Uri.parse(
      '$baseUrl$profile?api_key=$apiKey&start=$startPoint&end=$endPoint');
}

/// Funkcja do geokodowania wstecznego (zamiana współrzędnych na adres)
Future<String> reverseGeocode(double latitude, double longitude) async {
  // URL API geokodowania wstecznego
  try {
    final uri = Uri.parse(
        '$baseUrl2?api_key=$apiKey2&point.lon=$longitude&point.lat=$latitude');

    final response = await http.get(uri);

    checkResponseCode(response);

    var data = jsonDecode(response.body);

    if (data['features'] == null || data['features'].isEmpty) {
      throw Exception('Adres nieznany');
    }

    var address = data['features'][0]['properties']['label'];
    return address;
  } on HttpException catch (e) {
    return 'Błąd odpowiedzi: $e';
  } on Exception catch (e) {
    return '$e';
  } catch (e) {
    return 'Niespodziewany błąd: $e.message';
  }
}

void checkResponseCode(http.Response response) {
  if (response.statusCode != 200) {
    throw HttpException(
      '${response.statusCode}, body: ${response.body}',
    );
  }
}
