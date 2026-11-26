// TODO: Hapus atau nonaktifkan Mode Demo ini sebelum rilis produksi Play Store/App Store
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../logic/cat_hunter_provider.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

// TODO: Hapus atau nonaktifkan Mode Demo ini sebelum rilis produksi Play Store/App Store
Future<void> showDemoDebugSheet(
  BuildContext context, {
  String? initialCatId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.cardBg(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDimensions.radiusModal),
      ),
    ),
    builder: (sheetContext) => _DemoDebugBottomSheet(
      parentContext: context,
      initialCatId: initialCatId,
    ),
  );
}

class _DemoDebugBottomSheet extends StatefulWidget {
  final BuildContext parentContext;
  final String? initialCatId;

  const _DemoDebugBottomSheet({
    required this.parentContext,
    this.initialCatId,
  });

  @override
  State<_DemoDebugBottomSheet> createState() => _DemoDebugBottomSheetState();
}

class _DemoDebugBottomSheetState extends State<_DemoDebugBottomSheet> {
  String? _selectedCatId;

  @override
  void initState() {
    super.initState();
    final cats = widget.parentContext.read<CatHunterProvider>().allCats;
    if (widget.initialCatId != null &&
        cats.any((c) => c.id == widget.initialCatId)) {
      _selectedCatId = widget.initialCatId;
    } else if (cats.isNotEmpty) {
      _selectedCatId = cats.first.id;
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CatHunterProvider>();
    final cats = provider.allCats;
    if (cats.isEmpty) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Belum ada data kucing untuk disimulasikan.'),
        ),
      );
    }

    final resolvedId = (_selectedCatId != null &&
            cats.any((c) => c.id == _selectedCatId))
        ? _selectedCatId!
        : cats.first.id;
    final selectedCat = provider.getCatById(resolvedId);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.marginHorizontal,
          14,
          AppDimensions.marginHorizontal,
          AppDimensions.spaceLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderInteractiveOf(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.peachBgOf(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.bug_report_rounded,
                    color: AppColors.primaryOf(context),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mode Demo / Debug',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      Text(
                        'Panel simulasi pengujian alur pertemuan & cooldown',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Pilih Target Kucing:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: resolvedId,
              isExpanded: true,
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: AppColors.subtleBg(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  borderSide: BorderSide(
                    color: AppColors.borderInteractiveOf(context),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  borderSide: BorderSide(
                    color: AppColors.borderInteractiveOf(context),
                  ),
                ),
              ),
              items: cats.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat.id,
                  child: Text(
                    '${cat.name} (Pertemuan ${cat.encounterCount}/5)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryOf(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCatId = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            SecondaryButton(
              label: 'Reset Cooldown Hari Ini',
              icon: Icons.refresh_rounded,
              onPressed: () {
                provider.resetAllDailyCooldowns();
                Navigator.of(context).pop();
                _showSnack('Cooldown harian seluruh kucing berhasil direset!');
              },
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Simulasi 4x Pertemuan',
              icon: Icons.fast_forward_rounded,
              onPressed: () {
                provider.simulateFourEncounters(resolvedId);
                Navigator.of(context).pop();
                _showSnack(
                  '${selectedCat.name} diset ke 4x pertemuan. Scan berikutnya membuka fitur Rename!',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
