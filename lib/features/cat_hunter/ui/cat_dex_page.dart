import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../cat_dex/views/cat_dex_tab_screen.dart';
import '../cat_dex/views/profile_tab_screen.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../logic/cat_hunter_provider.dart';
import '../map_territory/views/territory_map_screen.dart';
import '../qr_scan/views/qr_scan_screen.dart';

class CatDexPage extends StatefulWidget {
  final int initialIndex;
  final int initialCatDexTab;
  final String? openCatProfileId;

  const CatDexPage({
    super.key,
    this.initialIndex = 0,
    this.initialCatDexTab = 0,
    this.openCatProfileId,
  });

  @override
  State<CatDexPage> createState() => _CatDexPageState();
}

class _CatDexPageState extends State<CatDexPage> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CatHunterProvider>().loadAll();
    });
  }

  void _openQrScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const QrScanScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      body: Stack(
        children: [
          Column(
            children: [
              // Sub-tab switcher for Cat-Dex, Peta Zona, and Profil
              Container(
                color: AppColors.cardBg(context),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: AppDimensions.marginHorizontal,
                  right: AppDimensions.marginHorizontal,
                  bottom: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.subtleBg(context),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  child: Row(
                    children: [
                      _buildNavPill(
                        index: 0,
                        label: 'Cat-Dex',
                        icon: Icons.pets_rounded,
                      ),
                      _buildNavPill(
                        index: 1,
                        label: 'Peta Zona',
                        icon: Icons.map_rounded,
                      ),
                      _buildNavPill(
                        index: 2,
                        label: 'Profil',
                        icon: Icons.person_rounded,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      CatDexTabScreen(
                        initialTabIndex: widget.initialCatDexTab,
                        openCatProfileId: widget.openCatProfileId,
                      ),
                      const TerritoryMapScreen(),
                      const ProfileTabScreen(),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Floating Pindai QR button positioned cleanly above Super App bottom bar
          Positioned(
            right: 16,
            bottom: 94 + bottomInset,
            child: GestureDetector(
              onTap: _openQrScanner,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusFull),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(242, 106, 27, 0.38),
                      blurRadius: 14,
                      spreadRadius: 1,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Pindai QR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavPill({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _currentIndex == index;
    final primary = AppColors.primaryOf(context);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? Colors.white
                    : AppColors.textSecondaryOf(context),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondaryOf(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
