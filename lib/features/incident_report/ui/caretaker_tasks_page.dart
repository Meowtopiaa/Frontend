import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/meow_style.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/meow_widgets.dart';
import '../data/incident_enums.dart';
import '../data/incident_model.dart';
import '../logic/incident_provider.dart';
import 'incident_status_sheet.dart';
import 'incident_widgets.dart';

/// Aplikasi relawan (caretaker): hanya tugas miliknya (EIR-05), terima atau
/// tolak penugasan (EIR-06), dan perbarui status (EIR-07). Hak akses
/// ditentukan server lewat permission; respons 403 ditampilkan apa adanya.
class CaretakerTasksPage extends StatefulWidget {
  const CaretakerTasksPage({super.key});

  @override
  State<CaretakerTasksPage> createState() => _CaretakerTasksPageState();
}

class _CaretakerTasksPageState extends State<CaretakerTasksPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<IncidentProvider>().fetchTasks();
    });
  }

  Future<void> _accept(CaretakerTask task) async {
    final failure = await context.read<IncidentProvider>().acceptTask(task.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failure?.message ?? 'Tugas ${task.incident.ticketCode} Anda terima.',
        ),
      ),
    );
  }

  Future<void> _decline(CaretakerTask task) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tolak tugas ini?'),
        content: TextField(
          controller: reason,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Alasan (opsional)',
            hintText: 'Contoh: sedang di luar kampus',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    final text = reason.text;
    reason.dispose();
    if (ok != true || !mounted) return;
    final failure = await context
        .read<IncidentProvider>()
        .declineTask(task.id, reason: text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failure?.message ??
              'Tugas ditolak. Tiket dikembalikan ke antrean admin.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<IncidentProvider>();
    final error = p.tasksError;
    final offered =
        p.tasks.where((t) => t.status == AssignmentStatus.offered).toList();
    final active =
        p.tasks.where((t) => t.status == AssignmentStatus.accepted).toList();
    final done =
        p.tasks.where((t) => t.status == AssignmentStatus.done).toList();

    return MeowPage(
      title: 'Tugas Relawan',
      child: RefreshIndicator(
        onRefresh: p.fetchTasks,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: MeowPage.scrollPadding(context, top: 12, bottom: 28),
          children: [
            if (error != null && error.isForbidden)
              const IncidentEmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'Khusus relawan terdaftar',
                message:
                    'Halaman ini hanya untuk akun relawan (caretaker). Akun relawan dibuat oleh pengelola lewat panel admin.',
              )
            else ...[
              if (error != null) ...[
                IncidentErrorBanner(
                    message: error.message, onRetry: p.fetchTasks),
                const SizedBox(height: 12),
              ],
              if (p.isLoadingTasks && p.tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: LoadingIndicator(message: 'Memuat tugas...'),
                )
              else if (p.tasks.isEmpty && error == null)
                const IncidentEmptyState(
                  icon: Icons.inbox_rounded,
                  title: 'Belum ada tugas',
                  message:
                      'Tugas yang ditawarkan admin insiden kepada Anda akan muncul di sini.',
                )
              else ...[
                if (offered.isNotEmpty) ...[
                  const SectionTitle('Ditawarkan',
                      icon: Icons.mark_email_unread_rounded),
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 10),
                    child: Text(
                      'Tanpa respons dalam 15 menit, tugas kembali ke antrean admin.',
                      style: TextStyle(color: MeowStyle.brown, fontSize: 12),
                    ),
                  ),
                  for (final t in offered)
                    _TaskCard(
                      task: t,
                      busy: p.isTaskBusy(t.id),
                      onAccept: () => _accept(t),
                      onDecline: () => _decline(t),
                    ),
                  const SizedBox(height: 12),
                ],
                if (active.isNotEmpty) ...[
                  const SectionTitle('Sedang Saya Tangani',
                      icon: Icons.directions_run_rounded),
                  const SizedBox(height: 10),
                  for (final t in active)
                    _TaskCard(
                      task: t,
                      busy: p.isTaskBusy(t.incident.id),
                      onUpdate: t.incident.status.caretakerNextStatuses
                              .isNotEmpty
                          ? () => showIncidentStatusSheet(context, t.incident)
                          : null,
                    ),
                  const SizedBox(height: 12),
                ],
                if (done.isNotEmpty) ...[
                  const SectionTitle('Selesai', icon: Icons.task_alt_rounded),
                  const SizedBox(height: 10),
                  for (final t in done) _TaskCard(task: t, busy: false),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.busy,
    this.onAccept,
    this.onDecline,
    this.onUpdate,
  });

  final CaretakerTask task;
  final bool busy;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) {
    final canOpen = task.status != AssignmentStatus.offered;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          IncidentTicketCard(
            incident: task.incident,
            onTap: canOpen
                ? () => context.push('/incidents/${task.incident.id}')
                : null,
            trailing: MeowPill(task.status.label),
          ),
          if (onAccept != null || onDecline != null || onUpdate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  if (onDecline != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : onDecline,
                        child: const Text('Tolak'),
                      ),
                    ),
                  if (onDecline != null && onAccept != null)
                    const SizedBox(width: 10),
                  if (onAccept != null)
                    Expanded(
                      child: FilledButton(
                        onPressed: busy ? null : onAccept,
                        child: busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Terima Tugas'),
                      ),
                    ),
                  if (onUpdate != null)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: busy ? null : onUpdate,
                        icon: const Icon(Icons.update_rounded),
                        label: const Text('Perbarui Status'),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
