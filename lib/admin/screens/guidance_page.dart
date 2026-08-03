import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Rice Variety Preset Structure
class RiceVariety {
  final String name;
  final int totalMaturityDays;
  final String description;

  const RiceVariety(this.name, this.totalMaturityDays, this.description);

  Map<String, dynamic> toJson() => {
        'name': name,
        'totalMaturityDays': totalMaturityDays,
        'description': description,
      };

  factory RiceVariety.fromJson(Map<String, dynamic> json) {
    return RiceVariety(
      json['name'] ?? 'Standard Inbred (e.g., Rc 222)',
      json['totalMaturityDays'] ?? 115,
      json['description'] ?? '',
    );
  }
}

const List<RiceVariety> kRiceVarieties = [
  RiceVariety('Standard Inbred (e.g., Rc 222)', 115, 'Karaniwang binhi na umaani sa loob ng 115 araw.'),
  RiceVariety('Early Maturing (e.g., Rc 192)', 105, 'Mabilis anihin (100-108 araw), mainam sa maikling tag-ulan.'),
  RiceVariety('Medium Maturing (e.g., Rc 216)', 112, 'Katamtamang panahon ng pag-ani (110-115 araw).'),
  RiceVariety('Late / Hybrid Rice', 125, 'Matagal anihin (120+ araw) ngunit may mataas na potensyal sa ani.'),
];

/// Data Model para sa Crop History Record
class PlantingRecord {
  final String id;
  final DateTime plantingDate;
  final RiceVariety variety;
  final bool isDirectSeeded;
  final DateTime estimatedHarvestDate;

  PlantingRecord({
    required this.id,
    required this.plantingDate,
    required this.variety,
    required this.isDirectSeeded,
    required this.estimatedHarvestDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'plantingDate': plantingDate.toIso8601String(),
        'variety': variety.toJson(),
        'isDirectSeeded': isDirectSeeded,
        'estimatedHarvestDate': estimatedHarvestDate.toIso8601String(),
      };

  factory PlantingRecord.fromJson(Map<String, dynamic> json) {
    return PlantingRecord(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      plantingDate: DateTime.parse(json['plantingDate']),
      variety: RiceVariety.fromJson(json['variety']),
      isDirectSeeded: json['isDirectSeeded'] ?? false,
      estimatedHarvestDate: DateTime.parse(json['estimatedHarvestDate']),
    );
  }
}

/// Siyentipikong Yugto ng Palay batay sa PhilRice PalayCheck System
enum RiceStage {
  preparation(
    'Paghahanda (Pre-Planting)',
    Icons.engineering_rounded,
    'PhilRice Prep: Seed Prep & Land Cultivation',
  ),
  planning(
    'Pagtatapos ng Pagpapatag',
    Icons.calendar_month_rounded,
    'PhilRice Key Check 1: Seed Selection & Land Prep',
  ),
  vegetative(
    'Pagsusuwi (Vegetative)',
    Icons.grass_rounded,
    'PhilRice Key Check 2 & 3: Nutrient & Water Management',
  ),
  reproductive(
    'Paglilihi & Pagbulaklak',
    Icons.eco_rounded,
    'PhilRice Key Check 4: Critical Crop Care',
  ),
  ripening(
    'Pagkahinog ng Butil',
    Icons.grain_rounded,
    'PhilRice Key Check 5: Water Drainage',
  ),
  harvesting(
    'Pag-aani & Post-Harvest',
    Icons.inventory_2_rounded,
    'PhilRice Key Check 6: Safe Storage & Market',
  );

  final String label;
  final IconData icon;
  final String standardRef;

  const RiceStage(this.label, this.icon, this.standardRef);
}

class GuidancePage extends StatefulWidget {
  const GuidancePage({super.key});

  @override
  State<GuidancePage> createState() => _GuidancePageState();
}

class _GuidancePageState extends State<GuidancePage> {
  // Configurable Crop State
  DateTime? _plantingDate;
  int _cropAgeDays = 0;
  bool _isFuturePlanting = false;
  int _daysUntilPlanting = 0;

  RiceVariety _selectedVariety = kRiceVarieties[0];
  bool _isDirectSeeded = false;
  RiceStage _selectedStage = RiceStage.planning;

  // History State
  List<PlantingRecord> _plantingHistory = [];

  // Weather State
  bool _isLoadingWeather = true;
  double? _currentTemp;
  int? _weatherCode;
  String _realtimeAdvisory = "Kina-kalkula ang datos ng panahon at araw ng tanim...";

  // Task Checklist Tracking State
  Map<String, bool> _completedTasks = {};

  // Calendar View State
  DateTime _focusedCalendarMonth = DateTime.now();

  static const double capalanganLat = 14.9540;
  static const double capalanganLng = 120.7594;

  @override
  void initState() {
    super.initState();
    _loadSavedData().then((_) {
      _updateCropAgeAndStage();
      _fetchRealtimeWeather();
    });
  }

