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
}

const List<RiceVariety> kRiceVarieties = [
  RiceVariety('Standard Inbred (e.g., Rc 222)', 115, 'Karaniwang binhi na umaani sa loob ng 115 araw.'),
  RiceVariety('Early Maturing (e.g., Rc 192)', 105, 'Mabilis anihin, mainam para sa maikling tag-ulan.'),
  RiceVariety('Late / Hybrid Rice', 125, 'Matagal anihin ngunit may potensyal sa mas mataas na ani.'),
];

/// Siyentipikong Yugto ng Palay batay sa PhilRice PalayCheck System
enum RiceStage {
  planning(
    'Paghahanda & Pagpaplano',
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
  RiceVariety _selectedVariety = kRiceVarieties[0];
  bool _isDirectSeeded = false; // false = Transplanted (DAT), true = Direct Seeded (DAS)
  RiceStage _selectedStage = RiceStage.planning;

  // Weather State
  bool _isLoadingWeather = true;
  double? _currentTemp;
  int? _weatherCode;
  String _realtimeAdvisory = "Kina-kalkula ang datos ng panahon sa Capalangan...";

  // Task Checklist Tracking State
  Map<String, bool> _completedTasks = {};

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

  // --- LOCAL PERSISTENCE & OFFLINE CACHING ---
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Planting Date
    final savedDateStr = prefs.getString('guidance_planting_date');
    if (savedDateStr != null) {
      _plantingDate = DateTime.tryParse(savedDateStr);
    }

    // Load Variety
    final varietyIndex = prefs.getInt('guidance_variety_index') ?? 0;
    if (varietyIndex >= 0 && varietyIndex < kRiceVarieties.length) {
      _selectedVariety = kRiceVarieties[varietyIndex];
    }

    // Load Planting Method
    _isDirectSeeded = prefs.getBool('guidance_is_direct_seeded') ?? false;

    // Load Tasks State
    final tasksJson = prefs.getString('guidance_completed_tasks');
    if (tasksJson != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(tasksJson);
        _completedTasks = decoded.map((key, value) => MapEntry(key, value as bool));
      } catch (_) {}
    }

