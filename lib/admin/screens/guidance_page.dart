import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/weather_entity.dart';
import '../../domain/weather_repository.dart';
import '../../services/weather/weather_api_service.dart';
import '../../services/weather/weather_repository_impl.dart';

/// IMPORTANT:
/// The app intentionally exposes only two choices:
///   1. Inbred
///   2. Hybrid
///
/// Baseline values (DA-PhilRice):
/// - Inbred: PSB Rc82 = 110 days
/// - Hybrid: Mestiso 20 / NSIC Rc204H = 111 days

enum RiceType {
  inbred,
  hybrid;

  String get label => this == RiceType.inbred ? 'Inbred' : 'Hybrid';

  String get referenceVariety =>
      this == RiceType.inbred ? 'PSB Rc82' : 'Mestiso 20 (NSIC Rc204H)';

  int get maturityDays => this == RiceType.inbred ? 110 : 111;

  String get maturityNote => this == RiceType.inbred
      ? 'Baseline: 110 araw (PSB Rc82, PhilRice)'
      : 'Baseline: 111 araw (Mestiso 20/NSIC Rc204H, PhilRice)';
}

enum RiceStage {
  notStarted,
  establishment,
  vegetative,
  reproductive,
  ripening,
  harvest;

  String get label {
    switch (this) {
      case RiceStage.notStarted:
        return 'Hindi pa Nagtatanim';
      case RiceStage.establishment:
        return 'Pagtatatag ng Tanim';
      case RiceStage.vegetative:
        return 'Vegetative / Pagsusuwi';
      case RiceStage.reproductive:
        return 'Reproductive / Panicle at Bulaklak';
      case RiceStage.ripening:
        return 'Pagkahinog';
      case RiceStage.harvest:
        return 'Panahon ng Pag-aani';
    }
  }

  IconData get icon {
    switch (this) {
      case RiceStage.notStarted:
        return Icons.event_available_rounded;
      case RiceStage.establishment:
        return Icons.grass_rounded;
      case RiceStage.vegetative:
        return Icons.eco_rounded;
      case RiceStage.reproductive:
        return Icons.spa_rounded;
      case RiceStage.ripening:
        return Icons.grain_rounded;
      case RiceStage.harvest:
        return Icons.agriculture_rounded;
    }
  }
}

class _CropProfile {
  final int maturityDays;
  final int establishmentEnd;
  final int vegetativeEnd;
  final int reproductiveEnd;

  const _CropProfile({
    required this.maturityDays,
    required this.establishmentEnd,
    required this.vegetativeEnd,
    required this.reproductiveEnd,
  });
}

class GuidancePage extends StatefulWidget {
  const GuidancePage({super.key});

  @override
  State<GuidancePage> createState() => _GuidancePageState();
}

class _GuidancePageState extends State<GuidancePage> {
  static const String _cropTrackerDocId = 'active_crop';

  late final WeatherRepository _weatherRepository;
  Future<WeatherEntity>? _weatherFuture;

  static const double latitude = 14.9540;
  static const double longitude = 120.7594;