  // --- PHILRICE CAPALANGAN SMART SUITABILITY MATRIX ---
  Map<String, dynamic> _getPhilriceCapalanganSuitability(DateTime date) {
    final month = date.month;

    if (month == 6 || month == 7) {
      return {
        "status": "GREEN",
        "color": const Color(0xFF16A34A),
        "label": "Napakaganda Magtanim 🌾",
        "reason": "BAKIT MAGANDA: Tamang-tama ang simula ng tag-ulan para sa Wet Season. May sapat at tuloy-tuloy na patubig mula sa ulan para sa pagpapatag at pagsusuwi ng palay.",
      };
    } else if (month == 11 || month == 12) {
      return {
        "status": "GREEN",
        "color": const Color(0xFF16A34A),
        "label": "Napakaganda Magtanim (Dry Crop) ☀️",
        "reason": "BAKIT MAGANDA: Mainam ang sikat ng araw sa Dry Season at mababa ang banta ng bagyo. Mas mataas ang ani basta't may maayos na patubig mula sa canal.",
      };
    } else if (month == 1 || month == 5) {
      return {
        "status": "YELLOW",
        "color": const Color(0xFFD97706),
        "label": "Pwede Magtanim (Katamtaman) ⚠️",
        "reason": "BAKIT DILAW: Nasa transition period ang panahon. Pwede magtanim pero kailangan ng maingat na pamamahala sa tubig.",
      };
    } else if (month >= 8 && month <= 10) {
      return {
        "status": "RED",
        "color": const Color(0xFFDC2626),
        "label": "Huwag Muna Magtanim (Mataas ang Risk) 🚨",
        "reason": "BAKIT HINDI MAGANDA: Peak season ng mga bagyo at matinding pag-ulan. Mataas ang posibilidad na mabaha ang palayan.",
      };
    } else {
      return {
        "status": "RED",
        "color": const Color(0xFFDC2626),
        "label": "Huwag Muna Magtanim (Tag-tuyot) ☀️",
        "reason": "BAKIT HINDI MAGANDA: Peak ng tag-init. Mabilis matuyo ang irrigation canals at maaring magkulang sa tubig ang palay.",
      };
    }
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();

    final savedDateStr = prefs.getString('guidance_planting_date');
    if (savedDateStr != null) {
      _plantingDate = DateTime.tryParse(savedDateStr);
    }

    final varietyIndex = prefs.getInt('guidance_variety_index') ?? 0;
    if (varietyIndex >= 0 && varietyIndex < kRiceVarieties.length) {
      _selectedVariety = kRiceVarieties[varietyIndex];
    }

    _isDirectSeeded = prefs.getBool('guidance_is_direct_seeded') ?? false;

    final historyJson = prefs.getString('guidance_planting_history');
    if (historyJson != null) {
      try {
        final List<dynamic> decoded = json.decode(historyJson);
        _plantingHistory = decoded.map((e) => PlantingRecord.fromJson(e)).toList();
      } catch (_) {}
    }

    final tasksJson = prefs.getString('guidance_completed_tasks');
    if (tasksJson != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(tasksJson);
        _completedTasks = decoded.map((key, value) => MapEntry(key, value as bool));
      } catch (_) {}
    }

    final cachedAdvisory = prefs.getString('guidance_cached_advisory');
    if (cachedAdvisory != null) {
      _realtimeAdvisory = cachedAdvisory;
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    if (_plantingDate != null) {
      await prefs.setString('guidance_planting_date', _plantingDate!.toIso8601String());
    } else {
      await prefs.remove('guidance_planting_date');
    }
    await prefs.setInt('guidance_variety_index', kRiceVarieties.indexOf(_selectedVariety));
    await prefs.setBool('guidance_is_direct_seeded', _isDirectSeeded);
    await prefs.setString('guidance_completed_tasks', json.encode(_completedTasks));
    await prefs.setString('guidance_cached_advisory', _realtimeAdvisory);

    final encodedHistory = json.encode(_plantingHistory.map((e) => e.toJson()).toList());
    await prefs.setString('guidance_planting_history', encodedHistory);
  }

  void _saveRecordToHistory(DateTime date) {
    final harvestDate = date.add(Duration(days: _selectedVariety.totalMaturityDays));
    final newRecord = PlantingRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      plantingDate: date,
      variety: _selectedVariety,
      isDirectSeeded: _isDirectSeeded,
      estimatedHarvestDate: harvestDate,
    );

    setState(() {
      _plantingHistory.insert(0, newRecord);
    });
  }

  Future<void> _resetCurrentTanim() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('guidance_planting_date');
    await prefs.remove('guidance_completed_tasks');

    setState(() {
      _plantingDate = null;
      _cropAgeDays = 0;
      _isFuturePlanting = false;
      _daysUntilPlanting = 0;
      _selectedStage = RiceStage.planning;
      _completedTasks.clear();
    });

