class HourlyForecastEntity {
  final String time; // e.g., "2026-07-11T13:00"
  final double temp;
  final int weatherCode;

  HourlyForecastEntity({
    required this.time,
    required this.temp,
    required this.weatherCode,
  });
}

class DailyForecastEntity {
  final String date;
  final double maxTemp;
  final double minTemp;
  final int weatherCode;
  final List<HourlyForecastEntity> hourlyData; // Lahat ng oras para sa araw na ito

  DailyForecastEntity({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.weatherCode,
    required this.hourlyData,
  });
}

class WeatherEntity {
  final double temperature;
  final double feelsLike;
  final int humidity;
  final String condition;
  final int weatherCode; // Para sa realtime warning filtering
  final double? windSpeed; // <--- IDINAGDAG DITO
  final String? alertMessage; // Mensahe kung may bagyo o malakas na ulan
  final List<DailyForecastEntity> forecast;

  WeatherEntity({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.condition,
    required this.weatherCode,
    this.windSpeed, // <--- IDINAGDAG DITO
    this.alertMessage,
    required this.forecast,
  });
}