import 'package:camera/camera.dart' show XFile;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/camera/camera_capture_page.dart';
import '../../../core/theme/meow_style.dart';
import '../../../core/widgets/meow_widgets.dart';
import '../data/incident_enums.dart';
import '../data/incident_model.dart';
import '../logic/incident_form_validator.dart';
import '../logic/incident_location_helper.dart';
import '../logic/incident_provider.dart';
import 'incident_location_picker_page.dart';
import 'incident_widgets.dart';

/// Form pembuatan tiket insiden (EIR-01 s.d. EIR-04, EIR-10).
///
/// Parameter opsional datang dari hub profil kucing, Cat Hunter (GAME-02),
/// atau Adopsi: `cat_id`, `source`, `source_ref`, `category`.
class CreateIncidentPage extends StatefulWidget {
  const CreateIncidentPage({
    super.key,
    this.catId,
    this.source = IncidentSource.direct,
    this.sourceRef,
    this.initialCategory,
  });

  final String? catId;
  final IncidentSource source;
  final String? sourceRef;
  final IncidentCategory? initialCategory;

  @override
  State<CreateIncidentPage> createState() => _CreateIncidentPageState();
}

class _CreateIncidentPageState extends State<CreateIncidentPage> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _noteController = TextEditingController();

  late IncidentCategory _category;
  IncidentUrgency _urgency = IncidentUrgency.medium;
  IncidentLocation? _location;
  String? _locationError;
  bool _locating = false;
  bool _linkCat = true;
  bool _confirmedNewAction = false;
  final List<IncidentAttachment> _attachments = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCategory;
    _category = (initial != null && initial.isReportable)
        ? initial
        : IncidentCategory.sick;
    if (_category == IncidentCategory.injured) _urgency = IncidentUrgency.high;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<IncidentProvider>();
      p.resetDraftSession();
      // EIR-10: perlu daftar tiket untuk mendeteksi tiket dari sumber sama.
      if (!p.mineLoaded && widget.source != IncidentSource.direct) {
        p.fetchMyIncidents();
      }
    });
  }

  @override
  void dispose() {
    _descController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String? get _effectiveCatId {
    if (!_linkCat || _category == IncidentCategory.newCat) return null;
    final id = widget.catId?.trim();
    return (id == null || id.isEmpty) ? null : id;
  }

  Future<void> _useGps() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    final res = await IncidentLocationHelper.current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (res.location != null) {
        _location = res.location;
      } else {
        _locationError = res.error;
      }
    });
  }

  Future<void> _pickOnMap() async {
    final picked = await Navigator.of(context).push<IncidentLocation>(
      MaterialPageRoute(
        builder: (_) => IncidentLocationPickerPage(initial: _location),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _location = picked;
        _locationError = null;
      });
    }
  }

  Future<void> _addMedia() async {
    final remaining = IncidentFormValidator.maxMedia - _attachments.length;
    if (remaining <= 0) return;
    final paths = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => CameraCapturePage(
          mode: CameraCaptureMode.photoVideo,
          maxFiles: remaining,
          purpose: 'incident',
        ),
      ),
    );
    if (paths == null || paths.isEmpty || !mounted) return;
    setState(() {
      for (final path in paths.take(remaining)) {
        if (_attachments.any((a) => a.key == path)) continue;
        final raw = path.split(RegExp(r'[\\/]')).last;
        final lower = raw.toLowerCase();
        final isVideo = lower.endsWith('.mp4') || lower.endsWith('.mov');
        final name = raw.contains('.') ? raw : '$raw.jpg';
        _attachments.add(
          IncidentAttachment(
            key: path,
            filename: name,
            isVideo: isVideo,
            readBytes: () => XFile(path).readAsBytes(),
          ),
        );
      }
    });
  }

  Future<bool> _confirmDialog() async {
    final catId = _effectiveCatId;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kirim laporan ini?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kategori: ${_category.label}'),
            Text('Urgensi: ${_urgency.label}'),
            if (catId != null) Text('Kucing: $catId'),
            if (_location != null) Text('Lokasi: ${_location!.label}'),
            Text('Lampiran: ${_attachments.length} berkas'),
            const SizedBox(height: 10),
            const Text(
              'Laporan dianggap terkirim hanya setelah server memberikan nomor tiket.',
              style: TextStyle(color: MeowStyle.brown, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Periksa lagi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _submit() async {
    final p = context.read<IncidentProvider>();
    final formOk = _formKey.currentState?.validate() ?? false;
    final locErr = IncidentFormValidator.location(_location);
    setState(() => _locationError = locErr);
    if (!formOk || locErr != null) return;

    final existing = p.activeTicketFromSource(widget.source, widget.sourceRef);
    if (existing != null && !_confirmedNewAction) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sudah ada tiket aktif dari sumber ini. Centang konfirmasi kejadian baru untuk melanjutkan.',
          ),
        ),
      );
      return;
    }

    if (!await _confirmDialog() || !mounted) return;

    final draft = IncidentDraft(
      category: _category,
      urgency: _urgency,
      description: _descController.text,
      location: _location!,
      locationNote: _noteController.text,
      catId: _effectiveCatId,
      source: widget.source,
      sourceRef: widget.sourceRef,
    );
    final ticket = await p.submit(draft, attachments: List.of(_attachments));
    if (!mounted || ticket == null) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded,
            color: MeowStyle.green, size: 44),
        title: const Text('Laporan tersimpan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ticket.ticketCode,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            IncidentStatusPill(ticket.status),
            const SizedBox(height: 12),
            const Text(
              'Tiket masuk antrean admin insiden. Perkembangan penanganan '
              'dapat dipantau di halaman tiket.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Lihat Tiket'),
          ),
        ],
      ),
    );
    if (mounted) context.pushReplacement('/incidents/${ticket.id}');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<IncidentProvider>();
    final existing = p.activeTicketFromSource(widget.source, widget.sourceRef);
    final fieldErrors = p.submitError?.fieldErrors ?? const {};

    return MeowPage(
      title: 'Buat Laporan',
      bottom: MeowButton(
        label: p.isSubmitting
            ? (p.submitStage.isEmpty ? 'Mengirim...' : p.submitStage)
            : (p.submitError != null ? 'Kirim Ulang Laporan' : 'Kirim Laporan'),
        icon: Icons.send_rounded,
        busy: p.isSubmitting,
        onPressed: _submit,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: MeowPage.scrollPadding(context, top: 12, bottom: 24),
          children: [
            if (p.submitError != null) ...[
              IncidentErrorBanner(message: p.submitError!.message),
              const SizedBox(height: 12),
            ],
            if (existing != null) ...[
              _DuplicateWarning(
                ticket: existing,
                confirmed: _confirmedNewAction,
                onChanged: (v) => setState(() => _confirmedNewAction = v),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.catId != null && widget.catId!.isNotEmpty) ...[
              _LinkedCatCard(
                catId: widget.catId!,
                source: widget.source,
                linked: _linkCat && _category != IncidentCategory.newCat,
                disabled: _category == IncidentCategory.newCat,
                onChanged: (v) => setState(() => _linkCat = v),
              ),
              const SizedBox(height: 16),
            ],
            const SectionTitle('Kategori', icon: Icons.category_rounded),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in IncidentCategory.reportable)
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 18),
                    label: Text(c.label),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_category.hint,
                style: const TextStyle(color: MeowStyle.brown, fontSize: 12)),
            const SizedBox(height: 20),
            const SectionTitle('Urgensi Awal',
                icon: Icons.priority_high_rounded),
            const SizedBox(height: 10),
            SegmentedButton<IncidentUrgency>(
              segments: [
                for (final u in IncidentUrgency.values)
                  ButtonSegment(value: u, label: Text(u.label)),
              ],
              selected: {_urgency},
              onSelectionChanged: (s) => setState(() => _urgency = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              '${_urgency.help} Admin dapat menyesuaikan urgensi setelah meninjau.',
              style: const TextStyle(color: MeowStyle.brown, fontSize: 12),
            ),
            const SizedBox(height: 20),
            const SectionTitle('Deskripsi Kondisi',
                icon: Icons.description_rounded),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descController,
              maxLines: 4,
              maxLength: IncidentFormValidator.maxDescription,
              validator: IncidentFormValidator.description,
              decoration: InputDecoration(
                hintText:
                    'Jelaskan kondisi kucing, ciri-ciri, dan apa yang Anda lihat.',
                errorText: fieldErrors['description'],
              ),
            ),
            const SizedBox(height: 12),
            const SectionTitle('Lokasi', icon: Icons.place_rounded),
            const SizedBox(height: 10),
            _LocationCard(
              location: _location,
              error: _locationError ?? fieldErrors['location'],
              locating: _locating,
              onGps: _useGps,
              onMap: _pickOnMap,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              maxLength: IncidentFormValidator.maxLocationNote,
              validator: IncidentFormValidator.locationNote,
              decoration: InputDecoration(
                labelText: 'Patokan lokasi (opsional)',
                hintText: 'Contoh: dekat kantin Gedung TULT',
                errorText: fieldErrors['location_note'],
              ),
            ),
            const SizedBox(height: 12),
            SectionTitle(
              'Foto atau Video (opsional)',
              icon: Icons.photo_camera_rounded,
              trailing: Text(
                '${_attachments.length}/${IncidentFormValidator.maxMedia}',
                style: const TextStyle(color: MeowStyle.brown),
              ),
            ),
            const SizedBox(height: 10),
            _AttachmentList(
              attachments: _attachments,
              onRemove: (a) => setState(() => _attachments.remove(a)),
            ),
            if (_attachments.length < IncidentFormValidator.maxMedia) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: p.isSubmitting ? null : _addMedia,
                icon: const Icon(Icons.add_a_photo_rounded),
                label: const Text('Ambil dengan kamera'),
              ),
            ],
            if (fieldErrors['media_ids'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(fieldErrors['media_ids']!,
                    style: const TextStyle(color: MeowStyle.danger)),
              ),
            const SizedBox(height: 16),
            const Text(
              'Lampiran tidak wajib agar laporan darurat tetap bisa dikirim cepat. '
              'Nomor kontak dan media Anda tidak ditampilkan di daftar publik.',
              style: TextStyle(color: MeowStyle.brown, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkedCatCard extends StatelessWidget {
  const _LinkedCatCard({
    required this.catId,
    required this.source,
    required this.linked,
    required this.disabled,
    required this.onChanged,
  });

  final String catId;
  final IncidentSource source;
  final bool linked;
  final bool disabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            const IconBubble(Icons.pets_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    disabled
                        ? 'Kucing baru tidak ditautkan ke profil'
                        : 'Tautkan ke kucing ini',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'ID $catId · dari ${source.label}',
                    style:
                        const TextStyle(color: MeowStyle.brown, fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch(value: linked, onChanged: disabled ? null : onChanged),
          ],
        ),
      );
}

class _DuplicateWarning extends StatelessWidget {
  const _DuplicateWarning({
    required this.ticket,
    required this.confirmed,
    required this.onChanged,
  });

  final IncidentReportModel ticket;
  final bool confirmed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => GlassCard(
        color: const Color(0xFFFFF4DE),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anda sudah punya tiket aktif ${ticket.ticketCode} dari sumber yang sama.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Buat tiket baru hanya jika ada kejadian baru. Untuk perkembangan '
              'kejadian yang sama, cukup pantau tiket yang ada.',
              style: TextStyle(color: MeowStyle.brown, fontSize: 13),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => context.push('/incidents/${ticket.id}'),
                  child: const Text('Lihat tiket'),
                ),
                const Spacer(),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: confirmed,
              onChanged: (v) => onChanged(v ?? false),
              title: const Text('Ini kejadian baru, tetap buat tiket'),
            ),
          ],
        ),
      );
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.location,
    required this.error,
    required this.locating,
    required this.onGps,
    required this.onMap,
  });

  final IncidentLocation? location;
  final String? error;
  final bool locating;
  final VoidCallback onGps;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) => GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  location == null
                      ? Icons.location_off_rounded
                      : Icons.location_on_rounded,
                  color: location == null ? MeowStyle.brown : MeowStyle.green,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    location == null
                        ? 'Lokasi belum ditentukan'
                        : '${location!.label}\n'
                            '${location!.fromGps ? 'GPS' : 'Pin manual'}'
                            '${location!.accuracyM != null ? ' · ±${location!.accuracyM!.round()} m' : ''}',
                    style: const TextStyle(height: 1.35),
                  ),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: MeowStyle.danger)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: locating ? null : onGps,
                    icon: locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded),
                    label: const Text('Pakai GPS'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMap,
                    icon: const Icon(Icons.map_rounded),
                    label: Text(location == null ? 'Pilih di peta' : 'Koreksi pin'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Lokasi hanya diminta saat Anda menekan tombol dan hanya terlihat oleh admin serta petugas yang ditugaskan.',
              style: TextStyle(color: MeowStyle.brown, fontSize: 11),
            ),
          ],
        ),
      );
}

class _AttachmentList extends StatelessWidget {
  const _AttachmentList({required this.attachments, required this.onRemove});
  final List<IncidentAttachment> attachments;
  final ValueChanged<IncidentAttachment> onRemove;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return const Text('Belum ada lampiran.',
          style: TextStyle(color: MeowStyle.brown));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < attachments.length; i++)
          InputChip(
            avatar: Icon(
              attachments[i].isVideo
                  ? Icons.videocam_rounded
                  : Icons.image_rounded,
              size: 18,
            ),
            label: Text('${attachments[i].isVideo ? 'Video' : 'Foto'} ${i + 1}'),
            onDeleted: () => onRemove(attachments[i]),
          ),
      ],
    );
  }
}