    // Load Cached Weather (Offline Support)
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
  }

  Future<void> _resetAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      _plantingDate = null;
      _cropAgeDays = 0;
      _selectedVariety = kRiceVarieties[0];
      _isDirectSeeded = false;
      _selectedStage = RiceStage.planning;
      _completedTasks.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Na-reset na ang lahat ng datos ng pagtatanim.')),
      );
    }
  }

  void _updateCropAgeAndStage() {
    if (_plantingDate == null) {
      setState(() {
        _cropAgeDays = 0;
        _selectedStage = RiceStage.planning;
      });
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pDate = DateTime(_plantingDate!.year, _plantingDate!.month, _plantingDate!.day);
    
    final diff = today.difference(pDate).inDays;

    setState(() {
      _cropAgeDays = diff < 0 ? 0 : diff;
      
      // Dynamic Stage Range Calculation
      final totalDays = _selectedVariety.totalMaturityDays;
      final vegEnd = (totalDays * 0.35).round(); 
      final repEnd = (totalDays * 0.65).round(); 
      final ripEnd = totalDays - 2;               

      if (_cropAgeDays <= 0) {
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
    });
  }

  // VALIDATED DATE PICKER
  Future<void> _selectPlantingDate(BuildContext context) async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _plantingDate ?? now,
      // Input Validation Limits: Hindi pwedeng lumagpas sa 150 days ang nakalipas o pumunta sa hinaharap
      firstDate: now.subtract(const Duration(days: 150)),
      lastDate: now,
      helpText: 'PILIIN ANG PETSA NG PAGTATANIM',
      confirmText: 'SIMULAN ANG PLANO',
      cancelText: 'KANSELA',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF16A34A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _plantingDate = picked;
      });
      _updateCropAgeAndStage();
      _saveData();
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
            _realtimeAdvisory = _generateRealtimeAdvisory(code, temp);
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
          _realtimeAdvisory = "Capalangan Advisory (Offline): Panatilihing malinis ang mga kanal sa paligid ng palayan upang mabilis ang daloy ng tubig.";
        }
      });
    }
  }

  String _generateRealtimeAdvisory(int code, double temp) {
    if (code >= 95) {
      return "🚨 PHILRICE WEATHER ALERT: Banta ng thunderstorm! Itigil muna ang pag-aabono o pag-spray ng pestisidyo upang maiwasan ang pagka-anod.";
    } else if (code >= 61 && code <= 67) {
      return "🌧️ PHILRICE AGRI-ADVISORY: Umuulan sa Capalangan ($temp°C). Huwag mag-aabono ng Nitrogen dahil masasayang lamang ito sa pag-agos ng tubig (Nutrient Leaching).";
    } else if (code >= 51 && code <= 55) {
      return "🌦️ PHILRICE AGRI-ADVISORY: May ambon ($temp°C). Tamang panahon upang mag-inspeksyon ng mga peste gaya ng kuhol at stem borer.";
    } else if (temp >= 33.0) {
      return "☀️ THERMAL STRESS ALERT: Mainit ang panahon ($temp°C). Panatilihing may 3-5 cm na lalim ng tubig sa petak upang maprotektahan ang ugat.";
    } else {
      return "🌤️ MAGANDANG PANAHON ($temp°C): Angkop na pagkakataon para sa pamamahala ng pataba, patubig, o paglilinis ng palayan.";
    }
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
            tooltip: "I-reset ang Data",
            icon: const Icon(Icons.restart_alt_rounded, color: Color(0xFF94A3B8), size: 22),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("I-reset ang Tanim?"),
                  content: const Text("Sigurado ka bang gusto mong burahin ang naka-save na petsa at mga natapos na gawain?"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Kansela")),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _resetAllData();
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
              // 🚀 HERO CALL-TO-ACTION BANNER
              _buildHeroPlantingBanner(context, estimatedHarvestDate),

              const SizedBox(height: 14),

              // ⚙️ CROP CONFIGURATION (VARIETY & METHOD SELECTOR)
              _buildCropConfigurationCard(),

              const SizedBox(height: 14),

              // 💡 REAL-TIME WEATHER & AGRI ADVISORY BANNER
              _buildRealtimeAdvisoryBanner(),

              const SizedBox(height: 16),

              // 📅 STAGE TRACKER & SELECTOR
              const Text("Mga Yugto ng Pagtatanim (Rice Stages)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 8),
              _buildStageSelector(),

              const SizedBox(height: 20),

              // 📋 INTERACTIVE STEP-BY-STEP CHECKLIST FOR CURRENT STAGE
              _buildInteractiveTaskChecklist(),

              const SizedBox(height: 20),

              // 🎓 PHILRICE SCIENTIFIC CARDS & GUIDELINES
              const Text("Siyentipikong Gabay at Pamantayan", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 10),
              ..._buildExpertGuidanceCards(_selectedStage),
            ],
          ),
        ),
      ),
    );
  }

  // BANNER SA TAAS
  Widget _buildHeroPlantingBanner(BuildContext context, DateTime? harvestDate) {
    final dayLabel = _isDirectSeeded ? "DAS" : "DAT";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF15803D), Color(0xFF16A34A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.rocket_launch_rounded, color: Color(0xFFFEF08A), size: 22),
                  SizedBox(width: 8),
                  Text("Simulan ang Pagtatanim", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                ],
              ),
              ElevatedButton(
                onPressed: () => _selectPlantingDate(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF15803D),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  _plantingDate == null ? "Pumili ng Petsa" : "Palitan ang Petsa",
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 12),
          if (_plantingDate == null)
            const Text(
              "I-click ang button sa itaas para ilagay kung kailan ka magtatanim. Tutulungan ka ng aming AI Agronomist na planuhin ang abono, patubig, at pangkalahatang alaga batay sa pamantayan ng PhilRice.",
              style: TextStyle(color: Colors.white24, fontSize: 11, height: 1.4),
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
                      Text("${_plantingDate!.year}-${_plantingDate!.month.toString().padLeft(2, '0')}-${_plantingDate!.day.toString().padLeft(2, '0')}",
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
                        Text("Araw $_cropAgeDays",
                            style: const TextStyle(color: Color(0xFFFEF08A), fontSize: 13, fontWeight: FontWeight.w900)),
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
                        Text("${harvestDate?.month}/${harvestDate?.day}/${harvestDate?.year}",
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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

  // CROP CONFIGURATION SELECTOR
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
          Row(
            children: [
              Expanded(
                child: Column(
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
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
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
                        DropdownMenuItem(value: false, child: Text("Lipat-Tanim (DAT)")),
                        DropdownMenuItem(value: true, child: Text("Sabog-Tanim (DAS)")),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _isDirectSeeded = val);
                          _saveData();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // REAL-TIME WEATHER ADVISORY BANNER
  Widget _buildRealtimeAdvisoryBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (_weatherCode ?? 0) >= 61 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (_weatherCode ?? 0) >= 61 ? const Color(0xFFFCA5A5) : const Color(0xFFBBF7D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _isLoadingWeather
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF16A34A)))
              : Icon((_weatherCode ?? 0) >= 61 ? Icons.warning_amber_rounded : Icons.sensors_rounded, color: (_weatherCode ?? 0) >= 61 ? const Color(0xFFDC2626) : const Color(0xFF16A34A), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _realtimeAdvisory,
              style: TextStyle(color: (_weatherCode ?? 0) >= 61 ? const Color(0xFF991B1B) : const Color(0xFF166534), fontSize: 12, fontWeight: FontWeight.w600, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // HORIZONTAL STAGE SELECTOR
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
                boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))] : [],
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

  // INTERACTIVE CHECKLIST FOR THE SELECTED STAGE
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                child: Text(_selectedStage.standardRef, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: const Color(0xFFF1F5F9), height: 1),
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
      case RiceStage.planning:
        return [
          "Pumili ng certified seeds (NSIC Rc) para sa mataas na ani at tibay sa peste.",
          "Mag-araro 14 araw bago magtanim upang mabulok ang mga lumang dayami.",
          "I-level nang maayos ang lupa gamit ang leveling board para sa pantay na patubig.",
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
      case RiceStage.planning:
        return [
          _buildGuidanceCard(
            title: "Paghahanda ng Lupa at Binhi",
            category: "PHILRICE KEY CHECK 1",
            icon: Icons.landscape_rounded,
            color: Colors.orange,
            bullets: [
              "Mag-araro ng 14 araw bago magtanim upang mabulok ang mga dayami at maging organic fertilizer.",
              "Gumamit ng Certified Seeds (tulad ng NSIC Rc 222 o Rc 160) na nakarehistro sa Bureau of Plant Industry.",
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
              "Suriin ang kulay ng dahon gamit ang LCC tuwing 7 araw mula 14 DAP/DAS hanggang panahong maglihi.",
              "Unang Pag-aabono: Complete Fertilizer (14-14-14) para sa malulusog na ugat.",
              "Pangalawang Pag-aabono: Urea (46-0-0) upang dumami ang mga suwi.",
            ],
          ),
          _buildGuidanceCard(
            title: "AWD Water Management System",
            category: "IRRI SCIENTIFIC STANDARD",
            icon: Icons.water_drop_rounded,
            color: Colors.blue,
            bullets: [
              "Hayaang matuyo ang lupa hanggang 15 cm sa ilalim bago muling magpapasok ng tubig upang palamigin at patibayin ang ugat laban sa malakas na hangin.",
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
              "Huwag patutuyuan ang petak! Panatilihing may 3-5 cm na tubig upang hindi maging hapa o walang laman ang mga butil.",
              "Mag-spray ng Potash (0-0-60) upang maging malusog at mabigat ang timbang ng bawat palay.",
            ],
          ),
        ];

     case RiceStage.ripening:
        return [
          _buildGuidanceCard(
            title: "Terminal Drainage at Pagpapatuyo",
            category: "PHILRICE KEY CHECK 5",
            icon: Icons.grain_rounded, // ✅ Pinalitan ng tamang IconData
            color: Colors.amber,        // ✅ Idinagdag ang nawawalang color parameter
            bullets: [
              "Alisin ang tubig sa petak 7-10 araw bago ang target na ani para tumigas ang lupa at mabilis na makaikot ang harvester.",
              "Siguraduhing malinis ang paligid laban sa mga ibon at daga habang naghihintay ng pag-ani.",
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
              "Patuyuin agad ang palay sa 14% Moisture Content (MC) sa loob ng 24 oras upang maiwasan ang pagpula o pag-itim ng bigas.",
              "I-post sa lokal na marketplace sa Capalangan para sa direktang benta nang walang middleman.",
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
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
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
          Divider(color: const Color(0xFFF1F5F9), height: 1),
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