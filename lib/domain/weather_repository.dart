import 'weather_entity.dart';

abstract class WeatherRepository {
  Future<WeatherEntity> getWeatherByCoordinates(double lat, double lon);
}