import 'dart:async';

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
  SystemControlHub._internal();

  // --- WEATHER SYNC STREAM ---
  String _currentWeather = "29°C — Mostly Sunny";
  final _weatherController = StreamController<String>.broadcast();
  
  String get currentWeather => _currentWeather;
  Stream<String> get weatherStream => _weatherController.stream;

  void updateWeather(String newWeather) {
    _currentWeather = newWeather;
    _weatherController.add(newWeather);
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
    if (_logs.length > 8) _logs.removeLast(); // Limit para hindi bumagal ang UI
    _logsController.add(List.from(_logs));
  }
}