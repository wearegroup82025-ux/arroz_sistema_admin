import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/weather_model.dart';

class WeatherApiService {
  final http.Client _client;

  WeatherApiService(this._client);

  Future<WeatherModel> fetchRawWeather(double lat, double lon) async {
    // Kinumpleto ang request parameters para makuha ang oras-oras na temperatura at codes para sa 7 araw
  final url = Uri.parse(
  'https://api.open-meteo.com/v1/forecast'
  '?latitude=$lat'
  '&longitude=$lon'
  '&current='
  'temperature_2m,'
  'apparent_temperature,'
  'relative_humidity_2m,'
  'wind_speed_10m,'
  'weather_code'
  '&hourly='
  'temperature_2m,'
  'weather_code'
  '&daily='
  'weather_code,'
  'temperature_2m_max,'
  'temperature_2m_min,'
  'precipitation_sum,'
  'precipitation_probability_max,'
  'wind_speed_10m_max'
  '&forecast_days=7'
  '&timezone=Asia/Manila',
);

    try {
      final response = await _client.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return WeatherModel.fromJson(data);
      } else {
        throw Exception('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network connection failed: $e');
    }
  }
}