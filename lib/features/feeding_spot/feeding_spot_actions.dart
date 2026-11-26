import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/hub/cat_action_registry.dart';

/// Registrasi aksi Hub Pemindai Terpadu untuk modul Adopt Feeding Spot (AFS).
/// Sesuai Bagian 4.5 & 10.2 PRD (Kontrak Lintas-Modul: Scan QR Terpadu & Hub),
/// modul AFS mendaftarkan aksi utama `feeding.start` ("Mulai Sesi Pemberian Makan")
/// ke `CatActionRegistry` maupun daftar aksi QR spot.
void registerFeedingSpotActions() {
  CatActionRegistry.register(
    CatActionSpec(
      id: FeedingSpotActions.startFeedingActionKey,
      label: 'Mulai Sesi Pemberian Makan',
      icon: Icons.restaurant_rounded,
      onTap: (context, catId) {
        final query = <String, String>{
          if (catId.trim().isNotEmpty) 'cat_id': catId.trim(),
        };
        final uri = Uri(
          path: '/feeding/scan',
          queryParameters: query.isEmpty ? null : query,
        );
        context.push(uri.toString());
      },
    ),
  );
}

class FeedingSpotActionItem {
  final String key;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isPrimary;
  final void Function(
    BuildContext context, {
    String? spotId,
    String? qrToken,
    String? catId,
  })
  onExecute;

  const FeedingSpotActionItem({
    required this.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    this.isPrimary = false,
    required this.onExecute,
  });
}

class FeedingSpotActions {
  static const String startFeedingActionKey = 'feeding.start';
  static const String viewSpotDetailActionKey = 'spot.view';

  static final List<FeedingSpotActionItem> spotQrActions = [
    FeedingSpotActionItem(
      key: startFeedingActionKey,
      label: 'Mulai Sesi Pemberian Makan',
      subtitle: 'Buka sesi 15 menit dan dokumentasikan pemberian pakan di spot ini.',
      icon: Icons.restaurant_rounded,
      isPrimary: true,
      onExecute: (context, {spotId, qrToken, catId}) {
        final query = <String, String>{
          if (spotId != null && spotId.isNotEmpty) 'spot_id': spotId,
          if (qrToken != null && qrToken.isNotEmpty) 'qr_token': qrToken,
          if (catId != null && catId.isNotEmpty) 'cat_id': catId,
        };
        final uri = Uri(
          path: '/feeding/scan',
          queryParameters: query.isEmpty ? null : query,
        );
        context.push(uri.toString());
      },
    ),
    FeedingSpotActionItem(
      key: viewSpotDetailActionKey,
      label: 'Lihat Detail Spot & Riwayat',
      subtitle: 'Cek waktu terakhir diberi makan dan statistik 14 hari terakhir.',
      icon: Icons.place_outlined,
      isPrimary: false,
      onExecute: (context, {spotId, qrToken, catId}) {
        if (spotId != null && spotId.isNotEmpty) {
          context.push('/feeding/spot/$spotId');
        } else {
          context.push('/feeding');
        }
      },
    ),
  ];

  static FeedingSpotActionItem get primarySpotAction => spotQrActions.first;
}
