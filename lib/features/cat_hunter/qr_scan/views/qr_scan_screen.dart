import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_exception.dart';
import '../../approach_session/views/tame_splash_screen.dart';
import '../../cat_dex/data/models/cat_model.dart';
import '../../cat_dex/views/cat_dex_tab_screen.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimensions.dart';
import '../../logic/cat_hunter_provider.dart';
import '../../widgets/app_header_bar.dart';
import '../../widgets/demo_debug_sheet.dart';
import '../../widgets/primary_button.dart';
import 'widgets/animal_welfare_card.dart';

class QrScanScreen extends StatefulWidget {
  final String? initialCatId;

  const QrScanScreen({super.key, this.initialCatId});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scannerAnimController;
  late Animation<double> _scanLineAnimation;
  final TextEditingController _manualCodeController = TextEditingController();
  bool _isFlashOn = false;
  bool _isChecking = false;
  String? _selectedCatId;

  @override
  void initState() {
    super.initState();
    final provider = context.read<CatHunterProvider>();
    final cats = provider.allCats;
    if (widget.initialCatId != null && cats.isNotEmpty) {
      _selectedCatId = provider.getCatById(widget.initialCatId!).id;
    } else if (cats.isNotEmpty) {
      _selectedCatId = cats.first.id;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      provider.loadAll();
    });

    _scannerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(
        parent: _scannerAnimController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _manualCodeController.dispose();
    _scannerAnimController.dispose();
    super.dispose();
  }

  Future<void> _handleScanDetected(CatModel selectedCat) async {
    if (_isChecking) return;

    final provider = context.read<CatHunterProvider>();
    final manualInput = _manualCodeController.text.trim();
    final codeToCheck = manualInput.isNotEmpty ? manualInput : selectedCat.qrHash;

    setState(() => _isChecking = true);

    try {
      final result = await provider.checkScan(
        selectedCat.id,
        qrCode: codeToCheck,
      );
      if (!mounted) return;

      if (!result.isAvailable) {
        _showErrorSnackBar(
          'Kucing ini sedang tidak berada di kampus atau sedang dalam perawatan.',
        );
        return;
      }

      if (!result.canScanToday) {
        _showAlreadyScannedDialog(result.cat);
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TameSplashScreen(catId: result.cat.id),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.message);
    } catch (_) {
      if (!mounted) return;
      _showErrorSnackBar('Gagal memverifikasi QR kalung kucing. Coba lagi ya.');
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.missRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAlreadyScannedDialog(CatModel cat) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: AppColors.cardBg(dialogContext),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusModal),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  cat.sadPoseAsset,
                  height: 150,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.pets_rounded,
                    size: 72,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kamu sudah menyapa kucing ini hari ini, coba lagi besok!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryOf(dialogContext),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Lihat Profil Kucing',
                  icon: Icons.menu_book_rounded,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => CatDexTabScreen(
                          initialTabIndex: 1,
                          openCatProfileId: cat.id,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CatHunterProvider>();
    final allCats = provider.allCats;

    if (allCats.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg(context),
        appBar: const AppHeaderBar(
          title: 'Kucing Kampus',
          subtitle: 'TelCat World • Pemindai QR',
          statusText: 'QR Kalung',
          showBackButton: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final resolvedId = (_selectedCatId != null &&
            allCats.any((c) => c.id == _selectedCatId))
        ? _selectedCatId!
        : allCats.first.id;
    final selectedCat = provider.getCatById(resolvedId);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppHeaderBar(
        title: 'Kucing Kampus',
        subtitle: 'TelCat World • Pemindai QR',
        statusText: provider.isOfflineFallback ? 'Mode Demo' : 'Terhubung',
        showBackButton: true,
        onTitleHoldTwoSeconds: () => showDemoDebugSheet(
          context,
          initialCatId: selectedCat.id,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.marginHorizontal,
            vertical: AppDimensions.spaceMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Verification Status Banner (QR Collar Only, no GPS verification)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.sweetSpotGreenBg,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusFull),
                  border: Border.all(
                    color: AppColors.sweetSpotGreen.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 16,
                      color: AppColors.sweetSpotGreen,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Siap Pindai Kalung QR Kucing Kampus Tel-U',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.sweetSpotGreen,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Camera Viewfinder Card
              Container(
                height: 290,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusCard),
                  boxShadow: AppDimensions.cardShadow,
                ),
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusCard),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Opacity(
                        opacity: 0.15,
                        child: GridPaper(
                          color: Colors.white,
                          divisions: 2,
                          subdivisions: 1,
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              left: 0,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: AppColors.primary,
                                      width: 4,
                                    ),
                                    left: BorderSide(
                                      color: AppColors.primary,
                                      width: 4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: AppColors.primary,
                                      width: 4,
                                    ),
                                    right: BorderSide(
                                      color: AppColors.primary,
                                      width: 4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppColors.primary,
                                      width: 4,
                                    ),
                                    left: BorderSide(
                                      color: AppColors.primary,
                                      width: 4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppColors.primary,
                                      width: 4,
                                    ),
                                    right: BorderSide(
                                      color: AppColors.primary,
                                      width: 4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _scanLineAnimation,
                              builder: (context, child) {
                                return Positioned(
                                  top: _scanLineAnimation.value * 200,
                                  left: 8,
                                  right: 8,
                                  child: Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              AppColors.primary.withOpacity(0.8),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 48,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 14,
                        right: 14,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isFlashOn = !_isFlashOn;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _isFlashOn
                                  ? AppColors.primary
                                  : Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isFlashOn
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusFull),
                          ),
                          child: const Text(
                            'Arahkan kamera ke kalung QR kucing kampus',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              // Target Selector & Optional Manual QR Code Input
              Container(
                padding: const EdgeInsets.all(AppDimensions.spaceMd),
                decoration: BoxDecoration(
                  color: AppColors.cardBg(context),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusCard),
                  border: Border.all(color: AppColors.borderOf(context)),
                  boxShadow: AppDimensions.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kucing yang Terdeteksi:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.peachBgOf(context),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            selectedCat.qrHash,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.peachTextOf(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: resolvedId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: AppColors.subtleBg(context),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusSm),
                          borderSide: BorderSide(
                            color: AppColors.borderInteractiveOf(context),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusSm),
                          borderSide: BorderSide(
                            color: AppColors.borderInteractiveOf(context),
                          ),
                        ),
                      ),
                      items: allCats.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat.id,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.pets_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${cat.name} (${cat.zone})',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimaryOf(context),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (catId) {
                        if (catId != null) {
                          setState(() {
                            _selectedCatId = catId;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _manualCodeController,
                      decoration: InputDecoration(
                        hintText:
                            'Opsional: Kode QR kalung (MTP1.C.... / ${selectedCat.qrHash})',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiaryOf(context),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: AppColors.subtleBg(context),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusSm),
                          borderSide: BorderSide(
                            color: AppColors.borderInteractiveOf(context),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusSm),
                          borderSide: BorderSide(
                            color: AppColors.borderInteractiveOf(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spaceMd),

              const AnimalWelfareCard(),

              const SizedBox(height: AppDimensions.spaceLg),

              PrimaryButton(
                label: 'Pindai Kalung: ${selectedCat.name}',
                icon: Icons.qr_code_scanner_rounded,
                isLoading: _isChecking || provider.isSubmitting,
                onPressed: () => _handleScanDetected(selectedCat),
              ),

              const SizedBox(height: AppDimensions.spaceMd),
            ],
          ),
        ),
      ),
    );
  }
}
