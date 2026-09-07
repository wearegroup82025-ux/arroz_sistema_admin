import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/weather_entity.dart';
import '../../domain/weather_repository.dart';
import '../../services/weather/weather_api_service.dart';
import '../../services/weather/weather_repository_impl.dart';

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
      json['name'] ?? 'NSIC Rc 222 (Pangkaraniwan)',
      json['totalMaturityDays'] ?? 115,
      json['description'] ?? '',
    );
  }
}

const List<RiceVariety> kRiceVarieties = [
  RiceVariety('NSIC Rc 222 (Pangkaraniwan / Inbred)', 115, 'Matagumpay sa tag-ulan at tag-araw. Aaniin sa loob ng 115 araw.'),
  RiceVariety('NSIC Rc 192 (Maagang Anihin)', 105, 'Mabilis anihin (105 araw), maganda laban sa maikling ulan.'),
  RiceVariety('NSIC Rc 216 (Magandang Kalidad)', 112, 'Maganda at masarap ang kalidad ng bigas. 112 araw.'),
  RiceVariety('Mestiso 20 (Hybrid Rice)', 123, 'Mas mataas magbigay ng ani. 123 araw.'),
];

enum PlantingWindowStatus {
  ideal('Magandang Panahon Magtanim', Color(0xFF059669), Icons.check_circle_rounded),
  warning('Katamtaman / May Kaunting Panganib', Color(0xFFD97706), Icons.warning_amber_rounded),
  bad('Delikado (Baha o Tagtuyot)', Color(0xFFDC2626), Icons.cancel_rounded);

  final String label;
  final Color color;
  final IconData icon;

  const PlantingWindowStatus(this.label, this.color, this.icon);
}

enum RiceStage {
  preparation('Paghahanda ng Lupa', Icons.engineering_rounded),
  planning('Pagpapatag at Binhi', Icons.calendar_month_rounded),
  vegetative('Pagsusuwi (Tanim)', Icons.grass_rounded),
  reproductive('Paglilihi at Bulaklak', Icons.eco_rounded),
  ripening('Pagkahinog ng Butil', Icons.grain_rounded),
  harvesting('Pag-aani at Pagpapatuyo', Icons.inventory_2_rounded);

  final String label;
  final IconData icon;

  const RiceStage(this.label, this.icon);
}

class GuidancePage extends StatefulWidget {
  const GuidancePage({super.key});

  @override
  State<GuidancePage> createState() => _GuidancePageState();
}

class _GuidancePageState extends State<GuidancePage> {
  late final WeatherRepository _weatherRepository;
  Future<WeatherEntity>? _weatherFuture;

  static const double latitude = 14.9540;
  static const double longitude = 120.7594;

  DateTime? _plantingDate;
  int _cropAgeDays = 0;

  RiceVariety _selectedVariety = kRiceVarieties[0];
  RiceStage _selectedStage = RiceStage.planning;

  Map<String, bool> _completedTasks = {};

  @override
  void initState() {
    super.initState();
    final apiService = WeatherApiService(http.Client());
    _weatherRepository = WeatherRepositoryImpl(apiService: apiService);
    _loadSavedData();
    _fetchWeather();
  }

  void _fetchWeather() {
    setState(() {
      _weatherFuture = _weatherRepository.getWeatherByCoordinates(latitude, longitude);
    });
  }

