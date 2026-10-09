import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HarvestBreakdownItem {
  String condition;
  TextEditingController kgController;
  TextEditingController srpController;
  /// Photos that belong ONLY to this condition/product row.
  /// Maximum of 9 photos per row.
  final List<XFile> imageFiles;

  HarvestBreakdownItem({
    required this.condition,
    required this.kgController,
    required this.srpController,
    List<XFile>? imageFiles,
  }) : imageFiles = imageFiles ?? [];
}

const Color _surfaceBg = Color(0xFFF8FAFC);
const Color _cardBg = Color(0xFFFFFFFF);
const Color _primaryGreen = Color(0xFF16A34A);
const Color _textPrimary = Color(0xFF0F172A);
const Color _textSecondary = Color(0xFF64748B);
const Color _borderLine = Color(0xFFE2E8F0);
const Color _warningOrange = Color(0xFFD97706);
const Color _dangerRed = Color(0xFFDC2626);
const Color _infoBlue = Color(0xFF2563EB);
const Color _primaryGreenSoft = Color(0xFFD1FAE5);

Widget _photoSourceButton({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: _surfaceBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _primaryGreenSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                color: _primaryGreen,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class InventoryInputPage extends StatefulWidget {
  const InventoryInputPage({super.key});

  @override
  State<InventoryInputPage> createState() => _InventoryInputPageState();
}

class _InventoryInputPageState extends State<InventoryInputPage> {
  final _controller = _InventoryInputController();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController totalCostController = TextEditingController();

  String selectedHectare = "Hectare 1";
  String selectedType = "Hybrid";
  final List<HarvestBreakdownItem> breakdownItems = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    breakdownItems.add(
      HarvestBreakdownItem(
        condition: _controller.riceConditions.first,
        kgController: TextEditingController(),
        srpController: TextEditingController(),
      ),
    );
  }

  @override
  void dispose() {
    descriptionController.dispose();
    totalCostController.dispose();
    for (final item in breakdownItems) {
      item.kgController.dispose();
      item.srpController.dispose();
    }
    super.dispose();
  }

  Future<void> _addBreakdownWithPhoto() async {
    final newItem = HarvestBreakdownItem(
      condition: _controller.riceConditions[
        breakdownItems.length % _controller.riceConditions.length
      ],
      kgController: TextEditingController(),
      srpController: TextEditingController(),
    );

    setState(() {
      breakdownItems.add(newItem);
    });

    await _pickMoreBreakdownPhotos(newItem);
  }

  Future<void> _pickMoreBreakdownPhotos(HarvestBreakdownItem item) async {
    if (!mounted || item.imageFiles.length >= 9) return;

    final remaining = 9 - item.imageFiles.length;

    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final picked = await _controller.picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (!mounted || picked.isEmpty) return;

      setState(() {
        item.imageFiles.addAll(picked.take(remaining));
      });
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Magdagdag ng larawan sa produktong ito",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Maaaring maglagay ng hanggang $remaining pang larawan.",
                style: const TextStyle(
                  fontSize: 12,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _photoSourceButton(
                      context: context,
                      icon: Icons.photo_library_outlined,
                      title: "Gallery",
                      subtitle: "Pumili ng larawan",
                      onTap: () => Navigator.of(sheetContext)
                          .pop(ImageSource.gallery),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _photoSourceButton(
                      context: context,
                      icon: Icons.photo_camera_outlined,
                      title: "Camera",
                      subtitle: "Kumuha ngayon",
                      onTap: () => Navigator.of(sheetContext)
                          .pop(ImageSource.camera),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || source == null) return;

    if (source == ImageSource.camera) {
      final picked = await _controller.picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (!mounted || picked == null) return;

      setState(() {
        if (item.imageFiles.length < 9) {
          item.imageFiles.add(picked);
        }
      });
      return;
    }

    final picked = await _controller.picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (!mounted || picked.isEmpty) return;

    setState(() {
      item.imageFiles.addAll(picked.take(remaining));
    });
  }

  void _removeBreakdownPhoto(HarvestBreakdownItem item, int photoIndex) {
    setState(() {
      item.imageFiles.removeAt(photoIndex);
    });
  }

  Widget _breakdownPhotoPicker(
    BuildContext context,
    HarvestBreakdownItem item,
  ) {
    final images = item.imageFiles;
    const double size = 64.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Mga Larawan ng Produkto",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Hanggang 9 na larawan • ${images.length}/9",
                      style: const TextStyle(
                        fontSize: 11,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (images.length < 9)
                OutlinedButton.icon(
                  onPressed: () => _pickMoreBreakdownPhotos(item),
                  icon: const Icon(
                    Icons.add_a_photo_outlined,
                    size: 14,
                  ),
                  label: const Text(
                    "Magdagdag",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryGreen,
                    side: const BorderSide(color: _primaryGreen),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (images.isEmpty)
            InkWell(
              onTap: () => _pickMoreBreakdownPhotos(item),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: size,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _surfaceBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _primaryGreen,
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: _primaryGreen,
                      size: 20,
                    ),
                    SizedBox(width: 6),
                    Text(
                      "Maglagay ng larawan",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  ...images.asMap().entries.map((entry) {
                    final photoIndex = entry.key;
                    final image = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8, top: 4),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: kIsWeb
                                ? Image.network(
                                    image.path,
                                    width: size,
                                    height: size,
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    File(image.path),
                                    width: size,
                                    height: size,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Material(
                              color: _dangerRed,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _removeBreakdownPhoto(
                                  item,
                                  photoIndex,
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(3),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double totalCost =
        double.tryParse(totalCostController.text) ?? 0.0;

    double sumKg = 0.0;
    double totalRevenue = 0.0;

    for (var item in breakdownItems) {
      final double kg = double.tryParse(item.kgController.text) ?? 0.0;
      final double srp = double.tryParse(item.srpController.text) ?? 0.0;
      sumKg += kg;
      totalRevenue += (kg * srp);
    }

    final double overallCostPerKg =
        sumKg > 0 ? totalCost / sumKg : 0.0;
    final double overallRevenuePerKg =
        sumKg > 0 ? totalRevenue / sumKg : 0.0;
    final double totalProfit = totalRevenue - totalCost;

    Widget sectionTitle(String title, {String? subtitle, Widget? action}) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action,
        ],
      );
    }

    InputDecoration compactDecoration({
      required String label,
      IconData? icon,
      Color? iconColor,
      bool green = false,
    }) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 12,
          color: _textSecondary,
        ),
        prefixIcon: icon == null
            ? null
            : Icon(
                icon,
                size: 16,
                color: iconColor ?? _textSecondary,
              ),
        filled: true,
        fillColor: green ? _primaryGreenSoft.withOpacity(0.28) : Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 8,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _borderLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: _primaryGreen,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _dangerRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: _dangerRed,
            width: 1.5,
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _surfaceBg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _surfaceBg,
        foregroundColor: _textPrimary,
        centerTitle: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Mag-input ng Ani & Puhunan",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "Ilagay ang detalye ng ani at gastos",
              style: TextStyle(
                fontSize: 12,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Close",
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 24),
            color: _textSecondary,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // DESCRIPTION CARD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderLine),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          sectionTitle(
                            "Description / Detalye ng Produkto",
                            subtitle: "Maikling detalye ng inyong ani",
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: descriptionController,
                            maxLines: 3,
                            maxLength: 1000,
                            style: const TextStyle(fontSize: 14),
                            textCapitalization: TextCapitalization.sentences,
                            decoration: compactDecoration(
                              label: "Description",
                              icon: Icons.description_outlined,
                              iconColor: _primaryGreen,
                            ).copyWith(
                              hintText:
                                  "Halimbawa: Premium quality palay, bagong ani, malinis at maayos ang pagkakaimbak...",
                              hintStyle: const TextStyle(
                                fontSize: 12,
                                color: _textSecondary,
                              ),
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // BASIC INPUT CARD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderLine),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          sectionTitle(
                            "Pangunahing Detalye",
                            subtitle: "Hectare, uri ng binhi, at puhunan",
                          ),
                          const SizedBox(height: 12),

                          const Text(
                            "Hectare",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),

                          Row(
                            children: ["Hectare 1", "Hectare 2"].map((h) {
                              final isSel = selectedHectare == h;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: h == "Hectare 1" ? 8.0 : 0,
                                  ),
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => selectedHectare = h),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 160),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: isSel
                                            ? _primaryGreenSoft
                                            : _surfaceBg,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSel
                                              ? _primaryGreen
                                              : _borderLine,
                                          width: isSel ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isSel) ...[
                                            const Icon(
                                              Icons.check_circle_rounded,
                                              size: 16,
                                              color: _primaryGreen,
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              h,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: isSel
                                                    ? _primaryGreen
                                                    : _textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 12),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedType,
                                  isDense: true,
                                  decoration: compactDecoration(
                                    label: "Uri ng Binhi",
                                    icon: Icons.grass_outlined,
                                    iconColor: _primaryGreen,
                                  ),
                                  items: _controller.riceTypes
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(
                                            e,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => selectedType = val);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: totalCostController,
                                  style: const TextStyle(fontSize: 12),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  validator: (v) =>
                                      (v == null || v.isEmpty) ? "Kailangan" : null,
                                  onChanged: (_) => setState(() {}),
                                  decoration: compactDecoration(
                                    label: "Puhunan / Capital",
                                    icon: Icons.payments_outlined,
                                    iconColor: _warningOrange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // BREAKDOWN CARD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderLine),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          sectionTitle(
                            "Condition / Uri ng Palay",
                            subtitle: "Ilagay ang kilos at SRP kada condition",
                            action: TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: _primaryGreen,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: _addBreakdownWithPhoto,
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                "+ Magdagdag",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          ...breakdownItems.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;

                            final double itemKg =
                                double.tryParse(item.kgController.text) ?? 0.0;
                            final double itemAllocatedCost = sumKg > 0
                                ? (itemKg / sumKg) * totalCost
                                : 0.0;
                            final double itemCostPerKg =
                                itemKg > 0 ? itemAllocatedCost / itemKg : 0.0;
                            final double itemSrp =
                                double.tryParse(item.srpController.text) ?? 0.0;
                            final double itemProfitPerKg =
                                itemSrp - itemCostPerKg;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _surfaceBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _borderLine),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: DropdownButtonFormField<String>(
                                          value: item.condition,
                                          isDense: true,
                                          decoration: compactDecoration(
                                            label: "Condition",
                                          ),
                                          items: _controller.riceConditions
                                              .map(
                                                (c) => DropdownMenuItem(
                                                  value: c,
                                                  child: Text(
                                                    c,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(
                                                () => item.condition = val,
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          controller: item.kgController,
                                          style: const TextStyle(fontSize: 11),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                          validator: (v) =>
                                              (v == null || v.isEmpty) ? "Kg" : null,
                                          onChanged: (_) => setState(() {}),
                                          decoration: compactDecoration(
                                            label: "Kilos (kg)",
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          controller: item.srpController,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                          validator: (v) => (v == null ||
                                                  v.isEmpty)
                                              ? "SRP"
                                              : null,
                                          onChanged: (_) => setState(() {}),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: _primaryGreen,
                                            fontSize: 11,
                                          ),
                                          decoration: compactDecoration(
                                            label: "SRP / kg",
                                            green: true,
                                          ),
                                        ),
                                      ),
                                      if (breakdownItems.length > 1)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 2, top: 4),
                                          child: IconButton(
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                              color: _dangerRed,
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                final removed =
                                                    breakdownItems.removeAt(idx);
                                                removed.kgController.dispose();
                                                removed.srpController.dispose();
                                              });
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _breakdownPhotoPicker(
                                    context,
                                    item,
                                  ),
                                  if (itemKg > 0 && totalCost > 0) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Puhunan Share: ₱${itemAllocatedCost.toStringAsFixed(2)}",
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: _warningOrange,
                                          ),
                                        ),
                                        Text(
                                          "Tubo / Profit/kg: ₱${itemProfitPerKg.toStringAsFixed(2)}",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: itemProfitPerKg >= 0
                                                ? _primaryGreen
                                                : _dangerRed,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // SUMMARY CARD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFF0FDF4),
                            Colors.white,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _primaryGreenSoft),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.auto_graph_rounded,
                                size: 18,
                                color: _primaryGreen,
                              ),
                              SizedBox(width: 6),
                              Text(
                                "Computation Details",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _summaryItem(
                                  "Kabuuang Kilo",
                                  "${sumKg.toStringAsFixed(0)} kg",
                                ),
                              ),
                              Expanded(
                                child: _summaryItem(
                                  "Avg Puhunan/kg",
                                  "₱${overallCostPerKg.toStringAsFixed(2)}",
                                  valueColor: _warningOrange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _summaryItem(
                                  "Estimated Gross/Benta",
                                  "₱${totalRevenue.toStringAsFixed(2)}",
                                  valueColor: _infoBlue,
                                ),
                              ),
                              Expanded(
                                child: _summaryItem(
                                  "Avg Tubo/kg",
                                  "₱${(overallRevenuePerKg - overallCostPerKg).toStringAsFixed(2)}",
                                  valueColor: totalProfit >= 0
                                      ? _primaryGreen
                                      : _dangerRed,
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1, color: _borderLine),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Tinatayang Tubo / Profit",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _textPrimary,
                                ),
                              ),
                              Text(
                                "₱${totalProfit.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: totalProfit >= 0
                                      ? _primaryGreen
                                      : _dangerRed,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // SAVE BUTTON
                    Align(
                      alignment: Alignment.center,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _primaryGreen.withOpacity(0.45),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          minimumSize: const Size(180, 42),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _isSaving
                            ? null
                            : () async {
                                if (!(_formKey.currentState?.validate() ?? false)) {
                                  return;
                                }

                                if (sumKg <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Mag-input ng timbang ng ani (kg).",
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      backgroundColor: _dangerRed,
                                    ),
                                  );
                                  return;
                                }

                                setState(() => _isSaving = true);

                                try {
                                  final String productName =
                                      "$selectedHectare - $selectedType Palay";

                                  final String uniqueCode =
                                      await _controller.generateStructuredCode(
                                    selectedHectare,
                                    selectedType,
                                  );

                                  final List<Map<String, dynamic>> breakdowns = [];

                                  for (int i = 0; i < breakdownItems.length; i++) {
                                    final item = breakdownItems[i];
                                    final double bKg = double.tryParse(
                                          item.kgController.text,
                                        ) ??
                                        0.0;
                                    final double bSrp = double.tryParse(
                                          item.srpController.text,
                                        ) ??
                                        0.0;
                                    final double bAllocatedCost = sumKg > 0
                                        ? (bKg / sumKg) * totalCost
                                        : 0.0;

                                    String breakdownImageUrl = '';
                                    List<String> breakdownImageUrls = [];

                                    if (item.imageFiles.isNotEmpty) {
                                      try {
                                        breakdownImageUrls =
                                            await _controller.uploadProductImages(
                                          item.imageFiles,
                                          '${uniqueCode}_breakdown_$i',
                                        );
                                        if (breakdownImageUrls.isNotEmpty) {
                                          breakdownImageUrl =
                                              breakdownImageUrls.first;
                                        }
                                      } catch (e, stackTrace) {
                                        debugPrint(
                                          "BREAKDOWN IMAGE UPLOAD FAILED: $e",
                                        );
                                        debugPrint(stackTrace.toString());
                                        if (context.mounted) {
                                          Navigator.of(context).pop(
                                            "Hindi ma-upload ang larawan ng ${item.condition}: $e",
                                          );
                                        }
                                        return;
                                      }
                                    }

                                    breakdowns.add({
                                      'condition': item.condition,
                                      'kg': bKg,
                                      'srp': bSrp,
                                      'allocatedCost': bAllocatedCost,
                                      'imageUrl': breakdownImageUrl,
                                      'imageUrls': breakdownImageUrls,
                                    });
                                  }

                                  final List<String> imageUrls = breakdowns
                                      .expand<String>(
                                        (b) => List<String>.from(
                                          b['imageUrls'] ?? const <String>[],
                                        ),
                                      )
                                      .toList();

                                  final Map<String, dynamic> newHarvestData = {
                                    'productCode': uniqueCode,
                                    'name': productName,
                                    'hectare': selectedHectare,
                                    'type': selectedType,
                                    'imageUrl': imageUrls.isNotEmpty
                                        ? imageUrls.first
                                        : '',
                                    'imageUrls': imageUrls,
                                    'description':
                                        descriptionController.text.trim(),
                                    'totalCost': totalCost,
                                    'breakdowns': breakdowns,
                                    'initialKg': sumKg,
                                    'remainingKg': sumKg,
                                    'totalKg': sumKg,
                                    'isDeleted': false,
                                    'createdAt': FieldValue.serverTimestamp(),
                                  };

                                  await FirebaseFirestore.instance
                                      .collection("products")
                                      .add(newHarvestData);

                                  if (context.mounted) {
                                    Navigator.of(context).pop(true);
                                  }
                                } catch (e, stackTrace) {
                                  debugPrint("SAVE INVENTORY ERROR: $e");
                                  debugPrint(stackTrace.toString());

                                  if (context.mounted) {
                                    Navigator.of(context).pop(
                                      "Hindi na-save ang Inventory: $e",
                                    );
                                  }
                                }
                              },
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Row(
                            key: ValueKey(_isSaving),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isSaving) ...[
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ] else ...[
                                const Icon(
                                  Icons.save_rounded,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                _isSaving
                                    ? "Isina-save..."
                                    : "I-save sa Inventory",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryItem(
    String label,
    String value, {
    Color valueColor = _textPrimary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: _textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: valueColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _InventoryInputController {
  final ImagePicker picker = ImagePicker();
  final List<String> riceTypes = const ["Hybrid", "Inbred"];
  final List<String> riceConditions = const ["Basa / Sariwa", "Tuyo"];

  Future<List<String>> uploadProductImages(
    List<XFile> imageFiles,
    String productCode,
  ) async {
    final supabase = Supabase.instance.client;
    final List<String> urls = [];

    for (int i = 0; i < imageFiles.length; i++) {
      final xfile = imageFiles[i];
      final extension = xfile.path.split('.').last.toLowerCase();
      final safeExtension =
          ['jpg', 'jpeg', 'png', 'webp'].contains(extension)
              ? extension
              : 'jpg';
      final contentType =
          safeExtension == 'jpg' || safeExtension == 'jpeg'
              ? 'image/jpeg'
              : 'image/$safeExtension';

      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final filePath =
          'products/${productCode.toString().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}/${timestamp}_$i.$safeExtension';

      final bytes = await xfile.readAsBytes();

      await supabase.storage.from('product-images').uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(
          cacheControl: '31536000',
          contentType: contentType,
          upsert: false,
        ),
      );

      final publicUrl =
          supabase.storage.from('product-images').getPublicUrl(filePath);
      urls.add(publicUrl);
    }

    return urls;
  }

  Future<String> generateStructuredCode(String hectare, String type) async {
    final String hectarePrefix = hectare.replaceAll(" ", "").toUpperCase();
    final String typePrefix =
        type.toUpperCase().padRight(3, 'X').substring(0, 3);

    final now = DateTime.now();
    final String dateStamp =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    final String baseCodePattern = "$hectarePrefix-$typePrefix-$dateStamp";

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection("products")
          .where("hectare", isEqualTo: hectare)
          .where("type", isEqualTo: type)
          .get();

      final int sequenceNumber = querySnapshot.docs.length + 1;
      final String sequenceStr = sequenceNumber.toString().padLeft(3, '0');
      return "$baseCodePattern-$sequenceStr";
    } catch (e) {
      debugPrint("CODE GENERATION QUERY FAILED: $e");
      return "$baseCodePattern-${now.millisecondsSinceEpoch % 1000000}";
    }
  }
}