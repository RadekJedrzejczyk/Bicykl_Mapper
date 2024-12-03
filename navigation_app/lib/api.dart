const String baseUrl = 'https://api.openrouteservice.org/v2/directions/';
const String apiKey = '5b3ce3597851110001cf6248f55d7a31499e40848c6848d7de8fa624';

/// Funkcja generująca URL dla wybranego profilu (typu roweru)
Uri getRouteUrl(String profile, String startPoint, String endPoint) {
  return Uri.parse('$baseUrl$profile?api_key=$apiKey&start=$startPoint&end=$endPoint');
}