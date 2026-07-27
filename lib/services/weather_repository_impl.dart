import '../domain/weather_entity.dart';
import '../domain/weather_repository.dart';
import 'weather_api_service.dart';

class WeatherRepositoryImpl implements WeatherRepository {
  final WeatherApiService apiService;

  WeatherRepositoryImpl({required this.apiService});

  @override
  Future<WeatherEntity> getWeatherByCoordinates(double lat, double lon) async {
    // Kukunin ang magaspang na data mula sa internet via service
    final rawModel = await apiService.fetchRawWeather(lat, lon);

    // Dahil si WeatherModel ay isang WeatherEntity na rin, 
    // pwede na natin itong ibalik nang direkta! Kasama na ang forecast array nito.
    return rawModel;
  }
}