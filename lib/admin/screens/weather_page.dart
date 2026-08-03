import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../domain/weather_entity.dart';
import '../../domain/weather_repository.dart';
import '../../services/weather/weather_api_service.dart';
import '../../services/weather/weather_repository_impl.dart';
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

  @override
  void initState() {
    super.initState();
    final apiService = WeatherApiService(http.Client());
    _weatherRepository = WeatherRepositoryImpl(apiService: apiService);
    _loadWeather();
  }

  void _loadWeather() {
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

  void _showMetricInfoDialog({
    required String title,
    required String definition,
    required String farmingImpact,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        actionsPadding: const EdgeInsets.all(20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.info_outline_rounded, color: Color(0xFF059669), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "PALIWANAG",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.8),
            ),
            const SizedBox(height: 6),
            Text(definition, style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.4)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.eco_rounded, size: 16, color: Color(0xFF16A34A)),
                      SizedBox(width: 6),
                      Text(
                        "EPEKTO SA BUKID AT PAGSASAKA",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF16A34A), letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(farmingImpact, style: const TextStyle(fontSize: 13, color: Color(0xFF166534), height: 1.4)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("Naintindihan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "AGRI-WEATHER HUB",
              style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8),
            ),
            Text(
              locationName,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A), size: 20),
              onPressed: () => setState(() => _loadWeather()),
              tooltip: 'Refresh Weather',
            ),
          ),
        ],
      ),
      body: FutureBuilder<WeatherEntity>(
        future: _weatherFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF059669), strokeWidth: 3));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  const Text("Hindi maikonekta sa Weather API.", style: TextStyle(color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => setState(() => _loadWeather()),
                    child: const Text("Subukan Ulit", style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            );
          }

          final weather = snapshot.data!;
          final selectedDay = weather.forecast[_selectedDayIndex];

          WidgetsBinding.instance.addPostFrameCallback((_) {
            SystemControlHub().updateWeather('${weather.temperature.toStringAsFixed(1)}°C — ${weather.condition}');
          });

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 32 : 16,
                  vertical: 12,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🌤️ GOOGLE EMERALD HERO CARD (Responsive Layout)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isWide ? 32 : 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF047857), Color(0xFF059669), Color(0xFF10B981)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF059669).withOpacity(0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Text(
                                            'Live Weather Sync',
                                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '${weather.temperature.toStringAsFixed(1)}°',
                                            style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: Colors.white, height: 1),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          weather.condition,
                                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600, fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(_getWeatherIcon(weather.condition), size: isWide ? 88 : 64, color: const Color(0xFFFDE047)),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: isWide
                                    ? Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: _buildMetricsList(weather),
                                      )
                                    : GridView.count(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        crossAxisCount: 2,
                                        childAspectRatio: 2.5,
                                        mainAxisSpacing: 8,
                                        crossAxisSpacing: 8,
                                        children: _buildMetricsList(weather),
                                      ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 🌾 FARMING ADVISORIES SECTION
                        const Text(
                          "Farming Advisories & Operations",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Mga gabay at babala sa pagsasaka base sa kasalukuyang panahon:",
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 10),

                        _buildFarmingAdvisoryCard(weather),

                        const SizedBox(height: 24),

                        // 📅 7-DAY FORECAST
                        const Text('7-Day Forecast', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 115,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: weather.forecast.length,
                            itemBuilder: (context, index) {
                              final day = weather.forecast[index];
                              final isSelected = _selectedDayIndex == index;
                              String dayLabel = index == 0 ? 'Ngayon' : day.date.substring(5);

                              return GestureDetector(
                                onTap: () => setState(() => _selectedDayIndex = index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 76,
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF059669) : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                                      width: 1.5,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF059669).withOpacity(0.3),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            )
                                          ]
                                        : [],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        dayLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Icon(
                                        _getWeatherIcon(_mapCodeToString(day.weatherCode)),
                                        size: 24,
                                        color: isSelected ? Colors.white : const Color(0xFF0284C7),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${day.maxTemp.toStringAsFixed(0)}°C',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 🕒 HOURLY OUTLOOK
                        Text('Oras-oras na Panahon (${selectedDay.date})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: SizedBox(
                            height: 80,
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
                                      Text(rawTime, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Icon(_getWeatherIcon(_mapCodeToString(hourItem.weatherCode)), size: 20, color: const Color(0xFF0284C7)),
                                      const SizedBox(height: 8),
                                      Text('${hourItem.temp.toStringAsFixed(1)}°', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _buildMetricsList(WeatherEntity weather) {
    return [
      _buildInteractiveMetric(
        icon: Icons.thermostat_rounded,
        label: "Feels Like",
        value: "${weather.feelsLike}°C",
        onTap: () => _showMetricInfoDialog(
          title: "Feels Like Temperature",
          definition: "Ito ang aktwal na 'damang temperatura' ng katawan batay sa paghahalo ng tunay na init ng hangin, humidity, at hangin sa paligid.",
          farmingImpact: "Kapag sobrang taas nito kumpara sa totoong temperatura, mabilis ma-dehydrate ang mga magsasaka at ang mga punla sa bukid.",
        ),
      ),
      _buildInteractiveMetric(
        icon: Icons.water_drop_rounded,
        label: "Humidity",
        value: "${weather.humidity}%",
        onTap: () => _showMetricInfoDialog(
          title: "Relative Humidity (%)",
          definition: "Ito ang sukat ng dami ng singaw ng tubig sa hangin.",
          farmingImpact: "Ang mataas na humidity (>80%) ay lumilikha ng basang paligid na paboritong bahayan ng mga fungal at bacterial diseases sa palay.",
        ),
      ),
      _buildInteractiveMetric(
        icon: Icons.air_rounded,
        label: "Wind Speed",
        value: "${weather.windSpeed} km/h",
        onTap: () => _showMetricInfoDialog(
          title: "Wind Speed (Bilis ng Hangin)",
          definition: "Ito ang bilis ng galaw ng hangin sa iyong lugar.",
          farmingImpact: "Kapag malakas ang hangin (>15-20 km/h), hindi inirerekomenda ang pag-spray ng pestisidyo o abono.",
        ),
      ),
      _buildInteractiveMetric(
        icon: Icons.qr_code_rounded,
        label: "WMO Code",
        value: "${weather.weatherCode}",
        onTap: () => _showMetricInfoDialog(
          title: "WMO Weather Code",
          definition: "Numerong pamantayan ng World Meteorological Organization para sa pag-uuri ng estado ng panahon.",
          farmingImpact: "Awtomatikong binabasa ng ArrozSistema ang code na ito upang maglabas ng realtime alerts sa dashboard.",
        ),
      ),
    ];
  }

  Widget _buildInteractiveMetric({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmingAdvisoryCard(WeatherEntity weather) {
    final bool isRainy = weather.weatherCode >= 51 || weather.condition.toLowerCase().contains("rain") || weather.condition.toLowerCase().contains("storm");
    final bool isHot = weather.temperature >= 33.0;

    Color cardBg = const Color(0xFFF0FDF4);
    Color iconBg = const Color(0xFF059669);
    Color titleColor = const Color(0xFF065F46);
    Color bulletColor = const Color(0xFF059669);
    IconData advisoryIcon = Icons.check_circle_rounded;
    String advisoryTitle = "GOOD FARMING CONDITIONS ADVISORY";
    String advisorySub = "Maayos ang panahon. Inirerekomenda ang mga sumusunod na gawain sa bukid:";

    List<String> bullets = [
      "Ipagpatuloy ang regular na pag-inspeksyon sa kalagayan ng palay at patubig.",
      "Ligtas at angkop ang panahon para sa pag-spray ng kinakailangang abono o pestisidyo.",
      "Gamitin ang Alternate Wetting and Drying (AWD) technique para sa maayos na konserbasyon ng tubig.",
      "Subaybayan ang antas ng tubig sa mga kanal upang maiwasan ang pagkatuyo ng lupa.",
    ];

    if (isRainy) {
      cardBg = const Color(0xFFFFFBEB);
      iconBg = const Color(0xFFD97706);
      titleColor = const Color(0xFF92400E);
      bulletColor = const Color(0xFFD97706);
      advisoryIcon = Icons.warning_rounded;
      advisoryTitle = "WEATHER WARNING: ULAN AT SAMA NG PANAHON";
      advisorySub = "May banta ng ulan. Isagawa agad ang mga emergency measures sa bukid:";

      bullets = [
        "Siguraduhing maayos ang mga sasakyang pangkargada at may emergency supplies bago bumiyahe.",
        "Iseguro at takpan ng tarapal ang mga naaning palay, farm inputs, at kagamitan laban sa ulan.",
        "Iligpit at iangat ang mga abono, pestisidyo, at kemikal malayo sa maaabot ng baha at tubig.",
        "Linisin ang mga drainage canals sa bukid upang maiwasan ang pagkahinto at pag-apaw ng tubig.",
        "Gamitin ang rainwater harvesting (catchments/tanks) upang makatipid sa patubig sa bukid.",
        "Palagiang subaybayan ang official weather updates upang makaiwas sa matinding pinsala.",
      ];
    } else if (isHot) {
      cardBg = const Color(0xFFFFF7ED);
      iconBg = const Color(0xFFEA580C);
      titleColor = const Color(0xFF9A3412);
      bulletColor = const Color(0xFFEA580C);
      advisoryIcon = Icons.wb_sunny_rounded;
      advisoryTitle = "HEAT ADVISORY: MATINDING TIKAT NG ARAW";
      advisorySub = "Mataas ang temperatura. Sundin ang mga paalala para sa kalusugan at pananim:";

      bullets = [
        "Siguraduhing sapat ang tubig sa bukid upang maiwasan ang mabilis na pagkatuyo ng lupang taniman.",
        "Iwasan ang pagtatrabaho sa gitna ng bukid tuwing tanghaling-tapat (11 AM - 3 PM) upang makaiwas sa heat stroke.",
        "Siguraduhing may sapat na inuming tubig at pananggalang sa init (sumbrero/long sleeves) ang mga magsasaka.",
        "Iwasan muna ang pag-spray ng pestisidyo sa matinding sikat ng araw dahil mabilis itong mag-evaporate.",
      ];
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: bulletColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(advisoryIcon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      advisoryTitle,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: titleColor, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 2),
                    Text(advisorySub, style: TextStyle(fontSize: 11, color: titleColor.withOpacity(0.8))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...bullets.map((text) => _buildAdvisoryBullet(text, bulletColor)),
        ],
      ),
    );
  }

  Widget _buildAdvisoryBullet(String text, Color bulletColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 10),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: bulletColor,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), height: 1.4, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}