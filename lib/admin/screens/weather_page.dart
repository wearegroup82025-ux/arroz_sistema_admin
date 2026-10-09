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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        actionsPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.info_outline_rounded, color: Color(0xFF059669), size: 26),
            ),
            const SizedBox(width: 12),
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
              "ANO ITO?",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
            ),
            const SizedBox(height: 4),
            Text(definition, style: const TextStyle(fontSize: 15, color: Color(0xFF334155), height: 1.4)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.eco_rounded, size: 18, color: Color(0xFF16A34A)),
                      SizedBox(width: 6),
                      Text(
                        "EPEKTO SA BUKID AT TANIM",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(farmingImpact, style: const TextStyle(fontSize: 14, color: Color(0xFF166534), height: 1.4)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("Naintindihan Ko", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "ULAT PANAHON SA BUKID",
              style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            Text(
              locationName,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.bold),
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
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A), size: 22),
              onPressed: () => setState(() => _loadWeather()),
              tooltip: 'I-update ang Panahon',
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
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 56, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    const Text(
                      "Hindi makuha ang ulat ng panahon ngayon. Paki-check ang internet connection.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => setState(() => _loadWeather()),
                      child: const Text("Subukan Ulit", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
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
                        // 🌤️ WEATHER MAIN CARD
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isWide ? 28 : 18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF047857), Color(0xFF059669), Color(0xFF10B981)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: const Text(
                                            'Kasalukuyang Panahon',
                                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '${weather.temperature.toStringAsFixed(1)}°C',
                                            style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold, color: Colors.white, height: 1),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          weather.condition,
                                          style: TextStyle(color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w600, fontSize: 18),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(_getWeatherIcon(weather.condition), size: isWide ? 80 : 68, color: const Color(0xFFFDE047)),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(18),
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
                                        childAspectRatio: 2.2,
                                        mainAxisSpacing: 8,
                                        crossAxisSpacing: 8,
                                        children: _buildMetricsList(weather),
                                      ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 🌾 MGA PAYO SA BUKID
                        const Text(
                          "Mga Payo sa Pagsasaka",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Mga dapat gawain sa bukid ayon sa lagay ng panahon ngayon:",
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 10),

                        _buildFarmingAdvisoryCard(weather),

                        const SizedBox(height: 24),

                        // 📅 PANAHON SA SUSUNOD NA 7 ARAW
                        const Text('Panahon sa Susunod na 7 Araw', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 125,
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
                                  width: 82,
                                  margin: const EdgeInsets.only(right: 10),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF059669) : Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                                      width: 1.5,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF059669).withOpacity(0.3),
                                              blurRadius: 8,
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
                                          fontSize: 13,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Icon(
                                        _getWeatherIcon(_mapCodeToString(day.weatherCode)),
                                        size: 26,
                                        color: isSelected ? Colors.white : const Color(0xFF0284C7),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${day.maxTemp.toStringAsFixed(0)}°C',
                                        style: TextStyle(
                                          fontSize: 14,
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

                        // 🕒 ORAS-ORAS NA PANAHON
                        Text('Oras-oras na Panahon (${selectedDay.date})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: SizedBox(
                            height: 85,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: selectedDay.hourlyData.length,
                              itemBuilder: (context, hIndex) {
                                final hourItem = selectedDay.hourlyData[hIndex];
                                String rawTime = hourItem.time.length >= 16 ? hourItem.time.substring(11, 16) : hourItem.time;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(rawTime, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Icon(_getWeatherIcon(_mapCodeToString(hourItem.weatherCode)), size: 22, color: const Color(0xFF0284C7)),
                                      const SizedBox(height: 6),
                                      Text('${hourItem.temp.toStringAsFixed(1)}°', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
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
        label: "feels like",
        value: "${weather.feelsLike}°C",
        onTap: () => _showMetricInfoDialog(
          title: "Temperatura (Feels Like)",
          definition: "Ito ang tunay na init na nararamdaman sa balat dahil sa pinagsamang init ng araw at hangin.",
          farmingImpact: "Kapag mataas ito, mabilis mapagod ang nagtatrabaho sa bukid at mabilis matuyuan ang mga tanim.",
        ),
      ),
      _buildInteractiveMetric(
        icon: Icons.water_drop_rounded,
        label: "Alinsangan",
        value: "${weather.humidity}%",
        onTap: () => _showMetricInfoDialog(
          title: "Alinsangan / Humidity",
          definition: "Ito ang dami ng lambong o ambon sa hangin sa paligid.",
          farmingImpact: "Kapag mataas ang alinsangan (lampas 80%), mabilis kumalat ang mga peste at sakit sa dahon ng palay.",
        ),
      ),
      _buildInteractiveMetric(
        icon: Icons.air_rounded,
        label: "Wind Speed",
        value: "${weather.windSpeed} km/h",
        onTap: () => _showMetricInfoDialog(
          title: "Wind Speed",
          definition: "Ito kung gaano kalakas ang hampas ng hangin sa bukid.",
          farmingImpact: "Kapag malakas ang hangin (lampas 15-20 km/h), huwag muna mag-spray ng abono o gamot dahil tatangayin lang ito.",
        ),
      ),
      _buildInteractiveMetric(
        icon: Icons.qr_code_rounded,
        label: "Weather Code",
        value: "${weather.weatherCode}",
        onTap: () => _showMetricInfoDialog(
          title: "Weather Code (WMO)",
          definition: "Koda ng mga eksperto para malaman kung maulan, maaraw, o may bagyo.",
          farmingImpact: "Kusa itong binabasa ng system para magbigay ng paalala kung ano ang magandang gawin sa bukid.",
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
                Icon(icon, color: Colors.white, size: 15),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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
    String advisoryTitle = "MAGANDA ANG PANAHON SA BUKID";
    String advisorySub = "Maayos ang panahon ngayon. Magandang magtrabaho sa bukid at sundin ang mga ito:";

    List<String> bullets = [
      "I-check ang patubig at ang lagay ng mga tanim na palay.",
      "Ligtas at magandang mag-spray ng abono o gamot sa tanim ngayon.",
      "Gumamit ng Alternate Wetting and Drying (AWD) para makatipid sa patubig.",
      "Bantayan ang tubig sa mga kanal para hindi matuyuan ang lupa.",
    ];

    if (isRainy) {
      cardBg = const Color(0xFFFFFBEB);
      iconBg = const Color(0xFFD97706);
      titleColor = const Color(0xFF92400E);
      bulletColor = const Color(0xFFD97706);
      advisoryIcon = Icons.warning_rounded;
      advisoryTitle = "BABALA: MAY ULAN O SAMA NG PANAHON";
      advisorySub = "May banta ng ulan. Gawin agad ang mga pag-iingat na ito sa bukid:";

      bullets = [
        "Siguraduhing maayos ang sasakyan at may baong gamit bago bumiyahe.",
        "Takpan agad ng tarapal ang mga naaning palay, abono, at mga kagamitan para hindi mabasa.",
        "Iligpit at iangat sa mataas na lugar ang mga abono at gamot para hindi maabot ng baha.",
        "Linisin ang mga patubigan at kanal para mabilis na dumaloy ang tubig at hindi magbaha.",
        "Mag-ipon ng tubig-ulan sa mga drum o tangke para magamit na patubig sa susunod.",
        "Palaging mag-check ng ulat-panahon para maiwasan ang pinsala sa tanim.",
      ];
    } else if (isHot) {
      cardBg = const Color(0xFFFFF7ED);
      iconBg = const Color(0xFFEA580C);
      titleColor = const Color(0xFF9A3412);
      bulletColor = const Color(0xFFEA580C);
      advisoryIcon = Icons.wb_sunny_rounded;
      advisoryTitle = "BABALA: MATINDING SIKAT NG ARAW AT INIT";
      advisorySub = "Mataas ang temperatura. Sundin ang mga payong ito para sa inyong kalusugan at tanim:";

      bullets = [
        "Siguraduhing may sapat na tubig ang bukid para hindi mabilis matuyo ang lupa.",
        "Iwasang magtrabaho sa bukid tuwing tanghaling-tapat (11 AM hanggang 3 PM) para maiwasan ang heat stroke.",
        "Magbaon ng sapat na inuming tubig at magsuot ng sumbrero at long sleeves.",
        "Huwag muna mag-spray ng gamot habang matindi ang sikat ng araw dahil mabilis lang itong matutuyo at masayang.",
      ];
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(advisoryIcon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      advisoryTitle,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor),
                    ),
                    const SizedBox(height: 2),
                    Text(advisorySub, style: TextStyle(fontSize: 12, color: titleColor.withOpacity(0.9))),
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
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: bulletColor,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), height: 1.4, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}