  /// EVALUATE PETSA: BERDE O PULA
  static PlantingWindowStatus evaluateDate(DateTime date) {
    final month = date.month;

    // Ligtas (Mayo - Hulyo & Nobyembre - Enero)
    if ((month >= 5 && month <= 7) || month == 11 || month == 12 || month == 1) {
      return PlantingWindowStatus.ideal;
    }

    // Delikado (Agosto - Oktubre & Pebrero - Abril)
    if ((month >= 8 && month <= 10) || (month >= 2 && month <= 4)) {
      return PlantingWindowStatus.bad;
    }

    return PlantingWindowStatus.warning;
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDateStr = prefs.getString('guidance_planting_date');
    if (savedDateStr != null) {
      _plantingDate = DateTime.tryParse(savedDateStr);
    }

    final vIndex = prefs.getInt('guidance_variety_index') ?? 0;
    if (vIndex >= 0 && vIndex < kRiceVarieties.length) {
      _selectedVariety = kRiceVarieties[vIndex];
    }

    final tasksJson = prefs.getString('guidance_completed_tasks');
    if (tasksJson != null) {
      try {
        final Map<String, dynamic> decoded = json.decode(tasksJson);
        _completedTasks = decoded.map((k, v) => MapEntry(k, v as bool));
      } catch (_) {}
    }

    _updateCropAgeAndStage();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    if (_plantingDate != null) {
      await prefs.setString('guidance_planting_date', _plantingDate!.toIso8601String());
    } else {
      await prefs.remove('guidance_planting_date');
    }
    await prefs.setInt('guidance_variety_index', kRiceVarieties.indexOf(_selectedVariety));
    await prefs.setString('guidance_completed_tasks', json.encode(_completedTasks));
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
      final totalDays = _selectedVariety.totalMaturityDays;

      if (_cropAgeDays == 0) {
        _selectedStage = RiceStage.planning;
      } else if (_cropAgeDays <= (totalDays * 0.35).round()) {
        _selectedStage = RiceStage.vegetative;
      } else if (_cropAgeDays <= (totalDays * 0.65).round()) {
        _selectedStage = RiceStage.reproductive;
      } else if (_cropAgeDays <= totalDays - 2) {
        _selectedStage = RiceStage.ripening;
      } else {
        _selectedStage = RiceStage.harvesting;
      }
    });
  }

  /// BUKAS NG POP-UP MODAL SA PAGPINDO SA BUTTON
  void _openColoredCalendarDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return _ColoredCalendarModal(
          initialDate: _plantingDate ?? DateTime.now(),
          onDateSelected: (selectedDate) async {
            final status = evaluateDate(selectedDate);

            if (status == PlantingWindowStatus.bad) {
              bool proceed = await showDialog<bool>(
                    context: context,
                    builder: (alertCtx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 28),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "BABALA SA PAGTATANIM",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                            ),
                          ),
                        ],
                      ),
                      content: const Text(
                        "Ang napili mong araw ay PULA sa kalendaryo. Delikado ito sa baha o matinding tagtuyot sa Pampanga.\n\nSigurado ka bang gusto mong itala ang petsang ito?",
                        style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(alertCtx, false),
                          child: const Text("Pumili ng Iba", style: TextStyle(color: Color(0xFF64748B))),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                          onPressed: () => Navigator.pop(alertCtx, true),
                          child: const Text("Ituloy Pa Rin", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ) ??
                  false;

              if (!proceed) return;
            }

            setState(() {
              _plantingDate = selectedDate;
            });
            _updateCropAgeAndStage();
            _saveData();
            Navigator.pop(ctx); // Isara ang modal pagkatapos pumili
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _plantingDate != null ? evaluateDate(_plantingDate!) : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("GABAY SA PAGSASA-KA (PHILRICE)", style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            Text("Capalangan, Pampanga", style: TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: const BoxDecoration(color: Color(0xFFE2E8F0), shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A), size: 20),
              onPressed: _fetchWeather,
            ),
          ),
        ],
      ),
      body: FutureBuilder<WeatherEntity>(
        future: _weatherFuture,
        builder: (context, snapshot) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroStatusBanner(status),
                const SizedBox(height: 16),
                
                // MALINIS NA CARD NA MAY BUTTON LAMANG
                _buildCalendarLauncherCard(status),

                const SizedBox(height: 16),
                _buildCropConfigurationCard(),
                const SizedBox(height: 16),
                const Text("Lagay at Yugto ng Tanim sa Bukid", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                _buildStageSelector(),
                const SizedBox(height: 16),
                _buildInteractiveTaskChecklist(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroStatusBanner(PlantingWindowStatus? status) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: status?.color ?? const Color(0xFF059669),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(status?.icon ?? Icons.eco_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                _plantingDate == null ? "Pumili ng Petsa ng Tanim" : "Edad ng Palay: Araw $_cropAgeDays",
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _plantingDate == null
                ? "Pindutin ang button sa ibaba para magbukas ang kalendaryong may gabay na kulay."
                : "Petsa ng Tanim: ${_plantingDate!.month}/${_plantingDate!.day}/${_plantingDate!.year} (${status?.label})",
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// MALINIS NA CARD WITH BUTTON
  Widget _buildCalendarLauncherCard(PlantingWindowStatus? status) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("📅 Kalendaryo ng Pagtatanim", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          const Text(
            "Pindutin ang button para buksan ang kalendaryo. Nakakultimada na roon ang Berde (Ligtas) at Pula (Baha/Tuyot).",
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: status?.color ?? const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.calendar_month_rounded, size: 20),
              label: Text(
                _plantingDate == null
                    ? "Buksan ang Kalendaryo ng Tanim"
                    : "Baguhin ang Petsa (${_plantingDate!.month}/${_plantingDate!.day}/${_plantingDate!.year})",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: _openColoredCalendarDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropConfigurationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("🌾 Uri ng Binhi na Gagamitin (PhilRice)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          DropdownButtonFormField<RiceVariety>(
            value: _selectedVariety,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: kRiceVarieties.map((v) => DropdownMenuItem(value: v, child: Text(v.name, style: const TextStyle(fontSize: 12)))).toList(),
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
    );
  }

  Widget _buildStageSelector() {
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: RiceStage.values.length,
        itemBuilder: (context, index) {
          final stage = RiceStage.values[index];
          final isSelected = _selectedStage == stage;
          return GestureDetector(
            onTap: () => setState(() => _selectedStage = stage),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF059669) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(stage.icon, color: isSelected ? Colors.white : const Color(0xFF059669), size: 18),
                  const SizedBox(height: 4),
                  Text(
                    stage.label,
                    style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInteractiveTaskChecklist() {
    final tasks = _getTasksForStage(_selectedStage);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Mga Gagawin sa Bukid: ${_selectedStage.label}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
          const Divider(),
          ...tasks.map((task) {
            final isChecked = _completedTasks[task] ?? false;
            return CheckboxListTile(
              dense: true,
              activeColor: const Color(0xFF059669),
              title: Text(task, style: TextStyle(fontSize: 12, decoration: isChecked ? TextDecoration.lineThrough : null, color: const Color(0xFF334155))),
              value: isChecked,
              onChanged: (val) {
                setState(() => _completedTasks[task] = val ?? false);
                _saveData();
              },
            );
          }),
        ],
      ),
    );
  }

  List<String> _getTasksForStage(RiceStage stage) {
    switch (stage) {
      case RiceStage.preparation:
        return [
          "Mag-araro at magsuklay ng lupa 2 hanggang 3 linggo bago magtanim.",
          "Subukan kung maganda ang binhi (Germination Test).",
        ];
      case RiceStage.planning:
        return [
          "Pantayin nang husto ang lupa gamit ang suyod o leveling board.",
          "Ihanda ang gagamiting abono at mga kagamitan sa bukid.",
        ];
      case RiceStage.vegetative:
        return [
          "Unang Pag-aabono (10-14 araw pagkatanim): Maglagay ng Complete (14-14-14).",
          "Pangalawang Pag-aabono (28-30 araw): Tingnan ang kulay ng dahon (LCC) bago maglagay ng Urea.",
        ];
      case RiceStage.reproductive:
        return [
          "Panatilihing may tubig na humigit-kumulang 3 hanggang 5 sentimetro ang lalim sa petak.",
          "Bantayan ang mga pesteng atangya o tipaklong habang nagbubulaklak ang palay.",
        ];
      case RiceStage.ripening:
        return [
          "Patuyuin na ang petak (alisin ang tubig) 7 hanggang 10 araw bago mag-ani.",
        ];
      case RiceStage.harvesting:
        return [
          "Mag-ani kapag kulay ginto na ang 80% hanggang 85% ng mga butil sa ulay.",
          "Patuyuin agad ang naaning palay sa loob ng 24 oras upang hindi masira.",
        ];
    }
  }
}

/// POP-UP DIALOG NG CUSTOM CALENDAR NA MAY KULAY
class _ColoredCalendarModal extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onDateSelected;

  const _ColoredCalendarModal({required this.initialDate, required this.onDateSelected});

  @override
  State<_ColoredCalendarModal> createState() => _ColoredCalendarModalState();
}

class _ColoredCalendarModalState extends State<_ColoredCalendarModal> {
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    _focusedMonth = widget.initialDate;
  }

  String _getMonthName(int month) {
    const months = ['Enero', 'Pebrero', 'Marso', 'Abril', 'Mayo', 'Hulyo', 'Hulyo', 'Agosto', 'Setyembre', 'Oktubre', 'Nobyembre', 'Disyembre'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;

    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final firstDayOfMonth = DateTime(year, month, 1);
    final startingWeekday = firstDayOfMonth.weekday % 7;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER NG POP-UP
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${_getMonthName(month)} $year",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () {
                        setState(() {
                          _focusedMonth = DateTime(year, month - 1, 1);
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () {
                        setState(() {
                          _focusedMonth = DateTime(year, month + 1, 1);
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            // LEGEND SA LOOB NG MODAL
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ModalLegendDot(color: Color(0xFF059669), label: "Berde = Ligtas"),
                SizedBox(width: 16),
                _ModalLegendDot(color: Color(0xFFDC2626), label: "Pula = Delikado"),
              ],
            ),
            const SizedBox(height: 12),

            // MGA ARAW SA LINGGO
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['Ling', 'Lun', 'Mar', 'Miy', 'Huw', 'Biy', 'Sab']
                  .map((d) => SizedBox(
                        width: 32,
                        child: Text(d, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),

            // GRID NG MGA ARAW SA POP-UP
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: startingWeekday + daysInMonth,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemBuilder: (context, index) {
                if (index < startingWeekday) {
                  return const SizedBox.shrink();
                }

                final dayNumber = index - startingWeekday + 1;
                final currentDate = DateTime(year, month, dayNumber);
                final status = _GuidancePageState.evaluateDate(currentDate);

                return InkWell(
                  onTap: () => widget.onDateSelected(currentDate),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: status.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: status.color, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        "$dayNumber",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: status.color,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Isara", style: TextStyle(color: Color(0xFF64748B))),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModalLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _ModalLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[800], fontWeight: FontWeight.bold)),
      ],
    );
  }
}