import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/meow_style.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/meow_widgets.dart';
import '../data/incident_enums.dart';
import '../data/incident_model.dart';
import '../logic/incident_provider.dart';
import 'incident_status_sheet.dart';
import 'incident_widgets.dart';

/// Detail tiket dan riwayat status (EIR-05). Akses ditentukan server:
/// pelapor, caretaker yang ditugaskan, atau admin (FIX-02).
class IncidentDetailPage extends StatefulWidget {
  const IncidentDetailPage({super.key, required this.incidentId});
  final String incidentId;

  @override
  State<IncidentDetailPage> createState() => _IncidentDetailPageState();
}

class _IncidentDetailPageState extends State<IncidentDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<IncidentProvider>().fetchDetail(widget.incidentId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<IncidentProvider>();
    final item = p.detailOf(widget.incidentId);
    final error = p.detailErrorOf(widget.incidentId);
    final loading = p.isLoadingDetail(widget.incidentId);

    CaretakerTask? myTask;
    for (final t in p.tasks) {
      if (t.incident.id == widget.incidentId &&
          t.status == AssignmentStatus.accepted) {
        myTask = t;
      }
    }
    final updatable = (myTask != null &&
            item != null &&
            item.status.caretakerNextStatuses.isNotEmpty)
        ? item
        : null;

    return MeowPage(
      title: item?.ticketCode ?? 'Detail Tiket',
      bottom: updatable != null
          ? MeowButton(
              label: 'Perbarui Status',
              icon: Icons.update_rounded,
              onPressed: () => showIncidentStatusSheet(context, updatable),
            )
          : null,
      child: RefreshIndicator(
        onRefresh: () => p.fetchDetail(widget.incidentId),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: MeowPage.scrollPadding(context, top: 12, bottom: 28),
          children: [
            if (error != null) ...[
              IncidentErrorBanner(
                message: error.message,
                onRetry: () => p.fetchDetail(widget.incidentId),
              ),
              const SizedBox(height: 12),
            ],
            if (item == null && loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: LoadingIndicator(message: 'Memuat detail tiket...'),
              )
            else if (item != null) ...[
              _Header(item: item),
              const SizedBox(height: 14),
              _HandlingCard(item: item),
              const SizedBox(height: 14),
              if (item.location != null || item.locationNote != null) ...[
                _LocationSection(item: item),
                const SizedBox(height: 14),
              ],
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('Riwayat Status',
                        icon: Icons.timeline_rounded),
                    const SizedBox(height: 14),
                    IncidentTimeline(logs: item.statusLogs),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.item});
  final IncidentReportModel item;

  @override
  Widget build(BuildContext context) => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBubble(
                  item.category.icon,
                  color: item.urgency.color.withValues(alpha: .15),
                  foreground: item.urgency.color,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.category.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Dibuat ${incidentDateLabel(item.createdAt)}',
                        style: const TextStyle(
                          color: MeowStyle.brown,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                IncidentStatusPill(item.status),
                IncidentUrgencyPill(item.urgency),
                MeowPill('Sumber: ${item.source.label}'),
                if (item.mediaCount > 0)
                  MeowPill('${item.mediaCount} lampiran',
                      icon: Icons.attach_file_rounded),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.status.meaning,
              style: const TextStyle(color: MeowStyle.brown, fontSize: 12),
            ),
            if (item.catId != null || item.catName != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.pets_rounded,
                      size: 16, color: MeowStyle.orangeDark),
                  const SizedBox(width: 6),
                  Text(item.catName ?? 'Kucing ${item.catId}'),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(item.description, style: const TextStyle(height: 1.4)),
          ],
        ),
      );
}

/// Status penanganan ditampilkan apa adanya (FIX-09, IT-10).
class _HandlingCard extends StatelessWidget {
  const _HandlingCard({required this.item});
  final IncidentReportModel item;

  @override
  Widget build(BuildContext context) {
    final assignee = item.hasAssignee
        ? 'Penanggung jawab ditetapkan'
            '${item.assignedAt != null ? ' · ${incidentDateLabel(item.assignedAt!)}' : ''}'
        : 'Belum ada penanggung jawab. Tiket tetap di antrean admin.';
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Penanganan',
              icon: Icons.volunteer_activism_rounded),
          const SizedBox(height: 10),
          _InfoRow(icon: Icons.person_pin_rounded, text: assignee),
          _InfoRow(
            icon: Icons.notifications_rounded,
            text: 'Notifikasi petugas: ${item.notificationStatus.label}',
          ),
          if (item.resolvedAt != null)
            _InfoRow(
              icon: Icons.task_alt_rounded,
              text: 'Selesai ditangani ${incidentDateLabel(item.resolvedAt!)}',
            ),
          if (item.closedAt != null)
            _InfoRow(
              icon: Icons.lock_rounded,
              text: 'Ditutup ${incidentDateLabel(item.closedAt!)}',
            ),
          if (item.resolutionNote != null) ...[
            const SizedBox(height: 6),
            Text(
              'Catatan penanganan: ${item.resolutionNote}',
              style: const TextStyle(height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: MeowStyle.brown),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
          ],
        ),
      );
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({required this.item});
  final IncidentReportModel item;

  @override
  Widget build(BuildContext context) {
    final loc = item.location;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Lokasi', icon: Icons.place_rounded),
          const SizedBox(height: 10),
          if (item.locationNote != null)
            _InfoRow(icon: Icons.signpost_rounded, text: item.locationNote!),
          if (loc != null) ...[
            _InfoRow(icon: Icons.gps_fixed_rounded, text: loc.label),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 180,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(loc.lat, loc.lng),
                    initialZoom: 17,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'id.meowtopia.meowtopia',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(loc.lat, loc.lng),
                          width: 40,
                          height: 40,
                          alignment: Alignment.topCenter,
                          child: const Icon(
                            Icons.location_on_rounded,
                            size: 40,
                            color: MeowStyle.danger,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
