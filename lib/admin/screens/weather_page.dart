import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../domain/weather_entity.dart';
import '../../domain/weather_repository.dart';
import '../../services/weather_api_service.dart';
import '../../services/weather_repository_impl.dart';
import 'system_control_hub.dart';

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  late final WeatherRepository _weatherRepository;
  late Future<WeatherEntity> _weatherFuture;

  static const double latitude = 14.9540;
  static const double longitude = 120.7594;
  static const String locationName = "Capalangan, Pampanga";

  int _selectedDayIndex = 0;
  bool _alertShown = false;

  @override
  void initState() {
    super.initState();
    final apiService = WeatherApiService(http.Client());
    _weatherRepository = WeatherRepositoryImpl(apiService: apiService);
    _loadWeather();
  }

  void _loadWeather() {
    _alertShown = false;
    _weatherFuture = _weatherRepository.getWeatherByCoordinates(latitude, longitude);
  }

  IconData _getWeatherIcon(String condition) {
    final text = condition.toLowerCase();
    if (text.contains("rain") || text.contains("drizzle")) return Icons.grain_rounded;
    if (text.contains("thunder") || text.contains("storm")) return Icons.thunderstorm_rounded;
    if (text.contains("cloud")) return Icons.cloud_rounded;
    if (text.contains("clear") || text.contains("sun")) return Icons.wb_sunny_rounded;
    return Icons.wb_cloudy_rounded;
  }

  String _mapCodeToString(int code) {
    if (code > 0 && code <= 3) return 'cloud';
    if (code >= 51 && code <= 67) return 'rain';
    if (code >= 95) return 'storm';
    return 'clear';
  }

  void _checkAndShowSevereWeatherAlert(WeatherEntity weather) {
    if (_alertShown) return;

    final bool isSevere = weather.weatherCode >= 61 || 
                          (weather.alertMessage != null && weather.alertMessage!.isNotEmpty);

    if (isSevere) {
      _alertShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            elevation: 2,
            backgroundColor: const Color(0xFF7F1D1D),
            leading: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "BABALA SA MASAMANG PANAHON",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  weather.alertMessage ?? "May banta ng malakas na ulan o bagyo. Protektahan ang patubig at pananim.",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
                child: const Text("OK", style: TextStyle(color: Color(0xFFFDE047), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Ecosystem Weather", style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w500)),
            Text(locationName, style: TextStyle(color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            style: IconButton.styleFrom(backgroundColor: const Color(0xFFF1F5F9)),
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF334155), size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              setState(() => _loadWeather());
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: FutureBuilder<WeatherEntity>(
        future: _weatherFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A), strokeWidth: 3));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFEF4444)),
                    const SizedBox(height: 12),
                    Text("Hindi maikonekta sa Weather Service: ${snapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text("Walang available na weather data.", style: TextStyle(color: Color(0xFF64748B))));
          }

          final weather = snapshot.data!;
          final selectedDay = weather.forecast[_selectedDayIndex];

          _checkAndShowSevereWeatherAlert(weather);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            final formattedWeather = '${weather.temperature.toStringAsFixed(1)}°C — ${weather.condition}';
            SystemControlHub().updateWeather(formattedWeather);
          });

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🛑 ALERT BANNER CARD
                if (weather.alertMessage != null && weather.alertMessage!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            weather.alertMessage!,
                            style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 🌤️ SMOOTH HERO CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text('Live Weather', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
                              ),
                              const SizedBox(height: 8),
                              Text('${weather.temperature.toStringAsFixed(1)}°C', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
                              const SizedBox(height: 4),
                              Text(weather.condition, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w600, fontSize: 15)),
                            ],
                          ),
                          Icon(_getWeatherIcon(weather.condition), size: 64, color: const Color(0xFFF59E0B)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMetricItem(Icons.thermostat_rounded, "Feels Like", "${weather.feelsLike}°C"),
                          _buildMetricItem(Icons.water_drop_rounded, "Humidity", "${weather.humidity}%"),
                          _buildMetricItem(Icons.thunderstorm_rounded, "Code", "${weather.weatherCode}"),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 📅 SMOOTH 7-DAY SELECTOR
                const Text('7-Day Forecast', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 10),
                SizedBox(
                  height: 95,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: weather.forecast.length,
                    itemBuilder: (context, index) {
                      final day = weather.forecast[index];
                      final isSelected = _selectedDayIndex == index;
                      String dayLabel = index == 0 ? 'Today' : day.date.substring(5);

                      return GestureDetector(
                        onTap: () => setState(() => _selectedDayIndex = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 76,
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF16A34A) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0)),
                            boxShadow: isSelected
                                ? [BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(dayLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF64748B))),
                              const SizedBox(height: 4),
                              Icon(_getWeatherIcon(_mapCodeToString(day.weatherCode)), size: 20, color: isSelected ? Colors.white : const Color(0xFF0EA5E9)),
                              const SizedBox(height: 4),
                              Text('${day.maxTemp.toStringAsFixed(0)}°C', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF1E293B))),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // 🕒 HOURLY TIMELINE
                Text('Hourly Outlook (${selectedDay.date})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: SizedBox(
                    height: 75,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: selectedDay.hourlyData.length,
                      itemBuilder: (context, hIndex) {
                        final hourItem = selectedDay.hourlyData[hIndex];
                        String rawTime = hourItem.time.length >= 16 ? hourItem.time.substring(11, 16) : hourItem.time;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(rawTime, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Icon(_getWeatherIcon(_mapCodeToString(hourItem.weatherCode)), size: 18, color: const Color(0xFF0284C7)),
                              const SizedBox(height: 6),
                              Text('${hourItem.temp.toStringAsFixed(1)}°', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF38BDF8), size: 18),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}