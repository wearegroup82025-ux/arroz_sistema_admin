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

  HarvestBreakdownItem({
    required this.condition,
    required this.kgController,
    required this.srpController,
  });
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

Widget _buildMultiPhotoPicker({
  required BuildContext context,
  required List<XFile> images,
  required StateSetter setModalState,
  required ImagePicker picker,
  String title = "Mga Larawan ng Produkto (Opsyonal)",
  String subtitle = "Puwedeng pumili ng hanggang 9 na larawan",
}) {
  final media = MediaQuery.of(context);
  final screenWidth = media.size.width;
  final scale = screenWidth / 375;

  Future<void> openImageSourcePicker() async {
    if (images.length >= 9) return;

    // Kung tumatakbo sa Web o PC/Desktop, rekta na sa Gallery / File Explorer
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final remaining = 9 - images.length;
      if (remaining <= 0) return;

      final picked = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (picked.isEmpty) return;

      setModalState(() {
        images.addAll(picked.take(remaining));
      });
      return;
    }

    // Para sa Mobile (Android/iOS)
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      useSafeArea: true,
      builder: (sheetContext) {
        return Container(
          margin: EdgeInsets.fromLTRB(
            screenWidth * 0.026,
            0,
            screenWidth * 0.026,
            screenWidth * 0.026,
          ),
          padding: EdgeInsets.fromLTRB(
            screenWidth * 0.032,
            screenWidth * 0.026,
            screenWidth * 0.032,
            screenWidth * 0.032,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(
              Radius.circular(screenWidth * 0.053),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: screenWidth * 0.096,
                height: screenWidth * 0.010,
                decoration: BoxDecoration(
                  color: _borderLine,
                  borderRadius: BorderRadius.circular(screenWidth * 0.26),
                ),
              ),
              SizedBox(height: screenWidth * 0.032),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Paano magdagdag ng larawan?",
                  style: TextStyle(
                    fontSize: 13 * scale,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
              ),
              SizedBox(height: screenWidth * 0.008),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Pumili mula sa gallery/PC storage o kumuha ng bagong larawan.",
                  style: TextStyle(
                    fontSize: 9.5 * scale,
                    color: _textSecondary,
                  ),
                ),
              ),
              SizedBox(height: screenWidth * 0.032),
              Row(
                children: [
                  Expanded(
                    child: _photoSourceButton(
                      context: context,
                      icon: Icons.photo_library_outlined,
                      title: "Files / Gallery",
                      subtitle: "Pumili mula sa storage",
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
              SizedBox(height: screenWidth * 0.010),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    if (source == ImageSource.camera) {
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (picked == null) return;

      setModalState(() {
        if (images.length < 9) {
          images.add(picked);
        }
      });
      return;
    }

    final remaining = 9 - images.length;
    if (remaining <= 0) return;

    final picked = await picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (picked.isEmpty) return;

    setModalState(() {
      images.addAll(picked.take(remaining));
    });
  }

  final double boxDimension = screenWidth * 0.28;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11 * scale,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          Text(
            "${images.length}/9",
            style: TextStyle(
              fontSize: 10 * scale,
              color: _textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      SizedBox(height: screenWidth * 0.010),
      Text(
        subtitle,
        style: TextStyle(fontSize: 10 * scale, color: _textSecondary),
      ),
      SizedBox(height: screenWidth * 0.021),
      SizedBox(
        height: boxDimension,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: images.length < 9 ? images.length + 1 : images.length,
          separatorBuilder: (_, __) => SizedBox(width: screenWidth * 0.021),
          itemBuilder: (context, index) {
            if (index == images.length && images.length < 9) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(screenWidth * 0.026),
                  onTap: openImageSourcePicker,
                  child: Container(
                    width: boxDimension,
                    decoration: BoxDecoration(
                      color: _surfaceBg,
                      borderRadius: BorderRadius.circular(screenWidth * 0.026),
                      border: Border.all(
                        color: _primaryGreen,
                        width: screenWidth * 0.0032,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: _primaryGreen,
                          size: 28 * scale,
                        ),
                        SizedBox(height: screenWidth * 0.010),
                        Text(
                          "Magdagdag",
                          style: TextStyle(
                            fontSize: 10 * scale,
                            color: _primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final xfile = images[index];
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(screenWidth * 0.026),
                  child: kIsWeb
                      ? Image.network(
                          xfile.path,
                          width: boxDimension,
                          height: boxDimension,
                          fit: BoxFit.cover,
                        )
                      : Image.file(
                          File(xfile.path),
                          width: boxDimension,
                          height: boxDimension,
                          fit: BoxFit.cover,
                        ),
                ),
                Positioned(
                  top: screenWidth * 0.010,
                  right: screenWidth * 0.010,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () =>
                          setModalState(() => images.removeAt(index)),
                      child: SizedBox(
                        width: screenWidth * 0.066,
                        height: screenWidth * 0.066,
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16 * scale,
                        ),
                      ),
                    ),
                  ),
                ),
                if (index == 0)
                  Positioned(
                    left: screenWidth * 0.013,
                    bottom: screenWidth * 0.013,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.016,
                        vertical: screenWidth * 0.008,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryGreen,
                        borderRadius: BorderRadius.circular(screenWidth * 0.013),
                      ),
                      child: Text(
                        "MAIN",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8 * scale,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      if (images.isEmpty)
        Padding(
          padding: EdgeInsets.only(top: screenWidth * 0.018),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(screenWidth * 0.024),
            decoration: BoxDecoration(
              color: _infoBlueBg,
              borderRadius: BorderRadius.circular(screenWidth * 0.021),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 15 * scale, color: _infoBlue),
                SizedBox(width: screenWidth * 0.018),
                Expanded(
                  child: Text(
                    "Opsyonal: Maaari kang mag-upload ng mga larawan mula sa PC o mobile kung mayroon.",
                    style: TextStyle(fontSize: 10 * scale, color: _infoBlue),
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

Widget _photoSourceButton({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  final media = MediaQuery.of(context);
  final screenWidth = media.size.width;
  final scale = screenWidth / 375;

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
  final List<XFile> selectedImages = [];
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

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final scale = screenWidth / 375;

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
                // PHOTO CARD
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(screenWidth * 0.032),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(screenWidth * 0.037),
                    border: Border.all(color: _borderLine),
                  ),
                  child: _buildMultiPhotoPicker(
                    context: context,
                    images: selectedImages,
                    setModalState: setState,
                    picker: _controller.picker,
                    title: "Mga Larawan ng Produkto (Opsyonal)",
                    subtitle: "Puwedeng pumili ng hanggang 9 na larawan",
                  ),
                ),

                SizedBox(height: screenWidth * 0.026),

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
                          onPressed: () {
                            setState(() {
                              breakdownItems.add(
                                HarvestBreakdownItem(
                                  condition: _controller.riceConditions[
                                      breakdownItems.length %
                                          _controller.riceConditions.length],
                                  kgController: TextEditingController(),
                                  srpController: TextEditingController(),
                                ),
                              );
                            });
                          },
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

                              final List<Map<String, dynamic>> breakdowns =
                                  breakdownItems.map((item) {
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

                                return {
                                  'condition': item.condition,
                                  'kg': bKg,
                                  'srp': bSrp,
                                  'allocatedCost': bAllocatedCost,
                                };
                              }).toList();

                              List<String> imageUrls = [];

                              if (selectedImages.isNotEmpty) {
                                try {
                                  imageUrls =
                                      await _controller.uploadProductImages(
                                    selectedImages,
                                    uniqueCode,
                                  );
                                } catch (e, stackTrace) {
                                  debugPrint(
                                    "MULTIPLE IMAGE UPLOAD FAILED: $e",
                                  );
                                  debugPrint(stackTrace.toString());

                                  if (context.mounted) {
                                    Navigator.of(context).pop(
                                      "Hindi ma-upload ang mga larawan: $e",
                                    );
                                  }
                                  return;
                                }
                              }

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
    final scale = screenWidth / 375;

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