import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/meow_style.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/meow_widgets.dart';
import '../data/incident_model.dart';
import '../logic/incident_provider.dart';
import 'incident_widgets.dart';

/// Kontak dokter hewan atau klinik mitra (EIR-12, P1) dari `GET /vets`.
/// Data hanya dari server; aplikasi tidak mengisi kontak fiktif.
/// Kontak disalin atas aksi pengguna (panggilan/WhatsApp dibuka manual).
class VetContactsPage extends StatefulWidget {
  const VetContactsPage({super.key});

  @override
  State<VetContactsPage> createState() => _VetContactsPageState();
}

class _VetContactsPageState extends State<VetContactsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<IncidentProvider>().fetchVets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<IncidentProvider>();
    return MeowPage(
      title: 'Dokter Hewan',
      child: RefreshIndicator(
        onRefresh: p.fetchVets,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: MeowPage.scrollPadding(context, top: 12, bottom: 28),
          children: [
            const Text(
              'Untuk kondisi darurat, hubungi klinik langsung. Meowtopia tidak '
              'menjamin waktu respons layanan medis.',
              style: TextStyle(color: MeowStyle.brown, height: 1.4),
            ),
            const SizedBox(height: 14),
            if (p.vetsError != null) ...[
              IncidentErrorBanner(
                message: p.vetsError!.message,
                onRetry: p.fetchVets,
              ),
              const SizedBox(height: 12),
            ],
            if (p.isLoadingVets && p.vets.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: LoadingIndicator(message: 'Memuat kontak klinik...'),
              )
            else if (p.vets.isEmpty && p.vetsError == null)
              const IncidentEmptyState(
                icon: Icons.local_hospital_outlined,
                title: 'Belum ada data klinik mitra',
                message:
                    'Kontak dokter hewan akan tampil setelah pengelola menambahkannya.',
              )
            else
              for (final v in p.vets) _VetCard(vet: v),
          ],
        ),
      ),
    );
  }
}

class _VetCard extends StatelessWidget {
  const _VetCard({required this.vet});
  final VetContact vet;

  Future<void> _copy(BuildContext context, String label, String value) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: value));
    messenger.showSnackBar(SnackBar(content: Text('$label disalin: $value')));
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vet.name,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              if (vet.address != null) ...[
                const SizedBox(height: 4),
                Text(vet.address!,
                    style: const TextStyle(color: MeowStyle.brown)),
              ],
              if (vet.openHours != null) ...[
                const SizedBox(height: 4),
                Text('Jam buka: ${vet.openHours}',
                    style: const TextStyle(color: MeowStyle.brown)),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (vet.phone != null)
                    ActionChip(
                      avatar: const Icon(Icons.call_rounded, size: 18),
                      label: Text(vet.phone!),
                      onPressed: () => _copy(context, 'Nomor', vet.phone!),
                    ),
                  if (vet.whatsapp != null)
                    ActionChip(
                      avatar: const Icon(Icons.chat_rounded, size: 18),
                      label: Text('WA ${vet.whatsapp!}'),
                      onPressed: () =>
                          _copy(context, 'WhatsApp', vet.whatsapp!),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
}
