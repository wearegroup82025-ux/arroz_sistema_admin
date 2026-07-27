import '../domain/weather_entity.dart';

class WeatherModel extends WeatherEntity {
  WeatherModel({
    required super.temperature,
    required super.feelsLike,
    required super.humidity,
    required super.condition,
    required super.weatherCode,
    super.alertMessage,
    required super.forecast,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>? ?? {};
    final daily = json['daily'] as Map<String, dynamic>? ?? {};
    final hourly = json['hourly'] as Map<String, dynamic>? ?? {};
    
    final currentWeatherCode = current['weather_code'] as int? ?? 0;
    
    // --- WEATHER ALERT LOGIC ---
    String? systemAlert;
    if (currentWeatherCode >= 95) {
      systemAlert = "⚠️ EMERGENCY WARNING: May paparating o kasalukuyang may BAGYO / THUNDERSTORM sa inyong lugar. Manatili sa ligtas na lugar!";
    } else if (currentWeatherCode == 65 || currentWeatherCode == 67 || currentWeatherCode == 82) {
      systemAlert = "🌧️ WEATHER ALERT: Inaasahan ang MALAKAS NA ULAN ngayon. Mag-ingat sa banta ng baha o madulas na kalsada.";
    }

    // --- HOURLY RAW DATA MASTER LIST (168 hours total for 7 days) ---
    final List<dynamic> hourlyTimes = hourly['time'] as List<dynamic>? ?? [];
    final List<dynamic> hourlyTemps = hourly['temperature_2m'] as List<dynamic>? ?? [];
    final List<dynamic> hourlyCodes = hourly['weather_code'] as List<dynamic>? ?? [];

    // --- DAILY & SEGREGATED HOURLY PARSING ---
    final List<dynamic> dailyDates = daily['time'] as List<dynamic>? ?? [];
    final List<dynamic> maxTemps = daily['temperature_2m_max'] as List<dynamic>? ?? [];
    final List<dynamic> minTemps = daily['temperature_2m_min'] as List<dynamic>? ?? [];
    final List<dynamic> dailyCodes = daily['weather_code'] as List<dynamic>? ?? [];

    List<DailyForecastEntity> dailyList = [];

    for (int i = 0; i < dailyDates.length; i++) {
      // Kumuha ng 24 na pirasong oras na tumatapat sa kasalukuyang araw (i * 24)
      List<HourlyForecastEntity> dayHourlyList = [];
      int startIndex = i * 24;
      int endIndex = startIndex + 24;

      if (endIndex <= hourlyTimes.length) {
        for (int h = startIndex; h < endIndex; h++) {
          dayHourlyList.add(HourlyForecastEntity(
            time: hourlyTimes[h].toString(),
            temp: (hourlyTemps[h] as num? ?? 0.0).toDouble(),
            weatherCode: hourlyCodes[h] as int? ?? 0,
          ));
        }
      }

      dailyList.add(DailyForecastEntity(
        date: dailyDates[i].toString(),
        maxTemp: (maxTemps[i] as num? ?? 0.0).toDouble(),
        minTemp: (minTemps[i] as num? ?? 0.0).toDouble(),
        weatherCode: dailyCodes[i] as int? ?? 0,
        hourlyData: dayHourlyList,
      ));
    }

    return WeatherModel(
      temperature: (current['temperature_2m'] as num? ?? 0.0).toDouble(),
      feelsLike: (current['apparent_temperature'] as num? ?? 0.0).toDouble(),
      humidity: (current['relative_humidity_2m'] as num? ?? 0).toInt(),
      condition: _mapWeatherCode(currentWeatherCode),
      weatherCode: currentWeatherCode,
      alertMessage: systemAlert,
      forecast: dailyList,
    );
  }

  static String _mapWeatherCode(int code) {
    if (code > 0 && code <= 3) return 'Partly Cloudy';
    if (code >= 45 && code <= 48) return 'Foggy';
    if (code >= 51 && code <= 67) return 'Rainy';
    if (code >= 71 && code <= 86) return 'Snowy';
    if (code >= 95) return 'Thunderstorm';
    return 'Sunny';
  }
}