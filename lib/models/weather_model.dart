import '../domain/weather_entity.dart';

class WeatherModel extends WeatherEntity {
  WeatherModel({
  required super.temperature,
  required super.feelsLike,
  required super.humidity,
  required super.condition,
  required super.weatherCode,
  super.windSpeed,
  super.alertMessage,
  required super.forecast,
});
  static bool isRain(int code) {
  return code >= 51 && code <= 82;
}

static bool isStorm(int code) {
  return code >= 95;
}

static bool isSunny(int code) {
  return code == 0;
}

static bool isCloudy(int code) {
  return code >= 1 && code <= 3;
}
  


  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>? ?? {};
    final daily = json['daily'] as Map<String, dynamic>? ?? {};
    final hourly = json['hourly'] as Map<String, dynamic>? ?? {};
    final currentWeatherCode = current['weather_code'] as int? ?? 0;
    final rainfall =
    daily['precipitation_sum'] as List<dynamic>? ?? [];

    final rainProbability =
    daily['precipitation_probability_max'] as List<dynamic>? ?? [];

    final windSpeed =
    daily['wind_speed_10m_max'] as List<dynamic>? ?? [];   
    
    
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

     dailyList.add(
  DailyForecastEntity(
    date: dailyDates[i].toString(),

    maxTemp: (maxTemps[i] as num? ?? 0).toDouble(),

    minTemp: (minTemps[i] as num? ?? 0).toDouble(),

    weatherCode: dailyCodes[i] as int? ?? 0,

    rainfall: (rainfall[i] as num? ?? 0).toDouble(),

    rainProbability:
        (rainProbability[i] as num? ?? 0).toDouble(),

    windSpeed:
        (windSpeed[i] as num? ?? 0).toDouble(),

    hourlyData: dayHourlyList,
  ),
);
    }

    return WeatherModel(
  temperature: (current['temperature_2m'] as num? ?? 0).toDouble(),
  feelsLike: (current['apparent_temperature'] as num? ?? 0).toDouble(),
  humidity: (current['relative_humidity_2m'] as num? ?? 0).toInt(),
  condition: _mapWeatherCode(currentWeatherCode),
  weatherCode: currentWeatherCode,
  windSpeed: (current['wind_speed_10m'] as num? ?? 0).toDouble(),
  alertMessage: systemAlert,
  forecast: dailyList,
);
  }

 static String _mapWeatherCode(int code) {
  switch (code) {
    case 0:
      return "Clear";

    case 1:
    case 2:
    case 3:
      return "Partly Cloudy";

    case 45:
    case 48:
      return "Fog";

    case 51:
    case 53:
    case 55:
      return "Drizzle";

    case 61:
    case 63:
    case 65:
      return "Rain";

    case 66:
    case 67:
      return "Freezing Rain";

    case 71:
    case 73:
    case 75:
      return "Snow";

    case 80:
    case 81:
    case 82:
      return "Rain Showers";

    case 95:
    case 96:
    case 99:
      return "Thunderstorm";

    default:
      return "Unknown";
  }
}
}