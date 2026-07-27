class WeatherRecommendationService {
  static String getRecommendation({
    required String description,
    required double temperature,
    required double windSpeed,
  }) {
    final weather = description.toLowerCase();

    if (weather.contains("thunderstorm")) {
      return "⛈ Thunderstorm expected. Delay harvesting and secure farm equipment.";
    }

    if (weather.contains("rain")) {
      return "🌧 Rain expected. Avoid drying rice outdoors today.";
    }

    if (temperature >= 35) {
      return "🌡 High temperature. Monitor stored rice to avoid heat damage.";
    }

    if (windSpeed >= 10) {
      return "💨 Strong winds detected. Secure lightweight farm equipment.";
    }

    return "☀ Weather conditions are favorable for harvesting and drying rice.";
  }

  static String getAlert(String description) {
    final weather = description.toLowerCase();

    if (weather.contains("thunderstorm")) {
      return "⚠ Thunderstorm Warning";
    }

    if (weather.contains("rain")) {
      return "⚠ Rain Expected";
    }

    if (weather.contains("drizzle")) {
      return "⚠ Light Rain Expected";
    }

    if (weather.contains("clear")) {
      return "✅ Fair Weather";
    }

    if (weather.contains("cloud")) {
      return "☁ Cloudy Weather";
    }

    return "Normal Weather";
  }
}