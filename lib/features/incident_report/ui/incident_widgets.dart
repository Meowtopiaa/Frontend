import 'package:flutter/material.dart';

import '../../../core/theme/meow_style.dart';
import '../../../core/utils/date_labels.dart';
import '../../../core/widgets/meow_widgets.dart';
import '../data/incident_enums.dart';
import '../data/incident_model.dart';

Color incidentStatusColor(IncidentStatus status) => switch (status) {
      IncidentStatus.received => MeowStyle.blue,
      IncidentStatus.waitingAssignment => const Color(0xFFE59A14),
      IncidentStatus.assigned => MeowStyle.violet,
      IncidentStatus.inProgress => MeowStyle.orange,
      IncidentStatus.resolved => MeowStyle.green,
      IncidentStatus.closed => MeowStyle.slate,
      IncidentStatus.rejected ||
      IncidentStatus.duplicate =>
        MeowStyle.danger,
      IncidentStatus.unknown => MeowStyle.brown,
    };

class IncidentStatusPill extends StatelessWidget {
  const IncidentStatusPill(this.status, {super.key});
  final IncidentStatus status;

  @override
  Widget build(BuildContext context) {
    final c = incidentStatusColor(status);
    return MeowPill(
      status.label,
      color: c.withValues(alpha: .14),
      foreground: Color.lerp(c, MeowStyle.ink, .3)!,
      icon: Icons.circle,
    );
  }
}

class IncidentUrgencyPill extends StatelessWidget {
  const IncidentUrgencyPill(this.urgency, {super.key});
  final IncidentUrgency urgency;

  @override
  Widget build(BuildContext context) => MeowPill(
        'Urgensi ${urgency.label}',
        color: urgency.color.withValues(alpha: .14),
        foreground: Color.lerp(urgency.color, MeowStyle.ink, .3)!,
        icon: Icons.priority_high_rounded,
      );
}

/// Format tanggal WIB singkat, mis. "26/11 14:05 WIB".
String incidentDateLabel(DateTime date) {
  final wib = date.toUtc().add(const Duration(hours: 7));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(wib.day)}/${two(wib.month)}/${wib.year} ${wibTime(date)}';
}

/// Kartu ringkas tiket untuk daftar. Tidak menampilkan kontak atau media
/// (EIR-09) — hanya ringkasan.
class IncidentTicketCard extends StatelessWidget {
  const IncidentTicketCard({
    super.key,
    required this.incident,
    this.onTap,
    this.trailing,
  });

  final IncidentReportModel incident;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cat = incident.category;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(
                cat.icon,
                color: incident.urgency.color.withValues(alpha: .15),
                foreground: incident.urgency.color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.catName != null
                          ? '${cat.label} · ${incident.catName}'
                          : cat.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${incident.ticketCode} · ${relativeTime(incident.createdAt.toLocal())}',
                      style: const TextStyle(
                        color: MeowStyle.brown,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (incident.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              incident.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: MeowStyle.ink, height: 1.35),
            ),
          ],
          if (incident.locationNote != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.place_outlined,
                    size: 14, color: MeowStyle.brown),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    incident.locationNote!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: MeowStyle.brown, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              IncidentStatusPill(incident.status),
              IncidentUrgencyPill(incident.urgency),
            ],
          ),
        ],
      ),
    );
  }
}

/// Riwayat status (incident_status_logs) sebagai linimasa.
class IncidentTimeline extends StatelessWidget {
  const IncidentTimeline({super.key, required this.logs});
  final List<IncidentStatusLog> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Text(
        'Belum ada riwayat status.',
        style: TextStyle(color: MeowStyle.brown),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < logs.length; i++)
          _TimelineRow(log: logs[i], isLast: i == logs.length - 1),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.log, required this.isLast});
  final IncidentStatusLog log;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = incidentStatusColor(log.toStatus);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: c.withValues(alpha: .25),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.toStatus.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    [
                      incidentDateLabel(log.createdAt),
                      if (log.actorName != null) log.actorName!,
                    ].join(' · '),
                    style: const TextStyle(
                      color: MeowStyle.brown,
                      fontSize: 12,
                    ),
                  ),
                  if (log.note != null) ...[
                    const SizedBox(height: 4),
                    Text(log.note!, style: const TextStyle(height: 1.35)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tampilan kosong/terkunci yang konsisten.
class IncidentEmptyState extends StatelessWidget {
  const IncidentEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        child: Column(
          children: [
            IconBubble(icon,
                size: 64,
                color: MeowStyle.lilac,
                foreground: MeowStyle.slate),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: MeowStyle.brown, height: 1.4),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      );
}

class IncidentErrorBanner extends StatelessWidget {
  const IncidentErrorBanner({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MeowStyle.danger.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: MeowStyle.danger.withValues(alpha: .25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: MeowStyle.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(color: MeowStyle.danger)),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      );
}
