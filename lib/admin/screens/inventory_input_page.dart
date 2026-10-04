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
const Color _infoBlueBg = Color(0xFFEFF6FF);
const Color _primaryGreenSoft = Color(0xFFD1FAE5);

Widget _photoSourceButton({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  final media = MediaQuery.of(context);
  final screenWidth = media.size.width;
  final scale = (screenWidth / 375).clamp(0.90, 1.15);

  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(screenWidth * 0.032),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.026,
          vertical: screenWidth * 0.029,
        ),
        decoration: BoxDecoration(
          color: _surfaceBg,
          borderRadius: BorderRadius.circular(screenWidth * 0.032),
          border: Border.all(color: _borderLine),
        ),
        child: Row(
          children: [
            Container(
              width: screenWidth * 0.096,
              height: screenWidth * 0.096,
              decoration: BoxDecoration(
                color: _primaryGreenSoft,
                borderRadius: BorderRadius.circular(screenWidth * 0.026),
              ),
              child: Icon(
                icon,
                color: _primaryGreen,
                size: 19 * scale,
              ),
            ),
            SizedBox(width: screenWidth * 0.021),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11 * scale,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.0026),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 8.5 * scale,
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

    // Every newly added product/condition gets its own photo picker.
    // It can contain up to 9 photos and never shares photos with another row.
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

    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final scale = (screenWidth / 375).clamp(0.90, 1.15);

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetContext) {
        return Container(
          margin: EdgeInsets.fromLTRB(
            screenWidth * 0.026,
            0,
            screenWidth * 0.026,
            screenWidth * 0.026,
          ),
          padding: EdgeInsets.all(screenWidth * 0.032),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(screenWidth * 0.053),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Magdagdag ng larawan para sa produktong ito",
                style: TextStyle(
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              SizedBox(height: screenWidth * 0.010),
              Text(
                "Maaari kang maglagay ng hanggang $remaining pang larawan.",
                style: TextStyle(
                  fontSize: 9.5 * scale,
                  color: _textSecondary,
                ),
              ),
              SizedBox(height: screenWidth * 0.032),
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
                  SizedBox(width: screenWidth * 0.021),
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
    double screenWidth,
    double scale,
  ) {
    final images = item.imageFiles;
    final size = (screenWidth * 0.18).clamp(72.0, 96.0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(screenWidth * 0.021),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(screenWidth * 0.024),
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
                    Text(
                      "Mga Larawan ng Produktong Ito",
                      style: TextStyle(
                        fontSize: 10.5 * scale,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    SizedBox(height: screenWidth * 0.0053),
                    Text(
                      "Hanggang 9 na larawan • ${images.length}/9",
                      style: TextStyle(
                        fontSize: 8.5 * scale,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (images.length < 9)
                OutlinedButton.icon(
                  onPressed: () => _pickMoreBreakdownPhotos(item),
                  icon: Icon(
                    Icons.add_a_photo_outlined,
                    size: 14 * scale,
                  ),
                  label: Text(
                    "Magdagdag",
                    style: TextStyle(fontSize: 8.5 * scale),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryGreen,
                    side: const BorderSide(color: _primaryGreen),
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.018,
                      vertical: screenWidth * 0.012,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          SizedBox(height: screenWidth * 0.018),
          if (images.isEmpty)
            InkWell(
              onTap: () => _pickMoreBreakdownPhotos(item),
              borderRadius: BorderRadius.circular(screenWidth * 0.021),
              child: Container(
                height: size,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _surfaceBg,
                  borderRadius: BorderRadius.circular(screenWidth * 0.021),
                  border: Border.all(
                    color: _primaryGreen,
                    width: screenWidth * 0.0026,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: _primaryGreen,
                      size: 24 * scale,
                    ),
                    SizedBox(width: screenWidth * 0.016),
                    Text(
                      "Maglagay ng larawan",
                      style: TextStyle(
                        fontSize: 9.5 * scale,
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
              child: Row(
                children: [
                  ...images.asMap().entries.map((entry) {
                    final photoIndex = entry.key;
                    final image = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        right: screenWidth * 0.016,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(screenWidth * 0.021),
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
                            right: -5,
                            top: -5,
                            child: Material(
                              color: _dangerRed,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => _removeBreakdownPhoto(
                                  item,
                                  photoIndex,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 12 * scale,
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
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final scale = (screenWidth / 375).clamp(0.90, 1.15);

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
                  style: TextStyle(
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: screenWidth * 0.0053),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9.5 * scale,
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
        labelStyle: TextStyle(
          fontSize: 10.5 * scale,
          color: _textSecondary,
        ),
        prefixIcon: icon == null
            ? null
            : Icon(
                icon,
                size: 16 * scale,
                color: iconColor ?? _textSecondary,
              ),
        filled: true,
        fillColor: green ? _primaryGreenSoft.withOpacity(0.28) : Colors.white,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.026,
          vertical: screenWidth * 0.026,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.024),
          borderSide: const BorderSide(color: _borderLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.024),
          borderSide: BorderSide(
            color: _primaryGreen,
            width: screenWidth * 0.0034,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.024),
          borderSide: const BorderSide(color: _dangerRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(screenWidth * 0.024),
          borderSide: BorderSide(
            color: _dangerRed,
            width: screenWidth * 0.0032,
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
        titleSpacing: screenWidth * 0.042,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Bagong Input",
              style: TextStyle(
                fontSize: 17 * scale,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            SizedBox(height: screenWidth * 0.0026),
            Text(
              "Ani at puhunan",
              style: TextStyle(
                fontSize: 9.5 * scale,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Isara",
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            color: _textSecondary,
          ),
          SizedBox(width: screenWidth * 0.016),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              screenWidth * 0.037,
              screenWidth * 0.010,
              screenWidth * 0.037,
              screenWidth * 0.048,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // DESCRIPTION CARD
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(screenWidth * 0.032),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(screenWidth * 0.037),
                    border: Border.all(color: _borderLine),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionTitle(
                        "Deskripsyon ng Produkto",
                        subtitle: "Maikling detalye na makikita sa product page",
                      ),
                      SizedBox(height: screenWidth * 0.021),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 4,
                        maxLength: 1000,
                        scrollPadding: EdgeInsets.only(bottom: screenWidth * 0.32),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: compactDecoration(
                          label: "Deskripsyon",
                          icon: Icons.description_outlined,
                          iconColor: _primaryGreen,
                        ).copyWith(
                          hintText:
                              "Halimbawa: Premium quality palay, bagong ani, malinis at maayos ang pagkakaimbak...",
                          hintStyle: TextStyle(
                            fontSize: 10.5 * scale,
                            color: _textSecondary,
                          ),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: screenWidth * 0.026),

                // BASIC INPUT CARD
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(screenWidth * 0.032),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(screenWidth * 0.037),
                    border: Border.all(color: _borderLine),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionTitle(
                        "Pangunahing Detalye",
                        subtitle: "Hectare, uri ng binhi, at puhunan",
                      ),
                      SizedBox(height: screenWidth * 0.026),

                      Text(
                        "Hectare",
                        style: TextStyle(
                          fontSize: 10 * scale,
                          fontWeight: FontWeight.w700,
                          color: _textSecondary,
                        ),
                      ),
                      SizedBox(height: screenWidth * 0.013),

                      Row(
                        children: ["Hectare 1", "Hectare 2"].map((h) {
                          final isSel = selectedHectare == h;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: h == "Hectare 1" ? screenWidth * 0.016 : 0,
                              ),
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => selectedHectare = h),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding: EdgeInsets.symmetric(
                                      vertical: screenWidth * 0.026),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? _primaryGreenSoft
                                        : _surfaceBg,
                                    borderRadius:
                                        BorderRadius.circular(screenWidth * 0.024),
                                    border: Border.all(
                                      color: isSel
                                          ? _primaryGreen
                                          : _borderLine,
                                      width: isSel
                                          ? screenWidth * 0.0034
                                          : screenWidth * 0.0026,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (isSel) ...[
                                        Icon(
                                          Icons.check_circle_rounded,
                                          size: 14 * scale,
                                          color: _primaryGreen,
                                        ),
                                        SizedBox(width: screenWidth * 0.013),
                                      ],
                                      Text(
                                        h,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11 * scale,
                                          color: isSel
                                              ? _primaryGreen
                                              : _textSecondary,
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

                      SizedBox(height: screenWidth * 0.026),

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
                                        style: TextStyle(fontSize: 11 * scale),
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
                          SizedBox(width: screenWidth * 0.021),
                          Expanded(
                            child: TextFormField(
                              controller: totalCostController,
                              scrollPadding: EdgeInsets.only(bottom: screenWidth * 0.32),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? "Kailangan" : null,
                              onChanged: (_) => setState(() {}),
                              decoration: compactDecoration(
                                label: "Puhunan",
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

                SizedBox(height: screenWidth * 0.026),

                // BREAKDOWN CARD
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(screenWidth * 0.032),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(screenWidth * 0.037),
                    border: Border.all(color: _borderLine),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionTitle(
                        "Klasipikasyon / Kondisyon",
                        subtitle: "Ilagay ang kg at SRP kada kondisyon",
                        action: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: _primaryGreen,
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.016,
                              vertical: screenWidth * 0.008,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _addBreakdownWithPhoto,
                          icon: Icon(
                            Icons.add_circle_outline_rounded,
                            size: 15 * scale,
                          ),
                          label: Text(
                            "Magdagdag",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5 * scale,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: screenWidth * 0.021),

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
                          margin: EdgeInsets.only(bottom: screenWidth * 0.018),
                          padding: EdgeInsets.all(screenWidth * 0.021),
                          decoration: BoxDecoration(
                            color: _surfaceBg,
                            borderRadius: BorderRadius.circular(screenWidth * 0.029),
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
                                        label: "Kondisyon",
                                      ),
                                      items: _controller.riceConditions
                                          .map(
                                            (c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(
                                                c,
                                                style: TextStyle(
                                                  fontSize: 10.5 * scale,
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
                                  SizedBox(width: screenWidth * 0.013),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: item.kgController,
                                      scrollPadding: EdgeInsets.only(bottom: screenWidth * 0.32),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      validator: (v) =>
                                          (v == null || v.isEmpty) ? "Kg" : null,
                                      onChanged: (_) => setState(() {}),
                                      decoration: compactDecoration(
                                        label: "Nakuha (kg)",
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: screenWidth * 0.013),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: item.srpController,
                                      scrollPadding: EdgeInsets.only(bottom: screenWidth * 0.32),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      validator: (v) => (v == null ||
                                              v.isEmpty)
                                          ? "SRP"
                                          : null,
                                      onChanged: (_) => setState(() {}),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: _primaryGreen,
                                        fontSize: 11 * scale,
                                      ),
                                      decoration: compactDecoration(
                                        label: "SRP / kg",
                                        green: true,
                                      ),
                                    ),
                                  ),
                                  if (breakdownItems.length > 1)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left: screenWidth * 0.0053,
                                        top: screenWidth * 0.021,
                                      ),
                                      child: IconButton(
                                        constraints: BoxConstraints(
                                          minWidth: screenWidth * 0.064,
                                          minHeight: screenWidth * 0.064,
                                        ),
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          Icons.remove_circle_outline,
                                          color: _dangerRed,
                                          size: 18 * scale,
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
                              SizedBox(height: screenWidth * 0.018),
                              _breakdownPhotoPicker(
                                context,
                                item,
                                screenWidth,
                                scale,
                              ),
                              if (itemKg > 0 && totalCost > 0) ...[
                                SizedBox(height: screenWidth * 0.013),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Puhunan: ₱${itemAllocatedCost.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        fontSize: 9 * scale,
                                        color: _warningOrange,
                                      ),
                                    ),
                                    Text(
                                      "Tubó/kg: ₱${itemProfitPerKg.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        fontSize: 9 * scale,
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

                SizedBox(height: screenWidth * 0.026),

                // SUMMARY CARD
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(screenWidth * 0.032),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF0FDF4),
                        Colors.white,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(screenWidth * 0.037),
                    border: Border.all(color: _primaryGreenSoft),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_graph_rounded,
                            size: 16 * scale,
                            color: _primaryGreen,
                          ),
                          SizedBox(width: screenWidth * 0.013),
                          Text(
                            "Awtomatikong Tantiya",
                            style: TextStyle(
                              fontSize: 11.5 * scale,
                              fontWeight: FontWeight.w800,
                              color: _textPrimary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenWidth * 0.021),
                      Row(
                        children: [
                          Expanded(
                            child: _summaryItem(
                              context,
                              "Kabuuang Ani",
                              "${sumKg.toStringAsFixed(0)} kg",
                            ),
                          ),
                          Expanded(
                            child: _summaryItem(
                              context,
                              "Avg Puhunan/kg",
                              "₱${overallCostPerKg.toStringAsFixed(2)}",
                              valueColor: _warningOrange,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: screenWidth * 0.018),
                      Row(
                        children: [
                          Expanded(
                            child: _summaryItem(
                              context,
                              "Inaasahang Gross",
                              "₱${totalRevenue.toStringAsFixed(2)}",
                              valueColor: _infoBlue,
                            ),
                          ),
                          Expanded(
                            child: _summaryItem(
                              context,
                              "Avg Tubó/kg",
                              "₱${(overallRevenuePerKg - overallCostPerKg).toStringAsFixed(2)}",
                              valueColor: totalProfit >= 0
                                  ? _primaryGreen
                                  : _dangerRed,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: screenWidth * 0.018),
                        child: const Divider(height: 1, color: _borderLine),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Inaasahang Malinis na Tubó",
                            style: TextStyle(
                              fontSize: 10.5 * scale,
                              fontWeight: FontWeight.w800,
                              color: _textPrimary,
                            ),
                          ),
                          Text(
                            "₱${totalProfit.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 15 * scale,
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

                SizedBox(height: screenWidth * 0.032),

                // SAVE BUTTON
                SizedBox(
                  width: double.infinity,
                  height: screenWidth * 0.128,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _primaryGreen.withOpacity(0.45),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(screenWidth * 0.032),
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

                                // Each breakdown/product has its OWN set of up to 9 images.
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

                              // The product-level image list is now built from
                              // the photos of each condition/product row. This
                              // keeps every row independent while preserving
                              // compatibility with existing product-page code.
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
                                  "Hindi na-save ang inventory: $e",
                                );
                              }
                            }
                          },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Row(
                        key: ValueKey(_isSaving),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isSaving) ...[
                            SizedBox(
                              width: screenWidth * 0.042,
                              height: screenWidth * 0.042,
                              child: CircularProgressIndicator(
                                strokeWidth: screenWidth * 0.0053,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.021),
                          ] else ...[
                            Icon(
                              Icons.save_rounded,
                              size: 18 * scale,
                            ),
                            SizedBox(width: screenWidth * 0.018),
                          ],
                          Text(
                            _isSaving
                                ? "Sine-save..."
                                : "I-save sa Inbentaryo",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5 * scale,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: screenWidth * 0.010),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryItem(
    BuildContext context,
    String label,
    String value, {
    Color valueColor = _textPrimary,
  }) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final scale = (screenWidth / 375).clamp(0.90, 1.15);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 8.5 * scale,
            color: _textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: screenWidth * 0.0053),
        Text(
          value,
          style: TextStyle(
            fontSize: 11 * scale,
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