import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/meow_style.dart';
import '../../../core/widgets/meow_widgets.dart';
import '../data/incident_enums.dart';
import '../data/incident_model.dart';
import '../logic/incident_form_validator.dart';
import '../logic/incident_provider.dart';

/// Lembar perubahan status oleh relawan (EIR-07): transisi yang diizinkan
/// dan catatan wajib. Satu Idempotency-Key per lembar agar retry aman.
Future<void> showIncidentStatusSheet(
  BuildContext context,
  IncidentReportModel incident,
) async {
  final options = incident.status.caretakerNextStatuses;
  if (options.isEmpty) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<IncidentProvider>(),
      child: _StatusSheet(incident: incident, options: options),
    ),
  );
}

class _StatusSheet extends StatefulWidget {
  const _StatusSheet({required this.incident, required this.options});
  final IncidentReportModel incident;
  final List<IncidentStatus> options;

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  final _note = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late IncidentStatus _target = widget.options.first;
  late final String _key = context.read<IncidentProvider>().newStatusKey();
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final p = context.read<IncidentProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final failure = await p.updateStatus(
      widget.incident.id,
      toStatus: _target,
      note: _note.text,
      idempotencyKey: _key,
    );
    if (!mounted) return;
    if (failure != null) {
      setState(() => _error = failure.message);
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Status tersimpan: ${_target.label}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<IncidentProvider>().isTaskBusy(
          widget.incident.id,
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Perbarui ${widget.incident.ticketCode}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Status saat ini: ${widget.incident.status.label}',
              style: const TextStyle(color: MeowStyle.brown),
            ),
            const SizedBox(height: 14),
            for (final s in widget.options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => setState(() => _target = s),
                leading: Icon(
                  _target == s
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: _target == s ? MeowStyle.orange : MeowStyle.brown,
                ),
                title: Text(s.label),
                subtitle: Text(s.meaning),
              ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _note,
              maxLines: 3,
              validator: IncidentFormValidator.statusNote,
              decoration: InputDecoration(
                labelText: _target == IncidentStatus.resolved
                    ? 'Catatan penanganan'
                    : 'Catatan',
                hintText: 'Tindakan yang dilakukan dan kondisi kucing.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: MeowStyle.danger)),
            ],
            const SizedBox(height: 16),
            MeowButton(
              label: 'Simpan Status',
              icon: Icons.save_rounded,
              busy: busy,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