  DateTime? _plantingDate;
  int _cropAgeDays = 0;
  RiceType _selectedType = RiceType.inbred;
  RiceStage _selectedStage = RiceStage.notStarted;

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
      _weatherFuture =
          _weatherRepository.getWeatherByCoordinates(latitude, longitude);
    });
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  _CropProfile get _profile {
    final maturity = _selectedType.maturityDays;

    final establishmentEnd = 14;
    final vegetativeEnd = (maturity * 0.55).round();
    final reproductiveEnd = (maturity * 0.82).round();

    return _CropProfile(
      maturityDays: maturity,
      establishmentEnd: establishmentEnd,
      vegetativeEnd: vegetativeEnd,
      reproductiveEnd: reproductiveEnd,
    );
  }

  RiceStage _stageForAge(int age) {
    if (_plantingDate == null || age <= 0) {
      return _plantingDate == null
          ? RiceStage.notStarted
          : RiceStage.establishment;
    }

    final p = _profile;

    if (age <= p.establishmentEnd) {
      return RiceStage.establishment;
    }
    if (age <= p.vegetativeEnd) {
      return RiceStage.vegetative;
    }
    if (age <= p.reproductiveEnd) {
      return RiceStage.reproductive;
    }
    if (age < p.maturityDays) {
      return RiceStage.ripening;
    }
    return RiceStage.harvest;
  }

  void _updateCropAgeAndStage({bool rebuild = true}) {
    if (_plantingDate == null) {
      _cropAgeDays = 0;
      _selectedStage = RiceStage.notStarted;
      if (rebuild && mounted) setState(() {});
      return;
    }

    final today = _dateOnly(DateTime.now());
    final planted = _dateOnly(_plantingDate!);
    final diff = today.difference(planted).inDays;

    _cropAgeDays = diff < 0 ? 0 : diff;
    _selectedStage = _stageForAge(_cropAgeDays);

    if (rebuild && mounted) setState(() {});
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();

    DateTime? localDate;
    final savedDate = prefs.getString('guidance_planting_date');
    if (savedDate != null) {
      localDate = DateTime.tryParse(savedDate);
    }

    final savedType = prefs.getString('guidance_rice_type');
    RiceType localType = RiceType.inbred;
    if (savedType == RiceType.hybrid.name) {
      localType = RiceType.hybrid;
    }

    if (mounted) {
      setState(() {
        _plantingDate = localDate;
        _selectedType = localType;
      });
      _updateCropAgeAndStage();
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('crop_tracker')
          .doc(_cropTrackerDocId)
          .get();

      final data = doc.data();
      final firestoreDate = data?['plantingDate'];

      DateTime? cloudDate;
      if (firestoreDate is Timestamp) {
        cloudDate = firestoreDate.toDate();
      } else if (firestoreDate is String) {
        cloudDate = DateTime.tryParse(firestoreDate);
      }

      final cloudType =
          data?['riceType']?.toString().toLowerCase().trim() == 'hybrid'
              ? RiceType.hybrid
              : RiceType.inbred;

      if (!mounted) return;

      setState(() {
        if (cloudDate != null) _plantingDate = _dateOnly(cloudDate);
        _selectedType = cloudType;
      });

      if (_plantingDate != null) {
        await prefs.setString(
          'guidance_planting_date',
          _plantingDate!.toIso8601String(),
        );
      }
      await prefs.setString('guidance_rice_type', _selectedType.name);

      _updateCropAgeAndStage();
    } catch (_) {}

    final tasksJson = prefs.getString('guidance_completed_tasks');
    if (tasksJson != null) {
      try {
        final decoded = json.decode(tasksJson);
        if (decoded is Map<String, dynamic>) {
          _completedTasks = decoded.map(
            (key, value) => MapEntry(key, value == true),
          );
        }
      } catch (_) {}
    }

    if (mounted) setState(() {});
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();

    if (_plantingDate != null) {
      await prefs.setString(
        'guidance_planting_date',
        _dateOnly(_plantingDate!).toIso8601String(),
      );
    } else {
      await prefs.remove('guidance_planting_date');
    }

    await prefs.setString('guidance_rice_type', _selectedType.name);
    await prefs.setString(
      'guidance_completed_tasks',
      json.encode(_completedTasks),
    );

    try {
      final data = <String, dynamic>{
        'plantingDays': _cropAgeDays,
        'riceType': _selectedType.name,
        'riceTypeLabel': _selectedType.label,
        'referenceVariety': _selectedType.referenceVariety,
        'maturityDays': _selectedType.maturityDays,
        'cropStage': _selectedStage.label,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_plantingDate != null) {
        data['plantingDate'] =
            Timestamp.fromDate(_dateOnly(_plantingDate!));
      } else {
        data['plantingDate'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance
          .collection('crop_tracker')
          .doc(_cropTrackerDocId)
          .set(data, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _selectPlantingDate(DateTime selectedDate) async {
    final cleanDate = _dateOnly(selectedDate);

    setState(() {
      _plantingDate = cleanDate;
    });

    _updateCropAgeAndStage();
    await _saveData();

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openCalendar() async {
    WeatherEntity? currentWeather;
    try {
      currentWeather = await _weatherFuture;
    } catch (_) {}

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _PlantingDateDialog(
        initialDate: _plantingDate ?? _dateOnly(DateTime.now()),
        selectedDate: _plantingDate,
        onDateSelected: _selectPlantingDate,
        weatherData: currentWeather,
        profile: _profile,
      ),
    );
  }

  Future<void> _changeRiceType(RiceType? value) async {
    if (value == null) return;

    setState(() {
      _selectedType = value;
      _selectedStage = _stageForAge(_cropAgeDays);
    });

    await _saveData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GABAY SA PALAY',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              'Capalangan, Pampanga',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'I-refresh ang panahon',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _fetchWeather,
            ),
          ),
        ],
      ),
      body: FutureBuilder<WeatherEntity>(
        future: _weatherFuture,
        builder: (context, snapshot) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isDesktop = width >= 1000;
              final isTablet = width >= 700;
              final horizontalPadding = isDesktop
                  ? 32.0
                  : isTablet
                      ? 24.0
                      : 16.0;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  12,
                  horizontalPadding,
                  32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStatusCard(),
                        const SizedBox(height: 16),
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildDateCard()),
                              const SizedBox(width: 16),
                              Expanded(child: _buildRiceTypeCard()),
                            ],
                          )
                        else ...[
                          _buildDateCard(),
                          const SizedBox(height: 16),
                          _buildRiceTypeCard(),
                        ],
                        const SizedBox(height: 16),
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: _buildStageCard()),
                              const SizedBox(width: 16),
                              Expanded(flex: 7, child: _buildChecklistCard()),
                            ],
                          )
                        else ...[
                          _buildStageCard(),
                          const SizedBox(height: 16),
                          _buildChecklistCard(),
                        ],
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

  Widget _buildStatusCard() {
    final hasDate = _plantingDate != null;
    final isFuture = hasDate &&
        _dateOnly(_plantingDate!).isAfter(_dateOnly(DateTime.now()));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF059669),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  !hasDate
                      ? 'Pumili ng petsa ng tanim'
                      : isFuture
                          ? 'Nakatakdang magtanim'
                          : 'Araw $_cropAgeDays ng palay',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            !hasDate
                ? 'Piliin ang aktuwal na petsa ng pagtatanim.'
                : '${_formatDate(_plantingDate!)} • ${_selectedType.label} • '
                    '${_selectedType.maturityDays} araw na baseline',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
          if (hasDate) ...[
            const SizedBox(height: 8),
            Text(
              isFuture
                  ? 'Magsisimula ang Day 1 sa mismong napiling petsa.'
                  : 'Kasalukuyang yugto: ${_selectedStage.label}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📅 Petsa ng Pagtatanim',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Puwede mong baguhin ang petsa anumang oras. Ang Day, yugto, at maturity target ay awtomatikong nire-recalculate.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openCalendar,
              icon: const Icon(Icons.calendar_month_rounded),
              label: Text(
                _plantingDate == null
                    ? 'Pumili ng Petsa'
                    : 'Baguhin ang Petsa (${_formatDate(_plantingDate!)})',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiceTypeCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🌾 Uri ng Palay',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<RiceType>(
            value: _selectedType,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: RiceType.values
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(
                      type.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: _changeRiceType,
          ),
          const SizedBox(height: 8),
          Text(
            _selectedType.maturityNote,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🌱 Awtomatikong Yugto ng Tanim',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF059669),
                child: Icon(
                  _selectedStage.icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedStage.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_plantingDate != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Day $_cropAgeDays / ${_profile.maturityDays}',
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _plantingDate == null
                ? 0
                : (_cropAgeDays / _profile.maturityDays).clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 8),
          Text(
            'Target maturity: ${_profile.maturityDays} araw '
            '(${_selectedType.referenceVariety})',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistCard() {
    final tasks = _getTasksForStage(_selectedStage);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mga Gagawin • ${_selectedStage.label}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
          const Divider(),
          ...tasks.map(
            (task) {
              final checked = _completedTasks[task] ?? false;
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF059669),
                title: Text(
                  task,
                  style: TextStyle(
                    fontSize: 12,
                    decoration:
                        checked ? TextDecoration.lineThrough : null,
                    color: const Color(0xFF334155),
                  ),
                ),
                value: checked,
                onChanged: (value) {
                  setState(() {
                    _completedTasks[task] = value ?? false;
                  });
                  _saveData();
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }

  List<String> _getTasksForStage(RiceStage stage) {
    switch (stage) {
      case RiceStage.notStarted:
        return [
          'Pumili muna ng aktuwal na petsa ng pagtatanim.',
          'Tiyaking tama ang napiling uri: Inbred o Hybrid.',
        ];

      case RiceStage.establishment:
        return [
          'Bantayan ang batang palay laban sa golden apple snail at iba pang peste.',
          'Panatilihing maayos ang kondisyon ng tubig at field establishment.',
        ];

      case RiceStage.vegetative:
        return [
          'Regular na obserbahan ang pagsusuwi at kulay ng dahon.',
          'Gamitin ang Leaf Color Chart (LCC) kung bahagi ito ng iyong nutrient-management recommendation.',
        ];

      case RiceStage.reproductive:
        return [
          'Bantayan ang panicle initiation, pagbuo ng uhay, at pamumulaklak.',
          'Iangkop ang nitrogen management sa variety, crop establishment, tubig, lupa, at klima.',
        ];

      case RiceStage.ripening:
        return [
          'Bantayan ang paghinog ng butil at kondisyon ng taniman.',
          'Ihanda ang harvesting at drying equipment bago umabot sa maturity target.',
        ];

      case RiceStage.harvest:
        return [
          'Suriin ang maturity ng pananim bago mag-ani; huwag umasa sa calendar date lamang.',
          'Ihanda ang agarang pagpapatuyo pagkatapos ng ani.',
        ];
    }
  }
}

class _PlantingDateDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final WeatherEntity? weatherData;
  final _CropProfile profile;

  const _PlantingDateDialog({
    required this.initialDate,
    required this.selectedDate,
    required this.onDateSelected,
    this.weatherData,
    required this.profile,
  });

  @override
  State<_PlantingDateDialog> createState() => _PlantingDateDialogState();
}

class _PlantingDateDialogState extends State<_PlantingDateDialog> {
  late DateTime _focusedMonth;
  DateTime? _previewDate;

  @override
  void initState() {
    super.initState();
    _focusedMonth =
        DateTime(widget.initialDate.year, widget.initialDate.month, 1);
    _previewDate = widget.selectedDate ?? widget.initialDate;
  }

  String _monthName(int month) {
    const months = [
      'Enero',
      'Pebrero',
      'Marso',
      'Abril',
      'Mayo',
      'Hunyo',
      'Hulyo',
      'Agosto',
      'Setyembre',
      'Oktubre',
      'Nobyembre',
      'Disyembre',
    ];
    return months[month - 1];
  }

  String _formatShortDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';

  bool _sameDate(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Map<String, dynamic> _getPlantingSuitability(DateTime date) {
    final harvestDate = date.add(Duration(days: widget.profile.maturityDays));

    // 1. Weather Forecast Check para sa napiling araw
    if (widget.weatherData != null) {
      final condition = widget.weatherData!.condition?.toLowerCase() ?? '';
      if (condition.contains('rain') ||
          condition.contains('storm') ||
          condition.contains('heavy') ||
          condition.contains('thunder')) {
        return {
          'isGood': false,
          'color': const Color(0xFFEF4444), // RED
          'reason':
              'HINDI ADVISABLE: May inaasahang malakas na ulan o bagyo na pwedeng makasira o mahanaw ang binhi.',
        };
      }
    }

    // 2. TAGTUYOT / MATAAS NA INIT (Marso hanggang Abril)
    if (date.month == 3 || date.month == 4) {
      return {
        'isGood': false,
        'color': const Color(0xFFEF4444), // RED
        'reason':
            'HINDI ADVISABLE (Tagtuyot): Peak ng matinding init sa Capalangan. Mabilis matuyo ang patubig sa bukid at maaaring ma-heat stress ang palay.',
      };
    }

    // 3. PEAK NG BAHA AT HABAGAT (Hulyo hanggang Setyembre)
    if (date.month >= 7 && date.month <= 9) {
      return {
        'isGood': false,
        'color': const Color(0xFFEF4444), // RED
        'reason':
            'HINDI ADVISABLE (Peligro sa Baha): Ang crop duration (${_formatShortDate(date)} - ${_formatShortDate(harvestDate)}) ay tatapat sa peak ng Habagat at Bagyo sa Pampanga. Malaki ang posibilidad na malunod ang palay.',
      };
    }

    // 4. TRANSITION WINDOW (Huling kalahati ng Hunyo)
    if (date.month == 6 && date.day > 15) {
      return {
        'isGood': false,
        'color': const Color(0xFFEF4444), // RED
        'reason':
            'HINDI ADVISABLE: Ang pag-aani (${_formatShortDate(harvestDate)}) ay tatapat sa panahon ng bagyo at pag-apaw ng tubig sa Pampanga.',
      };
    }

    // 5. UNANG TANIM / EARLY WET SEASON (Mayo hanggang Gitna ng Hunyo)
    if (date.month == 5 || (date.month == 6 && date.day <= 15)) {
      return {
        'isGood': true,
        'color': const Color(0xFF059669), // GREEN
        'reason':
            'MAGANDANG MAGTANIM (Unang Tanim): Sapat ang ulan para sa pagpapatatag at makakahabol sa pag-ani (${_formatShortDate(harvestDate)}) bago ang matinding baha ng Agosto.',
      };
    }

    // 6. PANGALAWANG TANIM / DRY SEASON (Nobyembre hanggang Pebrero)
    if (date.month >= 11 || date.month <= 2) {
      return {
        'isGood': true,
        'color': const Color(0xFF059669), // GREEN
        'reason':
            'MAGANDANG MAGTANIM (Dry Season): Ligtas sa baha at bagyo. Aani ng ${_formatShortDate(harvestDate)}. Siguraduhin lamang ang sapat na irigasyon.',
      };
    }

    // Default Fallback
    return {
      'isGood': true,
      'color': const Color(0xFF059669), // GREEN
      'reason':
          'MAGANDANG MAGTANIM: Maayos ang panahon para sa pagpapalago ng palay hanggang sa pag-ani (${_formatShortDate(harvestDate)}).',
    };
  }

  void _confirmSelection(DateTime date, Map<String, dynamic> suitability) {
    if (!suitability['isGood']) {
      // Magpakita ng Warning Dialog kapag Pula (Not Advisable)
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Babala sa Pagtatanim',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Ang napili mong petsa (${_formatShortDate(date)}) ay HINDI ADVISABLE dahil:\n\n'
            '${suitability['reason']}\n\n'
            'Sigurado ka bang gusto mo pa ring itakda ang petsang ito?',
            style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Pumili ng Ibang Petsa'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                widget.onDateSelected(date);
              },
              child: const Text('Ipagpatuloy Pa Rin'),
            ),
          ],
        ),
      );
    } else {
      // Diretso select kapag Green
      widget.onDateSelected(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final days = DateUtils.getDaysInMonth(year, month);
    final first = DateTime(year, month, 1);
    final start = first.weekday % 7;

    final selectedInfo = _previewDate != null
        ? _getPlantingSuitability(_previewDate!)
        : null;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_monthName(month)} $year',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem(
                        const Color(0xFF059669), 'Magandang Magtanim'),
                    const SizedBox(width: 16),
                    _buildLegendItem(
                        const Color(0xFFEF4444), 'Hindi Advisable'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['Ling', 'Lun', 'Mar', 'Miy', 'Huw', 'Biy', 'Sab']
                      .map(
                        (day) => SizedBox(
                          width: 34,
                          child: Text(
                            day,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: start + days,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1.05,
                  ),
                  itemBuilder: (context, index) {
                    if (index < start) {
                      return const SizedBox.shrink();
                    }

                    final day = index - start + 1;
                    final date = DateTime(year, month, day);
                    final isPreviewed = _sameDate(_previewDate, date);
                    final isCurrentlySaved = _sameDate(widget.selectedDate, date);
                    final isToday = _sameDate(DateTime.now(), date);

                    final suitability = _getPlantingSuitability(date);
                    final Color statusColor = suitability['color'];

                    return InkWell(
                      onTap: () {
                        // Unang pindot: I-preview lang muna ang impormasyon
                        setState(() {
                          _previewDate = date;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isPreviewed
                              ? statusColor
                              : statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isPreviewed
                                ? statusColor
                                : isCurrentlySaved
                                    ? Colors.amber.shade700
                                    : isToday
                                        ? Colors.blueAccent
                                        : statusColor.withOpacity(0.4),
                            width: isPreviewed || isCurrentlySaved || isToday ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isPreviewed
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (selectedInfo != null && _previewDate != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (selectedInfo['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            (selectedInfo['color'] as Color).withOpacity(0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              selectedInfo['isGood']
                                  ? Icons.check_circle_rounded
                                  : Icons.warning_rounded,
                              color: selectedInfo['color'],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_formatShortDate(_previewDate!)} • ${selectedInfo['isGood'] ? 'Magandang Magtanim' : 'Hindi Advisable'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: selectedInfo['color'],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          selectedInfo['reason'],
                          style: TextStyle(
                            fontSize: 11,
                            color: selectedInfo['color'],
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedInfo['color'],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () {
                              _confirmSelection(_previewDate!, selectedInfo);
                            },
                            child: Text(
                              'Piliin ang Petsang Ito (${_formatShortDate(_previewDate!)})',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Isara'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}