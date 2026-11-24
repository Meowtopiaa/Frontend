import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../features/feeding_spot/feeding_spot_actions.dart';
import '../../features/feeding_spot/ui/scan_spot_page.dart';
import '../constants/app_constants.dart';
import '../network/api_client.dart';
import '../widgets/loading_indicator.dart';

enum ScanPurpose {
  profile,
  encounter,
  pickup,
  returns,
  feeding,
}

class ScannerPage extends StatefulWidget {
  final ScanPurpose purpose;

  const ScannerPage({
    super.key,
    this.purpose = ScanPurpose.profile,
  });

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  final TextEditingController _manualInputController = TextEditingController();
  final ApiClient _apiClient = ApiClient();
  final QrScanCooldown _scanCooldown = QrScanCooldown();

  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  Future<void> _handleCode(String rawCode, {bool fromCamera = false}) async {
    final trimmed = rawCode.trim();
    if (_isProcessing || trimmed.isEmpty) return;
    if (fromCamera && _scanCooldown.shouldIgnore(trimmed)) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiClient.get(
        '/scan/resolve',
        queryParameters: {'code': trimmed},
      );

      final data = response.data['data'];
      final String type = data['type'];
      final String id = data['id'];

      if (!mounted) return;
      _scanCooldown.reset();

      // Handle based on ScanPurpose
      if (widget.purpose == ScanPurpose.feeding) {
        if (type != 'spot') {
          throw Exception('QR_WRONG_TYPE: Harap pindai QR titik makan resmi Meowtopia.');
        }
        FeedingSpotActions.primarySpotAction.onExecute(
          context,
          spotId: id,
          qrToken: trimmed,
        );
      } else if (widget.purpose == ScanPurpose.encounter) {
        if (type != 'cat') {
          throw Exception('QR_WRONG_TYPE: Harap pindai QR kalung kucing Meowtopia.');
        }
        context.push('/cat-hunter/encounter', extra: {'cat_id': id, 'cat_code': data['code']});
      } else {
        // Default: Open cat profile or spot detail
        if (type == 'cat') {
          context.push('/cats/$id');
        } else if (type == 'spot') {
          context.push('/feeding/spots/$id');
        }
      }
    } catch (e) {
      if (fromCamera) {
        _scanCooldown.recordFailure(trimmed);
      }
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isProcessing = false;
        });
      }
    }
  }

  void _showManualInputDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Input Kode Manual'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Masukkan kode alfanumerik yang tertera pada kalung kucing atau spot:'),
            const SizedBox(height: 12),
            TextField(
              controller: _manualInputController,
              decoration: const InputDecoration(
                hintText: 'Contoh: CAT001 atau SPOT-TULT-01',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = _manualInputController.text.trim();
              Navigator.pop(ctx);
              if (code.isNotEmpty) {
                _handleCode(code);
              }
            },
            child: const Text('Proses'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final rawValue = barcode.rawValue;
                if (rawValue != null && rawValue.isNotEmpty) {
                  _handleCode(rawValue, fromCamera: true);
                  break;
                }
              }
            },
            errorBuilder: (context, error, child) {
              final info = describeCameraScannerError(error.errorCode);
              return Container(
                color: const Color(0xFF1F2937),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.no_photography_outlined,
                      color: Colors.amber,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      info.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      info.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    if (info.showOpenSettings) ...[
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.amber),
                        ),
                        onPressed: () async {
                          try {
                            await Geolocator.openAppSettings();
                          } catch (_) {}
                        },
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Buka Pengaturan'),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: LoadingIndicator(
                  message: 'Memverifikasi kode...',
                  onDark: true,
                ),
              ),
            ),
          if (_errorMessage != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      onPressed: () => setState(() => _errorMessage = null),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _showManualInputDialog,
              icon: const Icon(Icons.keyboard),
              label: const Text('Input Kode Manual (Kalung Rusak/Hilang)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (widget.purpose) {
      case ScanPurpose.feeding:
        return 'Scan QR Titik Makan (Spot)';
      case ScanPurpose.encounter:
        return 'Scan QR Kalung Kucing (Dekati)';
      case ScanPurpose.pickup:
        return 'Scan QR Serah Terima Kucing';
      case ScanPurpose.returns:
        return 'Scan QR Pengembalian Kucing';
      case ScanPurpose.profile:
        return 'Pindai QR Meowtopia';
    }
  }
}
