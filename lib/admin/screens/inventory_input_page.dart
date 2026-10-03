import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  required List<File> images,
  required StateSetter setModalState,
  required ImagePicker picker,
  String title = "Mga Larawan ng Produkto",
  String subtitle = "Puwedeng pumili ng hanggang 9 na larawan",
}) {
  Future<void> openImageSourcePicker() async {
    if (images.length >= 9) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      useSafeArea: true,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _borderLine,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Paano magdagdag ng larawan?",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Pumili mula sa gallery o kumuha ng bagong larawan.",
                  style: TextStyle(
                    fontSize: 9.5,
                    color: _textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _photoSourceButton(
                      icon: Icons.photo_library_outlined,
                      title: "Gallery",
                      subtitle: "Pumili ng marami",
                      onTap: () => Navigator.of(sheetContext)
                          .pop(ImageSource.gallery),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _photoSourceButton(
                      icon: Icons.photo_camera_outlined,
                      title: "Camera",
                      subtitle: "Kumuha ngayon",
                      onTap: () => Navigator.of(sheetContext)
                          .pop(ImageSource.camera),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
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
          images.add(File(picked.path));
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
      images.addAll(
        picked.take(remaining).map((x) => File(x.path)),
      );
    });
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          Text(
            "${images.length}/9",
            style: const TextStyle(
              fontSize: 10,
              color: _textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: const TextStyle(fontSize: 10, color: _textSecondary),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 105,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: images.length < 9 ? images.length + 1 : images.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            if (index == images.length && images.length < 9) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: openImageSourcePicker,
                  child: Container(
                    width: 105,
                    decoration: BoxDecoration(
                      color: _surfaceBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _primaryGreen,
                        width: 1.2,
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: _primaryGreen,
                          size: 28,
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Magdagdag",
                          style: TextStyle(
                            fontSize: 10,
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

            final file = images[index];
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    file,
                    width: 105,
                    height: 105,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () =>
                          setModalState(() => images.removeAt(index)),
                      child: const SizedBox(
                        width: 25,
                        height: 25,
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                if (index == 0)
                  Positioned(
                    left: 5,
                    bottom: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryGreen,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        "MAIN",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
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
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _infoBlueBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 15, color: _infoBlue),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    "Tip: Mag-upload ng 3–6 malinaw na larawan para mas professional ang product page.",
                    style: TextStyle(fontSize: 10, color: _infoBlue),
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
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: _surfaceBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderLine),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _primaryGreenSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: _primaryGreen,
                size: 19,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 8.5,
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
  final List<File> selectedImages = [];
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
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 9.5,
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
          fontSize: 10.5,
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
          horizontal: 10,
          vertical: 10,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: _borderLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(
            color: _primaryGreen,
            width: 1.3,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: _dangerRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(
            color: _dangerRed,
            width: 1.2,
          ),
        ),
      );
    }

    return Scaffold(
      // Let Flutter shrink the viewport when the keyboard opens so the
      // focused field can be scrolled into view instead of being covered.
      resizeToAvoidBottomInset: true,
      backgroundColor: _surfaceBg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _surfaceBg,
        foregroundColor: _textPrimary,
        centerTitle: false,
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Bagong Input",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            SizedBox(height: 1),
            Text(
              "Ani at puhunan",
              style: TextStyle(
                fontSize: 9.5,
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
          const SizedBox(width: 6),
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
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PHOTO CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _borderLine),
                  ),
                  child: _buildMultiPhotoPicker(
                    context: context,
                    images: selectedImages,
                    setModalState: setState,
                    picker: _controller.picker,
                    title: "Mga Larawan ng Produkto",
                    subtitle: "Puwedeng pumili ng hanggang 9 na larawan",
                  ),
                ),

                const SizedBox(height: 10),

                // DESCRIPTION CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _borderLine),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionTitle(
                        "Deskripsyon ng Produkto",
                        subtitle: "Maikling detalye na makikita sa product page",
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 4,
                        maxLength: 1000,
                        scrollPadding: const EdgeInsets.only(bottom: 120),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: compactDecoration(
                          label: "Deskripsyon",
                          icon: Icons.description_outlined,
                          iconColor: _primaryGreen,
                        ).copyWith(
                          hintText:
                              "Halimbawa: Premium quality palay, bagong ani, malinis at maayos ang pagkakaimbak...",
                          hintStyle: const TextStyle(
                            fontSize: 10.5,
                            color: _textSecondary,
                          ),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // BASIC INPUT CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _borderLine),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      sectionTitle(
                        "Pangunahing Detalye",
                        subtitle: "Hectare, uri ng binhi, at puhunan",
                      ),
                      const SizedBox(height: 10),

                      const Text(
                        "Hectare",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _textSecondary,
                        ),
                      ),
                      const SizedBox(height: 5),

                      Row(
                        children: ["Hectare 1", "Hectare 2"].map((h) {
                          final isSel = selectedHectare == h;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: h == "Hectare 1" ? 6 : 0,
                              ),
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => selectedHectare = h),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? _primaryGreenSoft
                                        : _surfaceBg,
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                      color: isSel
                                          ? _primaryGreen
                                          : _borderLine,
                                      width: isSel ? 1.3 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (isSel) ...[
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 14,
                                          color: _primaryGreen,
                                        ),
                                        const SizedBox(width: 5),
                                      ],
                                      Text(
                                        h,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
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

                      const SizedBox(height: 10),

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
                                        style: const TextStyle(fontSize: 11),
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
                              scrollPadding: const EdgeInsets.only(bottom: 120),
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

                const SizedBox(height: 10),

                // BREAKDOWN CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(14),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
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
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 15,
                          ),
                          label: const Text(
                            "Magdagdag",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

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
                          margin: const EdgeInsets.only(bottom: 7),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _surfaceBg,
                            borderRadius: BorderRadius.circular(11),
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
                                                style: const TextStyle(
                                                  fontSize: 10.5,
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
                                  const SizedBox(width: 5),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: item.kgController,
                                      scrollPadding: const EdgeInsets.only(bottom: 120),
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
                                  const SizedBox(width: 5),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: item.srpController,
                                      scrollPadding: const EdgeInsets.only(bottom: 120),
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
                                      padding: const EdgeInsets.only(
                                        left: 2,
                                        top: 8,
                                      ),
                                      child: IconButton(
                                        constraints: const BoxConstraints(
                                          minWidth: 24,
                                          minHeight: 24,
                                        ),
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
                              if (itemKg > 0 && totalCost > 0) ...[
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Puhunan: ₱${itemAllocatedCost.toStringAsFixed(2)}",
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: _warningOrange,
                                      ),
                                    ),
                                    Text(
                                      "Tubó/kg: ₱${itemProfitPerKg.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        fontSize: 9,
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

                const SizedBox(height: 10),

                // SUMMARY CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF0FDF4),
                        Colors.white,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _primaryGreenSoft),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.auto_graph_rounded,
                            size: 16,
                            color: _primaryGreen,
                          ),
                          SizedBox(width: 5),
                          Text(
                            "Awtomatikong Tantiya",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: _textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _summaryItem(
                              "Kabuuang Ani",
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
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: _summaryItem(
                              "Inaasahang Gross",
                              "₱${totalRevenue.toStringAsFixed(2)}",
                              valueColor: _infoBlue,
                            ),
                          ),
                          Expanded(
                            child: _summaryItem(
                              "Avg Tubó/kg",
                              "₱${(overallRevenuePerKg - overallCostPerKg).toStringAsFixed(2)}",
                              valueColor: totalProfit >= 0
                                  ? _primaryGreen
                                  : _dangerRed,
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 7),
                        child: Divider(height: 1, color: _borderLine),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Inaasahang Malinis na Tubó",
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: _textPrimary,
                            ),
                          ),
                          Text(
                            "₱${totalProfit.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 15,
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

                const SizedBox(height: 12),

                // SAVE BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _primaryGreen.withOpacity(0.45),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

                            if (selectedImages.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Magdagdag muna ng kahit isang larawan ng produkto.",
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
                            const SizedBox(width: 7),
                          ],
                          Text(
                            _isSaving
                                ? "Sine-save..."
                                : "I-save sa Inbentaryo",
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 4),
              ],
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
            fontSize: 8.5,
            color: _textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
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
    List<File> imageFiles,
    String productCode,
  ) async {
    final supabase = Supabase.instance.client;
    final List<String> urls = [];

    for (int i = 0; i < imageFiles.length; i++) {
      final file = imageFiles[i];
      final extension = file.path.split('.').last.toLowerCase();
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

      await supabase.storage.from('product-images').upload(
        filePath,
        file,
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

    // Try to preserve the old sequential code. If Firestore requires an
    // index or this query fails, use a timestamp-based suffix so saving the
    // inventory item is not blocked by code generation.
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
