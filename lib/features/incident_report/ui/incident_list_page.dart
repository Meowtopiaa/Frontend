import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/meow_style.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/meow_widgets.dart';
import '../logic/incident_provider.dart';
import 'incident_widgets.dart';

/// Beranda modul Lapor (Optimind): buat laporan, daftar tiket milik
/// pelapor (EIR-05), pintasan tugas relawan dan kontak dokter hewan.
class IncidentListPage extends StatefulWidget {
  const IncidentListPage({super.key});

  @override
  State<IncidentListPage> createState() => _IncidentListPageState();
}

class _IncidentListPageState extends State<IncidentListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<IncidentProvider>().fetchMyIncidents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<IncidentProvider>();
    final items = p.myIncidents;

    return MeowPage(
      title: 'Lapor Insiden',
      child: RefreshIndicator(
        onRefresh: p.fetchMyIncidents,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: MeowPage.scrollPadding(context, top: 12, bottom: 28),
          children: [
            _ReportHero(onCreate: () => context.push('/incidents/create')),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ShortcutTile(
                    icon: Icons.volunteer_activism_rounded,
                    label: 'Tugas Relawan',
                    onTap: () => context.push('/incidents/tasks'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ShortcutTile(
                    icon: Icons.local_hospital_rounded,
                    label: 'Dokter Hewan',
                    onTap: () => context.push('/incidents/vets'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SectionTitle(
              'Laporan Saya',
              icon: Icons.receipt_long_rounded,
              trailing: IconButton(
                tooltip: 'Muat ulang',
                onPressed: p.isLoadingMine ? null : p.fetchMyIncidents,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            const SizedBox(height: 10),
            if (p.mineError != null) ...[
              IncidentErrorBanner(
                message: p.mineError!.message,
                onRetry: p.fetchMyIncidents,
              ),
              const SizedBox(height: 12),
            ],
            if (p.isLoadingMine && items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: LoadingIndicator(message: 'Memuat laporan Anda...'),
              )
            else if (items.isEmpty && p.mineError == null)
              IncidentEmptyState(
                icon: Icons.health_and_safety_rounded,
                title: 'Belum ada laporan',
                message:
                    'Laporan yang Anda kirim akan muncul di sini beserta status penanganannya.',
                action: SizedBox(
                  width: 220,
                  child: MeowButton(
                    label: 'Buat Laporan',
                    icon: Icons.add_alert_rounded,
                    onPressed: () => context.push('/incidents/create'),
                  ),
                ),
              )
            else
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: IncidentTicketCard(
                    incident: item,
                    onTap: () => context.push('/incidents/${item.id}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ReportHero extends StatelessWidget {
  const _ReportHero({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => GlassCard(
        color: MeowStyle.blue.withValues(alpha: .10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                IconBubble(
                  Icons.health_and_safety_rounded,
                  color: Color(0x264388E8),
                  foreground: MeowStyle.blue,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Melihat kucing kampus butuh bantuan?',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Laporkan kucing sakit, terluka, hilang, kucing baru, atau QR rusak. '
              'Laporan diteruskan ke antrean admin insiden. Aplikasi ini bukan '
              'layanan darurat dengan jaminan waktu respons.',
              style: TextStyle(color: MeowStyle.brown, height: 1.4),
            ),
            const SizedBox(height: 14),
            MeowButton(
              label: 'Buat Laporan Insiden',
              icon: Icons.add_alert_rounded,
              onPressed: onCreate,
            ),
          ],
        ),
      );
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: MeowStyle.orangeDark),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}
