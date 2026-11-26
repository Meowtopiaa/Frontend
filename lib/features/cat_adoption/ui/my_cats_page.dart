import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/loading_indicator.dart';
import '../data/my_adoption_model.dart';
import '../logic/adoption_provider.dart';
import 'adoption_theme.dart';
import 'adoption_widgets.dart';

/// Layar 5: Kucing Saya. Hanya adopsi ACTIVE yang tampil (ADP-08);
/// status kelayakan ditampilkan terpisah di bawahnya.
class MyCatsPage extends StatefulWidget {
  const MyCatsPage({super.key});

  @override
  State<MyCatsPage> createState() => _MyCatsPageState();
}

class _MyCatsPageState extends State<MyCatsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    final provider = context.read<AdoptionProvider>();
    await Future.wait([
      provider.fetchMyAdoptions(),
      provider.fetchMyEligibility(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdoptionProvider>();

    return Scaffold(
      backgroundColor: AdoptionTheme.pageBg,
      appBar: AppBar(
        backgroundColor: AdoptionTheme.pageBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Kucing saya', style: AdoptionTheme.titleStyle),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined, size: 22),
            tooltip: 'Riwayat pengajuan kelayakan',
            onPressed: () => _showApplicationsSheet(context, provider),
          ),
          const SizedBox(width: 4),
        ],
      ),
      // Gagal memuat ditampilkan sebagai error, bukan sebagai daftar kosong.
      body: provider.isMyAdoptionsLoading && provider.myAdoptions.isEmpty
          ? const LoadingIndicator(message: 'Memuat adopsimu...')
          : provider.myAdoptionsError != null
              ? AdoptionErrorState(
                  message: provider.myAdoptionsError!,
                  onRetry: _reload,
                )
              : RefreshIndicator(
                  color: AdoptionTheme.accent,
                  onRefresh: _reload,
                  child: AdoptionPageBody(
                    children: [
                      const AdoptionHeader(
                        overline: 'Adopsi saya',
                        title: 'Kucing saya',
                        subtitle:
                            'Kucing yang sedang kamu rawat dan laporan kondisinya.',
                        icon: Icons.favorite_rounded,
                      ),
                      if (provider.myAdoptions.isEmpty)
                        AdoptionEmptyState(
                          message: 'Kamu belum mengadopsi kucing',
                          submessage:
                              'Kucing muncul di sini setelah kelayakanmu disetujui '
                              'dan pengambilan selesai.',
                          action: AdoptionSecondaryButton(
                            label: 'Lihat katalog',
                            onPressed: () => context.push('/adoption'),
                          ),
                        )
                      else
                        ...provider.myAdoptions.map(
                          (adoption) => _AdoptionBlock(adoption: adoption),
                        ),
                      const SizedBox(height: 8),
                      _buildEligibilitySection(provider),
                    ],
                  ),
                ),
    );
  }

  /// Status kelayakan ditampilkan terpisah dari adopsi (ADP-08). Kelayakan
  /// disetujui belum berarti punya kucing.
  Widget _buildEligibilitySection(AdoptionProvider provider) {
    final apps = provider.myEligibility;
    final latest = apps.isEmpty ? null : apps.first;

    final Widget status;
    if (provider.isEligibilityLoading && apps.isEmpty) {
      status = const Text('Memuat status kelayakan...',
          style: AdoptionTheme.bodyStyle);
    } else if (provider.eligibilityError != null) {
      status = Text(
        'Status kelayakan belum bisa dimuat. Tarik ke bawah untuk mencoba lagi.',
        style: AdoptionTheme.bodyStyle.copyWith(color: AdoptionTheme.danger),
      );
    } else if (latest == null) {
      status =
          const Text('Belum ada pengajuan.', style: AdoptionTheme.bodyStyle);
    } else {
      status = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ApplicationStatusBadge(status: latest.status),
          if (latest.adminNote != null) ...[
            const SizedBox(height: 8),
            Text('Catatan pengurus: ${latest.adminNote}',
                style: AdoptionTheme.bodyStyle),
          ],
        ],
      );
    }

    // Halaman detail pengajuan masih memakai id angka (Sprint 1), jadi
    // tautannya hanya muncul di mode demo.
    Widget? action;
    if (provider.eligibilityError == null) {
      if (latest == null) {
        action = TextButton(
          style: TextButton.styleFrom(foregroundColor: AdoptionTheme.accent),
          onPressed: () => context.push('/adoption/apply'),
          child: const Text('Isi form kelayakan'),
        );
      } else if (provider.legacyPagesSupported) {
        action = TextButton(
          style: TextButton.styleFrom(foregroundColor: AdoptionTheme.accent),
          onPressed: () => context.push('/adoption/detail/${latest.id}'),
          child: const Text('Lihat rincian'),
        );
      }
    }

    return AdoptionSection(
      title: 'Status kelayakan',
      child: Row(
        children: [
          Expanded(child: status),
          if (action != null) action,
        ],
      ),
    );
  }

  void _showApplicationsSheet(BuildContext context, AdoptionProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AdoptionTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final apps = provider.myEligibility;
        final canOpen = provider.legacyPagesSupported;
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 8, 20, MediaQuery.paddingOf(ctx).bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Riwayat pengajuan',
                        style: AdoptionTheme.titleStyle),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              if (provider.eligibilityError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(provider.eligibilityError!,
                      style: AdoptionTheme.bodyStyle),
                )
              else if (apps.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Belum ada pengajuan.',
                      style: AdoptionTheme.bodyStyle),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: apps.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AdoptionTheme.divider),
                    itemBuilder: (_, index) {
                      final item = apps[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item.submittedAt == null
                              ? 'Belum dikirim'
                              : 'Dikirim ${formatAdoptionDate(item.submittedAt!)}',
                          style: AdoptionTheme.subtitleStyle,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ApplicationStatusBadge(status: item.status),
                          ),
                        ),
                        trailing: canOpen
                            ? const Icon(Icons.chevron_right_rounded, size: 20)
                            : null,
                        onTap: canOpen
                            ? () {
                                Navigator.pop(ctx);
                                context.push('/adoption/detail/${item.id}');
                              }
                            : null,
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Satu adopsi ACTIVE: identitas kucing, laporan berikutnya, dan aksi lain.
class _AdoptionBlock extends StatelessWidget {
  final MyAdoption adoption;