    await _saveData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Na-reset na ang kasalukuyang tanim. Naka-save pa rin ang history.')),
      );
    }
  }

  void _updateCropAgeAndStage() {
    if (_plantingDate == null) {
      setState(() {
        _cropAgeDays = 0;
        _isFuturePlanting = false;
        _daysUntilPlanting = 0;
        _selectedStage = RiceStage.planning;
      });
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pDate = DateTime(_plantingDate!.year, _plantingDate!.month, _plantingDate!.day);

    final diff = today.difference(pDate).inDays;

    setState(() {
      if (diff < 0) {
        _isFuturePlanting = true;
        _daysUntilPlanting = diff.abs();
        _cropAgeDays = 0;
        _selectedStage = RiceStage.preparation;
      } else {
        _isFuturePlanting = false;
        _daysUntilPlanting = 0;
        _cropAgeDays = diff;

        final totalDays = _selectedVariety.totalMaturityDays;
        final vegEnd = (totalDays * 0.35).round();
        final repEnd = (totalDays * 0.65).round();
        final ripEnd = totalDays - 2;

        if (_cropAgeDays == 0) {
          _selectedStage = RiceStage.planning;
        } else if (_cropAgeDays <= vegEnd) {
          _selectedStage = RiceStage.vegetative;
        } else if (_cropAgeDays <= repEnd) {
          _selectedStage = RiceStage.reproductive;
        } else if (_cropAgeDays <= ripEnd) {
          _selectedStage = RiceStage.ripening;
        } else {
          _selectedStage = RiceStage.harvesting;
        }
      }
    });

    if (_weatherCode != null && _currentTemp != null) {
      _realtimeAdvisory = _generateDailyAndWeatherAdvisory(_weatherCode!, _currentTemp!);
    }
  }

  Map<String, String> _getCropMaturityStatus() {
    final total = _selectedVariety.totalMaturityDays;
    
    String varietyCategory = "Standard";
    if (total <= 108) {
      varietyCategory = "Early Maturing (100-108 Araw)";
    } else if (total <= 118) {
      varietyCategory = "Medium Maturing (110-118 Araw)";
    } else {
      varietyCategory = "Late Maturing / Hybrid (120+ Araw)";
    }

    if (_plantingDate == null || _isFuturePlanting) {
      return {
        "varietyCategory": varietyCategory,
        "harvestGuide": "Nasa Preparation Stage / Hindi Pa Nakatanim",
        "statusTag": "N/A",
      };
    }

    final daysRemaining = total - _cropAgeDays;

    if (_cropAgeDays < (total - 15)) {
      return {
        "varietyCategory": varietyCategory,
        "harvestGuide": "Masyado pang Maaga para Anihin (May $daysRemaining araw pa)",
        "statusTag": "MASYADO PANG MAAGA",
      };
    } else if (_cropAgeDays >= (total - 15) && _cropAgeDays < (total - 3)) {
      return {
        "varietyCategory": varietyCategory,
        "harvestGuide": "Malapit nang Anihin! Ihanda ang pagpapatuyo at makinarya ($daysRemaining araw nalang)",
        "statusTag": "MALAPIT NANG ANIHIN",
      };
    } else if (_cropAgeDays >= (total - 3) && _cropAgeDays <= (total + 7)) {
      return {
        "varietyCategory": varietyCategory,
        "harvestGuide": "PUWEDENG-PUWEDE NANG ANIHIN! (Nasa tamang panahon na ng pag-ani)",
        "statusTag": "PWEDE NANG ANIHIN 🌾",
      };
    } else {
      return {
        "varietyCategory": varietyCategory,
        "harvestGuide": "Lampas na sa Takdang Araw ng Ani! Anihin agad upang maiwasan ang pagkatapon ng butil.",
        "statusTag": "OVERDUE / ANIHIN AGAD",
      };
    }
  }

  Future<void> _fetchRealtimeWeather() async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$capalanganLat&longitude=$capalanganLng&current_weather=true',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final currentWeather = data['current_weather'];
        final double temp = (currentWeather['temperature'] as num).toDouble();
        final int code = currentWeather['weathercode'] as int;

        if (mounted) {
          setState(() {
            _currentTemp = temp;
            _weatherCode = code;
            _realtimeAdvisory = _generateDailyAndWeatherAdvisory(code, temp);
            _isLoadingWeather = false;
          });
          _saveData();
        }
      } else {
        _setFallbackAdvisory();
      }
    } catch (_) {
      _setFallbackAdvisory();
    }
  }

  void _setFallbackAdvisory() {
    if (mounted) {
      setState(() {
        _isLoadingWeather = false;
        if (_realtimeAdvisory.contains("Kina-kalkula")) {
          _realtimeAdvisory =
              "Capalangan Advisory (Offline): Panatilihing malinis ang mga kanal sa paligid ng palayan upang mabilis ang daloy ng tubig.";
        }
      });
    }
  }

  String _generateDailyAndWeatherAdvisory(int code, double temp) {
    bool isRaining = code >= 51;
    bool isStormy = code >= 95;
    final dayLabel = _isDirectSeeded ? "DAS" : "DAT";
    final maturityInfo = _getCropMaturityStatus();

    if (_plantingDate == null) {
      if (isRaining) {
        return "🌧️ ADVISORY NGAYONG ARAW: Umuulan ($temp°C). Mainam na maghanda ng kanal para sa lalabas na tubig bago magsimula ng tanim.";
      }
      return "🌤️ ADVISORY NGAYONG ARAW ($temp°C): Magandang simula para magplano ng petsa ng pagtatanim at maghanda ng binhi.";
    }

    if (_isFuturePlanting) {
      if (_daysUntilPlanting <= 7) {
        if (isRaining) {
          return "🌦️ $_daysUntilPlanting ARAW BAGO MAGTANIM: Umuulan ($temp°C). Siguraduhing pantay ang patag ng lupa at hindi babahain ang punlaan.";
        }
        return "🚜 $_daysUntilPlanting ARAW BAGO MAGTANIM: Mainam ang panahon ($temp°C) para sa huling pagpapatag ng lupa at paghahanda ng binhi.";
      }
      return "📅 PAGHAHAHANDA SA PAGTATANIM: May $_daysUntilPlanting araw pa. Simulan na ang pag-aararo at pagbili ng sertipikadong binhi.";
    }

    if (isStormy) {
      return "🚨 THUNDERSTORM ALERT (Araw $_cropAgeDays - $dayLabel): Unahin ang kaligtasan! Itigil muna ang pag-aabono o pag-spray ng pestisidyo.";
    }

    if (_cropAgeDays >= 0 && _cropAgeDays <= 7) {
      if (isRaining) {
        return "🌧️ ARAW $_cropAgeDays ($dayLabel) - [${maturityInfo['statusTag']}]: Umuulan ($temp°C). Bantayan ang lalim ng tubig. Huwag hayaang malunod ang mga bagong sibol!";
      }
      return "🌱 ARAW $_cropAgeDays ($dayLabel) - [${maturityInfo['statusTag']}]: Panatilihing mababaw lang (2-3 cm) ang tubig upang mabilis na mag-ugat ang palay.";
    }

    if (_cropAgeDays >= 10 && _cropAgeDays <= 15) {
      if (isRaining) {
        return "⚠️ ARAW $_cropAgeDays ($dayLabel): Umuulan ($temp°C). IPAGPALIBAN MUNA ANG UNANG PAG-AABONO (Complete 14-14-14) upang hindi maanod ng tubig.";
      }
      return "🧪 ARAW $_cropAgeDays ($dayLabel): Takdang araw para sa UNANG PAG-AABONO (14-14-14). Mag-abono habang maaliwalas ang panahon ($temp°C).";
    }

    if (_cropAgeDays >= 28 && _cropAgeDays <= 32) {
      if (isRaining) {
        return "🌦️ ARAW $_cropAgeDays ($dayLabel): May ulan ($temp°C). Ipagpaliban ang pag-aabono ng Urea (Nitrogen) hanggang sa tumigil ang ulan.";
      }
      return "🌾 ARAW $_cropAgeDays ($dayLabel) - PAGSUSUWI: Takdang panahon sa PANGALAWANG PAG-AABONO. Gamitin ang Leaf Color Chart (LCC) bago maglagay ng Urea.";
    }

    if (_cropAgeDays >= 50 && _cropAgeDays <= 65) {
      if (temp >= 33.0) {
        return "☀️ ARAW $_cropAgeDays ($dayLabel) - HEAT ALERT ($temp°C): Yugto ng Paglilihi/Pagbulaklak! Taasan ang tubig sa 3-5 cm para hindi matuyo ang mga bulaklak.";
      }
      if (isRaining) {
        return "🌧️ ARAW $_cropAgeDays ($dayLabel): Umuulan ($temp°C). Maging alerto sa mga peste tulad ng Rice Bug (Atangya) pagkatapos ng ulan.";
      }
      return "🌸 ARAW $_cropAgeDays ($dayLabel) - PAGBULAKLAK: Huwag papatuyuan ang petak! Panatilihing may sapat na tubig para sa buong timbang ng butil.";
    }

    if (_cropAgeDays >= (_selectedVariety.totalMaturityDays - 15) && _cropAgeDays < (_selectedVariety.totalMaturityDays - 3)) {
      return "🔔 ARAW $_cropAgeDays ($dayLabel) - [${maturityInfo['statusTag']}]: ${maturityInfo['harvestGuide']}. Patuyuin na ang bukid (Terminal Drainage).";
    }

    if (_cropAgeDays >= (_selectedVariety.totalMaturityDays - 3)) {
      return "🌾 ARAW $_cropAgeDays ($dayLabel) - [${maturityInfo['statusTag']}]: ${maturityInfo['harvestGuide']}. Angkop ang panahon ($temp°C) para sa pag-aani!";
    }

    if (isRaining) {
      return "🌧️ ARAW $_cropAgeDays ($dayLabel) - [${maturityInfo['statusTag']}]: Umuulan ($temp°C). Panatilihing malinis ang daluyan ng tubig.";
    }

    return "🌤️ ARAW $_cropAgeDays ($dayLabel) - [${maturityInfo['statusTag']}]: ${maturityInfo['harvestGuide']}.";
  }

  void _showHistoryBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.history_rounded, color: Color(0xFF16A34A)),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                "History ng Pagtatanim",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  if (_plantingHistory.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          "Wala pang nakatalang history ng pagtatanim.\nSimulan ang pagtatanim para magkaroon ng record.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _plantingHistory.length,
                        itemBuilder: (context, index) {
                          final item = _plantingHistory[index];
                          final method = item.isDirectSeeded ? "Sabog-Tanim (DAS)" : "Lipat-Tanim (DAT)";
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.variety.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF15803D)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                        onPressed: () async {
                                          setState(() {
                                            _plantingHistory.removeAt(index);
                                          });
                                          setModalState(() {});
                                          await _saveData();
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text("Petsa ng Tanim: ${item.plantingDate.year}-${item.plantingDate.month.toString().padLeft(2, '0')}-${item.plantingDate.day.toString().padLeft(2, '0')}",
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                                  Text("Tantyang Ani: ${item.estimatedHarvestDate.year}-${item.estimatedHarvestDate.month.toString().padLeft(2, '0')}-${item.estimatedHarvestDate.day.toString().padLeft(2, '0')}",
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                                  Text("Paraan: $method", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final estimatedHarvestDate = _plantingDate?.add(Duration(days: _selectedVariety.totalMaturityDays));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Expert Farming Assistant", style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
            Text("PhilRice & IRRI Scientific Protocols • Capalangan", style: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Tingnan ang History",
            icon: const Icon(Icons.history_rounded, color: Color(0xFF16A34A), size: 22),
            onPressed: _showHistoryBottomSheet,
          ),
          IconButton(
            tooltip: "I-reset ang Kasalukuyang Tanim",
            icon: const Icon(Icons.restart_alt_rounded, color: Color(0xFF94A3B8), size: 22),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("I-reset ang Kasalukuyang Tanim?"),
                  content: const Text("Buburahin lang ang kasalukuyang sinusubaybayang tanim. Naka-save pa rin ang iyong History."),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Kansela")),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _resetCurrentTanim();
                      },
                      child: const Text("I-reset", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            tooltip: "I-refresh ang Weather",
            icon: const Icon(Icons.sync_rounded, color: Color(0xFF64748B), size: 20),
            onPressed: () {
              setState(() => _isLoadingWeather = true);
              _fetchRealtimeWeather();
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF16A34A),
        onRefresh: _fetchRealtimeWeather,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HERO BANNER
              _buildHeroPlantingBanner(context, estimatedHarvestDate),

              const SizedBox(height: 14),

              // CROP CONFIGURATION
              _buildCropConfigurationCard(),

              const SizedBox(height: 14),

              // SMART CROP CALENDAR MATRIX (RESPONSIVE)
              _buildSmartPhilriceCalendarSection(),

              const SizedBox(height: 14),

              // DAILY & WEATHER ADVISORY BANNER
              _buildRealtimeAdvisoryBanner(),

              const SizedBox(height: 16),

              // STAGE TRACKER
              const Text("Mga Yugto ng Pagtatanim (Rice Stages)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 8),
              _buildStageSelector(),

              const SizedBox(height: 20),

              // CHECKLIST
              _buildInteractiveTaskChecklist(),

              const SizedBox(height: 20),

              // EXPERT GUIDANCE CARDS
              const Text("Siyentipikong Gabay at Pamantayan", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 10),
              ..._buildExpertGuidanceCards(_selectedStage),
            ],
          ),
        ),
      ),
    );
  }

  // --- SMART PHILRICE CALENDAR SYSTEM (RESPONSIVE DESIGN) ---
  Widget _buildSmartPhilriceCalendarSection() {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedCalendarMonth.year, _focusedCalendarMonth.month);
    final firstDayOffset = DateTime(_focusedCalendarMonth.year, _focusedCalendarMonth.month, 1).weekday % 7;

    final monthNames = [
      "Enero", "Pebredo", "Marso", "Abril", "Mayo", "Hunyo",
      "Hulyo", "Agosto", "Setyembre", "Oktubre", "Nobyembre", "Disyembre"
    ];

    final currentMonthLabel = "${monthNames[_focusedCalendarMonth.month - 1]} ${_focusedCalendarMonth.year}";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: Color(0xFF16A34A), size: 22),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "Smart Planting Calendar",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () {
                      setState(() {
                        _focusedCalendarMonth = DateTime(_focusedCalendarMonth.year, _focusedCalendarMonth.month - 1);
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                  Text(currentMonthLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 4),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () {
                      setState(() {
                        _focusedCalendarMonth = DateTime(_focusedCalendarMonth.year, _focusedCalendarMonth.month + 1);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Pindutin ang alinmang araw sa kalendaryo upang makita ang buong dahilan:",
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),

          // LEGEND BAR (RESPONSIVE WRAP)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceAround,
              spacing: 12,
              runSpacing: 6,
              children: [
                _buildCalendarLegendTile(const Color(0xFF16A34A), "🟢 Maganda"),
                _buildCalendarLegendTile(const Color(0xFFD97706), "🟡 Katamtaman"),
                _buildCalendarLegendTile(const Color(0xFFDC2626), "🔴 Huwag Muna"),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // DAY OF WEEK LABELS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ["Ling", "Lun", "Mar", "Miy", "Huw", "Biy", "Sab"].map((d) {
              return Expanded(
                child: Center(
                  child: Text(d, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // MONTH GRID BUILDER (DYNAMIC FLEXIBLE RATIO)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: daysInMonth + firstDayOffset,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              if (index < firstDayOffset) {
                return const SizedBox.shrink();
              }

              final dayNum = index - firstDayOffset + 1;
              final cellDate = DateTime(_focusedCalendarMonth.year, _focusedCalendarMonth.month, dayNum);
              final suitability = _getPhilriceCapalanganSuitability(cellDate);
              final isSelectedDate = _plantingDate != null &&
                  _plantingDate!.year == cellDate.year &&
                  _plantingDate!.month == cellDate.month &&
                  _plantingDate!.day == cellDate.day;

              final Color themeColor = suitability['color'] as Color;

              return InkWell(
                onTap: () {
                  _showCalendarDateDetailsModal(cellDate, suitability);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelectedDate
                        ? const Color(0xFF0F172A)
                        : themeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelectedDate
                          ? Colors.black
                          : themeColor.withOpacity(0.4),
                      width: isSelectedDate ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "$dayNum",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelectedDate ? Colors.white : themeColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelectedDate ? const Color(0xFFFEF08A) : themeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarLegendTile(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
      ],
    );
  }

  // --- MODAL POPUP KAPAG PININDOT ANG ISANG PETSA SA KALENDARYO ---
  void _showCalendarDateDetailsModal(DateTime targetDate, Map<String, dynamic> suitability) {
    final maturityDays = _selectedVariety.totalMaturityDays;
    final estimatedStartHarvest = targetDate.add(Duration(days: maturityDays - 5));
    final estimatedEndHarvest = targetDate.add(Duration(days: maturityDays + 5));

    final vegDate = targetDate.add(Duration(days: (maturityDays * 0.35).round()));
    final repDate = targetDate.add(Duration(days: (maturityDays * 0.65).round()));
    final Color themeColor = suitability['color'] as Color;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          suitability['label'] as String,
                          style: TextStyle(color: themeColor, fontSize: 11, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // DETAILS CONTAINER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: themeColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    suitability['reason'] as String,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.4, fontWeight: FontWeight.w500),
                  ),
                ),

                const Divider(height: 24),
                const Text("ESTIMATED HARVEST DURATION & CROP PHASES", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                const SizedBox(height: 8),

                // HARVEST RANGE CARD
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.grain_rounded, color: Color(0xFF16A34A), size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Tantyang Haba ng Ani (Harvest Window):", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF166534))),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "${estimatedStartHarvest.month}/${estimatedStartHarvest.day}/${estimatedStartHarvest.year} — ${estimatedEndHarvest.month}/${estimatedEndHarvest.day}/${estimatedEndHarvest.year}",
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // PHASES SUMMARY
                Row(
                  children: [
                    Expanded(
                      child: _buildPhaseMiniBadge("Vegetative", "Hanggang ${vegDate.month}/${vegDate.day}"),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPhaseMiniBadge("Reproductive", "Hanggang ${repDate.month}/${repDate.day}"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text("PILIIN ITONG PETSA NG PAGTATANIM", style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      setState(() {
                        _plantingDate = targetDate;
                      });
                      _saveRecordToHistory(targetDate);
                      _updateCropAgeAndStage();
                      _saveData();
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhaseMiniBadge(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          Text(subtitle, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildHeroPlantingBanner(BuildContext context, DateTime? harvestDate) {
    final dayLabel = _isDirectSeeded ? "DAS" : "DAT";
    final maturity = _getCropMaturityStatus();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isFuturePlanting
              ? [const Color(0xFF0284C7), const Color(0xFF0369A1)]
              : [const Color(0xFF15803D), const Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2216A34A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(_isFuturePlanting ? Icons.event_available_rounded : Icons.rocket_launch_rounded, color: const Color(0xFFFEF08A), size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _isFuturePlanting ? "Plano sa Hinaharap" : "Kasalukuyang Pagtatanim",
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          if (_plantingDate != null && !_isFuturePlanting) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.eco_outlined, color: Color(0xFFFEF08A), size: 14),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      "${maturity['varietyCategory']} • ${maturity['statusTag']}",
                      style: const TextStyle(color: Color(0xFFFEF08A), fontSize: 10, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          Divider(color: Colors.white.withOpacity(0.2), height: 1),
          const SizedBox(height: 12),
          if (_plantingDate == null)
            const Text(
              "Pumili ng petsa sa Smart Calendar sa ibaba upang simulan ang pagsubaybay sa iyong palayan batay sa pamantayan ng PhilRice Capalangan.",
              style: TextStyle(color: Colors.white, fontSize: 11, height: 1.4),
            )
          else if (_isFuturePlanting)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("TARGET NA PETSA", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text("${_plantingDate!.year}-${_plantingDate!.month.toString().padLeft(2, '0')}-${_plantingDate!.day.toString().padLeft(2, '0')}",
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                Container(height: 28, width: 1, color: Colors.white24),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("COUNTDOWN", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text("May $_daysUntilPlanting araw pa",
                              style: const TextStyle(color: Color(0xFFFEF08A), fontSize: 13, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(height: 28, width: 1, color: Colors.white24),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("TANTYANG ANI", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text("${harvestDate?.month}/${harvestDate?.day}/${harvestDate?.year}",
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("PETSA NG PAGTATANIM", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text("${_plantingDate!.year}-${_plantingDate!.month.toString().padLeft(2, '0')}-${_plantingDate!.day.toString().padLeft(2, '0')}",
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                Container(height: 28, width: 1, color: Colors.white24),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("EDAD ($dayLabel)", style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text("Araw $_cropAgeDays",
                              style: const TextStyle(color: Color(0xFFFEF08A), fontSize: 13, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(height: 28, width: 1, color: Colors.white24),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("TANTYANG ANI", style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text("${harvestDate?.month}/${harvestDate?.day}/${harvestDate?.year}",
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCropConfigurationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("⚙️ Detalye ng Pananim & Pamamaraan", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 360) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildVarietyDropdown(),
                    const SizedBox(height: 10),
                    _buildMethodDropdown(),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: _buildVarietyDropdown()),
                  const SizedBox(width: 10),
                  Expanded(child: _buildMethodDropdown()),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVarietyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Uri ng Binhi (Rice Variety)", style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        const SizedBox(height: 4),
        DropdownButtonFormField<RiceVariety>(
          value: _selectedVariety,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
          items: kRiceVarieties.map((v) {
            return DropdownMenuItem(value: v, child: Text(v.name, overflow: TextOverflow.ellipsis));
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedVariety = val);
              _updateCropAgeAndStage();
              _saveData();
            }
          },
        ),
      ],
    );
  }

  Widget _buildMethodDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Paraan ng Pagtatanim", style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        const SizedBox(height: 4),
        DropdownButtonFormField<bool>(
          value: _isDirectSeeded,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
          items: const [
            DropdownMenuItem(value: false, child: Text("Lipat-Tanim (DAT)", overflow: TextOverflow.ellipsis)),
            DropdownMenuItem(value: true, child: Text("Sabog-Tanim (DAS)", overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _isDirectSeeded = val);
              _updateCropAgeAndStage();
              _saveData();
            }
          },
        ),
      ],
    );
  }

  Widget _buildRealtimeAdvisoryBanner() {
    bool isAlert = (_weatherCode ?? 0) >= 61 || _realtimeAdvisory.contains("🚨") || _realtimeAdvisory.contains("⚠️");

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAlert ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isAlert ? const Color(0xFFFCA5A5) : const Color(0xFFBBF7D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _isLoadingWeather
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)))
              : Icon(isAlert ? Icons.warning_amber_rounded : Icons.sensors_rounded, color: isAlert ? const Color(0xFFDC2626) : const Color(0xFF16A34A), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _realtimeAdvisory,
              style: TextStyle(color: isAlert ? const Color(0xFF991B1B) : const Color(0xFF166534), fontSize: 12, fontWeight: FontWeight.w600, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageSelector() {
    return SizedBox(
      height: 85,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: RiceStage.values.length,
        itemBuilder: (context, index) {
          final stage = RiceStage.values[index];
          final isSelected = _selectedStage == stage;

          return GestureDetector(
            onTap: () => setState(() => _selectedStage = stage),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 145,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF16A34A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0)),
                boxShadow: isSelected ? const [BoxShadow(color: Color(0x3316A34A), blurRadius: 8, offset: Offset(0, 3))] : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(stage.icon, color: isSelected ? Colors.white : const Color(0xFF16A34A), size: 20),
                  const SizedBox(height: 4),
                  Text(stage.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF1E293B))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInteractiveTaskChecklist() {
    List<String> tasks = _getPhilriceTasksForStage(_selectedStage);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.playlist_add_check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Gawain sa Yugtong Ito (${_selectedStage.label})",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                  child: Text(_selectedStage.standardRef, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)), overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 8),
          ...tasks.map((task) {
            final isChecked = _completedTasks[task] ?? false;
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: const Color(0xFF16A34A),
              title: Text(
                task,
                style: TextStyle(
                  fontSize: 12,
                  color: isChecked ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                  fontWeight: isChecked ? FontWeight.normal : FontWeight.w500,
                ),
              ),
              value: isChecked,
              onChanged: (val) {
                setState(() {
                  _completedTasks[task] = val ?? false;
                });
                _saveData();
              },
            );
          }),
        ],
      ),
    );
  }

  List<String> _getPhilriceTasksForStage(RiceStage stage) {
    final dayType = _isDirectSeeded ? "DAS" : "DAP/DAT";

    switch (stage) {
      case RiceStage.preparation:
        return [
          "Maghanap at bumili ng Certified Seeds (NSIC Rc) sa accredited seed grower.",
          "Mag-araro ng lupa 14-21 araw bago magtanim upang mabulok ang mga lumang damo at dayami.",
          "Mag-suyod ng palayan (1st & 2nd harrowing) pitong araw bago ang target na tanim.",
          "Magpatubig nang bahagya upang maipahinga ang lupa at lumabas ang mga natutulog na binhi ng damo.",
          "Ihanda ang Punas/Punlaan (Dapog o Traditional Bed) kung magli-lipat tanim.",
        ];
      case RiceStage.planning:
        return [
          "Pantayin nang maayos ang lupa gamit ang leveling board para pantay ang lalim ng tubig.",
          "Isagawa ang germination test sa binhi upang masigurong mataas ang sprouting rate (>85%).",
          "Ihanda ang mga gagamiting abono at mga kagamitan sa pag-aabono.",
        ];
      case RiceStage.vegetative:
        return [
          "Unang Pag-aabono (10-14 $dayType): Maglagay ng Complete Fertilizer (14-14-14) sa sukat na 4-5 bags/ha.",
          "Pangalawang Pag-aabono (28-30 $dayType): Maglagay ng Urea (46-0-0) batay sa balangkas ng Leaf Color Chart (LCC).",
          "AWD Water System: Hayaang bumaba ang tubig sa 15 cm sa ilalim ng lupa bago muling magpatubig.",
        ];
      case RiceStage.reproductive:
        return [
          "Panatilihing may 3-5 cm na lalim ng tubig sa petak upang hindi ma-abort ang mga butil.",
          "Mag-spray ng Muriate of Potash (0-0-60) para sa mas matitigas at mabibigat na ulay.",
          "Mag-inspeksyon laban sa Rice Bug (Atangya) sa oras ng pagmumukadkad.",
        ];
      case RiceStage.ripening:
        return [
          "Patuyuin ang bukid 7-10 araw bago mag-ani (Terminal Drainage) upang tumigas ang lupa.",
          "Ihanda ang gagamiting Combine Harvester o mga manggagawa para sa takdang petsa ng ani.",
        ];
      case RiceStage.harvesting:
        return [
          "Anihin ang palay kapag 80-85% ng mga butil sa ulay ay kulay ginto na.",
          "Patuyuin ang palay sa 14% Moisture Content (MC) sa loob ng 24 oras upang mapanatili ang mataas na kalidad.",
          "I-encode sa Marketplace upang direktang maibenta sa tamang presyo.",
        ];
    }
  }

  List<Widget> _buildExpertGuidanceCards(RiceStage stage) {
    switch (stage) {
      case RiceStage.preparation:
        return [
          _buildGuidanceCard(
            title: "Paghahanda Bago ang Pagtatanim (Pre-Planting)",
            category: "PHILRICE LAND PREPARATION",
            icon: Icons.engineering_rounded,
            color: Colors.indigo,
            bullets: [
              "Ang maagang pag-aararo (14 araw bago magtanim) ay pumatay ng mga peste at nagpapanatili ng sustansya ng lupa.",
              "Siguraduhing bumili lamang ng sertipikadong binhi (Certified Seeds) upang makaiwas sa halo-halong uri ng palay.",
            ],
          ),
        ];

      case RiceStage.planning:
        return [
          _buildGuidanceCard(
            title: "Pagpapatag ng Lupa at Pagpili ng Binhi",
            category: "PHILRICE KEY CHECK 1",
            icon: Icons.landscape_rounded,
            color: Colors.orange,
            bullets: [
              "Ang pantay na lupa ay nakakatipid ng hanggang 20% sa patubig at nakababawas sa pagdami ng damo.",
              "Gumamit ng Certified Seeds (tulad ng NSIC Rc 222 o Rc 160).",
            ],
          ),
        ];

      case RiceStage.vegetative:
        return [
          _buildGuidanceCard(
            title: "Tamang Nutrisyon at Leaf Color Chart (LCC)",
            category: "PHILRICE KEY CHECK 2 & 3",
            icon: Icons.science_rounded,
            color: Colors.green,
            bullets: [
              "Suriin ang kulay ng dahon gamit ang LCC tuwing 7 araw mula 14 DAP/DAS.",
              "Unang Pag-aabono: Complete Fertilizer (14-14-14) para sa malulusog na ugat.",
            ],
          ),
        ];

      case RiceStage.reproductive:
        return [
          _buildGuidanceCard(
            title: "Pangalagaan ang Paglilihi at Pagbulaklak",
            category: "PHILRICE KEY CHECK 4",
            icon: Icons.eco_rounded,
            color: Colors.purple,
            bullets: [
              "Huwag patutuyuan ang petak! Panatilihing may 3-5 cm na tubig.",
            ],
          ),
        ];

      case RiceStage.ripening:
        return [
          _buildGuidanceCard(
            title: "Terminal Drainage at Pagpapatuyo",
            category: "PHILRICE KEY CHECK 5",
            icon: Icons.agriculture_rounded,
            color: Colors.amber,
            bullets: [
              "Alisin ang tubig sa petak 7-10 araw bago ang target na ani.",
            ],
          ),
        ];

      case RiceStage.harvesting:
        return [
          _buildGuidanceCard(
            title: "Post-Harvest at Moisture Quality",
            category: "PHILRICE KEY CHECK 6",
            icon: Icons.inventory_2_rounded,
            color: Colors.teal,
            bullets: [
              "Patuyuin agad ang palay sa 14% Moisture Content (MC) sa loob ng 24 oras.",
            ],
          ),
        ];
    }
  }

  Widget _buildGuidanceCard({
    required String title,
    required String category,
    required IconData icon,
    required MaterialColor color,
    required List<String> bullets,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color.shade700, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color.shade700, letterSpacing: 0.5)),
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 12),
          ...bullets.map((bullet) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("• ", style: TextStyle(color: color.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
                    Expanded(
                      child: Text(
                        bullet,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.35),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}