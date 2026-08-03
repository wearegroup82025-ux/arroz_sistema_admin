import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LogEntry {
  final String title;
  final String time;
  final String type; // 'info', 'success', 'warning'
  LogEntry({required this.title, required this.time, required this.type});
}

class SystemControlHub {
  // Singleton pattern
  static final SystemControlHub _instance = SystemControlHub._internal();
  factory SystemControlHub() => _instance;

  SystemControlHub._internal() {
    // Kusa nang mag-fe-fetch ng live weather sa pag-start pa lang ng app!
    fetchLiveWeather();
  }

  // --- WEATHER SYNC STREAM ---
  String _currentWeather = "Fetching Weather...";
  final _weatherController = StreamController<String>.broadcast();
  
  String get currentWeather => _currentWeather;
  Stream<String> get weatherStream => _weatherController.stream;

  void updateWeather(String newWeather) {
    _currentWeather = newWeather;
    _weatherController.add(newWeather);
  }

// Kopyahin ito sa loob ng system_control_hub.dart
String _getWeatherCondition(int code) {
  if (code == 0) return 'Clear Sky';
  if (code >= 1 && code <= 3) return 'Partly Cloudy';
  if (code == 45 || code == 48) return 'Foggy';
  if (code >= 51 && code <= 55) return 'Drizzle'; // 👈 Ito ang nagpabago mula Rainy -> Drizzle!
  if (code >= 56 && code <= 67) return 'Rainy';
  if (code >= 80 && code <= 82) return 'Showers';
  if (code >= 95) return 'Thunderstorm';
  return 'Sunny';
}

  // DIRECT API FETCH PARA SA ADMIN DASHBOARD (Pampanga Coordinates: 14.9540, 120.7594)
  Future<void> fetchLiveWeather({double lat = 14.9540, double lon = 120.7594}) async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,weather_code&timezone=Asia/Manila',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        final currentData = data['current'];
        if (currentData != null) {
          final double tempDouble = (currentData['temperature_2m'] as num).toDouble();
          final String temp = tempDouble.toStringAsFixed(1); // Ginawang 1 decimal point para parehong-pareho sa WeatherPage
          final int weatherCode = (currentData['weather_code'] as num).toInt();

          final String condition = _getWeatherCondition(weatherCode);
          final String formattedWeather = "$temp°C — $condition";

          updateWeather(formattedWeather);
        }
      } else {
        updateWeather("28.0°C — Partly Cloudy");
      }
    } catch (e) {
      print("Error fetching weather in SystemControlHub: $e");
      updateWeather("28.0°C — Partly Cloudy");
    }
  }

  // --- TELEMETRY LOGS STREAM ---
  final List<LogEntry> _logs = [
    LogEntry(title: "System initialized. Monitoring all active supply chains.", time: "Just now", type: "info"),
    LogEntry(title: "All synchronized farm hubs reporting optimal metrics.", time: "5m ago", type: "success"),
  ];
  
  final _logsController = StreamController<List<LogEntry>>.broadcast();

  List<LogEntry> get currentLogs => List.unmodifiable(_logs);
  Stream<List<LogEntry>> get logsStream => _logsController.stream;

  void addLog(String title, String type) {
    _logs.insert(0, LogEntry(title: title, time: "Just now", type: type));
    if (_logs.length > 8) _logs.removeLast();
    _logsController.add(List.from(_logs));
  }
}