  const _AdoptionBlock({required this.adoption});

  @override
  Widget build(BuildContext context) {
    final catName = adoption.catName;
    final total = adoption.totalFollowups;
    final done = adoption.completedFollowups;
    final next = adoption.nextFollowup;
    final isLate = adoption.isNextFollowupLate(DateTime.now().toUtc());
    final encodedName = Uri.encodeComponent(catName);
    final encodedId = Uri.encodeComponent(adoption.id);
    final legacyPages = context.read<AdoptionProvider>().legacyPagesSupported;
    final details = [
      if (adoption.genderLabel != null) adoption.genderLabel!,
      if (adoption.pickedUpAt != null)
        'Diadopsi sejak ${formatAdoptionDate(adoption.pickedUpAt!)}',
    ];

    final String dueText;
    if (!adoption.hasSchedule) {
      dueText = 'Jadwal laporan kondisi belum tersedia.';
    } else if (next == null) {
      dueText = 'Semua laporan tiga bulan pertama sudah dikirim.';
    } else if (next.dueAt == null) {
      dueText = 'Laporan ke-${next.periodNo} belum punya batas waktu.';
    } else if (isLate) {
      dueText = 'Laporan ke-${next.periodNo} sudah lewat batas '
          '${formatAdoptionDate(next.dueAt!)}. '
          'Kirim sekarang, laporan terlambat tetap diterima.';
    } else {
      dueText = 'Laporan ke-${next.periodNo} paling lambat '
          '${formatAdoptionDate(next.dueAt!)}.';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: AdoptionTheme.padCard,
            decoration: AdoptionTheme.cardDecoration,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 88,
                  child: CatPhotoBox(photoUrl: adoption.catPhotoUrl),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(catName, style: AdoptionTheme.headlineStyle),
                      const SizedBox(height: 4),
                      for (final line in details)
                        Text(line, style: AdoptionTheme.bodyStyle),
                      const SizedBox(height: 8),
                      ActiveAdoptionStatusBadge(status: adoption.status),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AdoptionSection(
            title: 'Laporan kondisi',
            trailing: adoption.hasSchedule
                ? Text('$done dari $total terkirim',
                    style: AdoptionTheme.captionStyle)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (adoption.hasSchedule) ...[
                  _FollowupProgress(total: total, done: done, isLate: isLate),
                  const SizedBox(height: 12),
                ],
                Text(
                  dueText,
                  style: AdoptionTheme.bodyStyle.copyWith(
                    color:
                        isLate ? AdoptionTheme.danger : AdoptionTheme.textMain,
                  ),
                ),
                if (next != null) ...[
                  const SizedBox(height: 14),
                  AdoptionPrimaryButton(
                    label: 'Kirim laporan ke-${next.periodNo}',
                    icon: Icons.photo_camera_outlined,
                    onPressed: () => context.push(
                      '/adoption/followup?adoption_id=$encodedId&cycle=${next.periodNo}&cat_name=$encodedName',
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: AdoptionTheme.cardDecoration,
            child: Column(
              children: [
                _LinkRow(
                  label: 'Laporkan kendala',
                  description: 'Sakit, hilang, meninggal, atau kalung rusak',
                  onTap: () => context.push(
                    '/adoption/issue?adoption_id=$encodedId&name=$encodedName',
                  ),
                ),
                const Divider(height: 1, color: AdoptionTheme.divider),
                // Alur pengembalian (EN-22) belum tersambung ke server.
                _LinkRow(
                  label: 'Ajukan pengembalian',
                  description: legacyPages
                      ? 'Syarat dan alur pengembalian kucing'
                      : 'Belum tersedia di aplikasi. Hubungi pengurus adopsi.',
                  onTap: legacyPages
                      ? () => context.push(
                            '/adoption/return?adoption_id=$encodedId&name=$encodedName',
                          )
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Garis kemajuan laporan: satu ruas per laporan.
class _FollowupProgress extends StatelessWidget {
  final int total;
  final int done;
  final bool isLate;

  const _FollowupProgress({
    required this.total,
    required this.done,
    required this.isLate,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$done dari $total laporan terkirim',
      child: Row(
        children: List.generate(total, (i) {
          final Color color;
          if (i < done) {
            color = AdoptionTheme.accent;
          } else if (i == done && isLate) {
            color = AdoptionTheme.danger;
          } else {
            color = AdoptionTheme.divider;
          }
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == total - 1 ? 0 : 4),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: color == AdoptionTheme.divider
                      ? AdoptionTheme.chipBg
                      : color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  final String description;
  final VoidCallback? onTap;

  const _LinkRow({
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AdoptionTheme.bodyStyle.copyWith(
                      color: AdoptionTheme.textMain,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(description, style: AdoptionTheme.captionStyle),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded,
                  color: AdoptionTheme.textHint),
          ],
        ),
      ),
    );
  }
}
