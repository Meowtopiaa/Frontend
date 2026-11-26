import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/camera/camera_capture_page.dart';
import '../data/adoption_enums.dart';
import '../data/my_adoption_model.dart';
import '../logic/adoption_provider.dart';
import 'adoption_theme.dart';
import 'adoption_widgets.dart';

/// Layar 8: laporan kendala adopsi (ADP-13, EN-23).
///
/// Laporan tidak menutup adopsi. Untuk kucing yang butuh bantuan, adopter dapat
/// meminta laporan diteruskan sebagai tiket insiden dengan persetujuannya.
/// Tiket dari kucing teradopsi ditangani admin, bukan relawan kampus.
class AdoptionIssueReportPage extends StatefulWidget {
  final String adoptionId;
  final String catName;

  const AdoptionIssueReportPage({
    super.key,
    required this.adoptionId,
    required this.catName,
  });

  @override
  State<AdoptionIssueReportPage> createState() =>
      _AdoptionIssueReportPageState();
}

class _AdoptionIssueReportPageState extends State<AdoptionIssueReportPage> {
  static const _uuid = Uuid();

  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  AdoptionIssueCategory _category = AdoptionIssueCategory.SICK;
  bool _requestIncident = false;
  String? _photo;
  AdoptionIssueResult? _result;

  /// Satu kunci untuk satu isian. Dipakai ulang saat kirim ulang isian yang
  /// sama (misalnya jaringan putus), dan diganti bila isian berubah.
  String? _idempotencyKey;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _onInputChanged() => _idempotencyKey = null;

  void _selectCategory(AdoptionIssueCategory category) {
    setState(() {
      _category = category;
      if (!issueCategoryAllowsIncident(category)) _requestIncident = false;
      _onInputChanged();
    });
  }

  Future<void> _takeOptionalPhoto() async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => const CameraCapturePage(
          mode: CameraCaptureMode.cameraOnly,
          maxFiles: 1,
          purpose: 'adoption_issue',
        ),
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        _photo = result.first;
        _onInputChanged();
      });
    }
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AdoptionProvider>();
    _idempotencyKey ??= _uuid.v4();
    final result = await provider.submitAdoptionIssue(
      adoptionId: widget.adoptionId,
      category: _category,
      description: _descriptionController.text.trim(),
      requestIncident: _requestIncident,
      idempotencyKey: _idempotencyKey!,
      photo: provider.issuePhotoSupported ? _photo : null,
    );
    if (!mounted || result == null) return;
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdoptionTheme.pageBg,
      appBar: AppBar(
        backgroundColor: AdoptionTheme.pageBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Laporkan kendala', style: AdoptionTheme.titleStyle),
      ),
      body: widget.adoptionId.isEmpty
          ? AdoptionEmptyState(
              icon: Icons.search_off_rounded,
              message: 'Adopsi tidak ditemukan',
              submessage: 'Buka lagi laporan kendala dari halaman Kucing Saya.',
              action: AdoptionSecondaryButton(
                label: 'Kembali',
                onPressed: () => context.pop(),
              ),
            )
          : _result != null
              ? _IssueResultView(
                  result: _result!,
                  catName: widget.catName,
                  category: _category,
                )
              : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final provider = context.watch<AdoptionProvider>();
    final submitting = provider.isIssueSubmitting;

    return Form(
      key: _formKey,
      child: AdoptionPageBody(
        children: [
          AdoptionHeader(
            overline: 'Laporan kendala ${widget.catName}',
            title: 'Apa yang terjadi?',
            subtitle:
                'Laporan ini dibaca pengurus adopsi dan tidak menutup adopsimu.',
            icon: Icons.report_gmailerrorred_rounded,
          ),
          if (provider.issueError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AdoptionBanner(
                variant: 'danger',
                icon: Icons.error_outline_rounded,
                title: 'Laporan belum terkirim',
                message: provider.issueError!,
              ),
            ),
          AdoptionSection(
            title: 'Jenis kendala',
            child: Column(
              children: AdoptionIssueCategory.values
                  .map((c) => _CategoryOption(
                        category: c,
                        selected: _category == c,
                        onTap: submitting ? null : () => _selectCategory(c),
                      ))
                  .toList(),
            ),
          ),
          AdoptionSection(
            title: 'Ceritakan kejadiannya',
            description:
                'Sejak kapan, gejala yang terlihat, dan kondisi kucing sekarang.',
            child: TextFormField(
              key: const Key('issue_description'),
              controller: _descriptionController,
              enabled: !submitting,
              maxLines: 4,
              maxLength: 1000,
              onChanged: (_) => _onInputChanged(),
              style: AdoptionTheme.bodyStyle
                  .copyWith(color: AdoptionTheme.textMain),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: AdoptionTheme.borderMd,
                  borderSide: BorderSide(color: AdoptionTheme.inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AdoptionTheme.borderMd,
                  borderSide: BorderSide(color: AdoptionTheme.inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AdoptionTheme.borderMd,
                  borderSide:
                      BorderSide(color: AdoptionTheme.accent, width: 1.5),
                ),
                filled: true,
                fillColor: AdoptionTheme.cardBg,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Ceritakan kejadiannya dulu.'
                  : null,
            ),
          ),
          AdoptionSection(
            title: 'Foto',
            description: provider.issuePhotoSupported
                ? 'Opsional. Lampirkan kalau membantu pengurus memahami kondisinya.'
                : 'Lampiran foto belum tersedia. Laporan tetap bisa dikirim tanpa foto.',
            child: provider.issuePhotoSupported
                ? CameraPhotoSlot(
                    localPath: _photo,
                    hint: 'Ambil foto (opsional)',
                    onTap: submitting ? () {} : _takeOptionalPhoto,
                  )
                : const SizedBox.shrink(),
          ),
          if (issueCategoryAllowsIncident(_category))
            AdoptionSection(
              title: 'Butuh bantuan darurat?',
              description:
                  'Laporan bisa diteruskan sebagai tiket insiden. Tiket untuk '
                  'kucing adopsi ditangani admin insiden, bukan relawan kampus, '
                  'dan alamatmu tidak dibagikan ke relawan.',
              // Material sendiri agar efek sentuh terlihat di atas kartu.
              child: Material(
                type: MaterialType.transparency,
                child: CheckboxListTile(
                  key: const Key('issue_request_incident'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AdoptionTheme.accent,
                  value: _requestIncident,
                  onChanged: submitting
                      ? null
                      : (v) => setState(() {
                            _requestIncident = v ?? false;
                            _onInputChanged();
                          }),
                  title: const Text(
                    'Saya setuju laporan ini diteruskan sebagai tiket insiden.',
                    style: AdoptionTheme.bodyStyle,
                  ),
                ),
              ),
            ),
          AdoptionPrimaryButton(
            label: 'Kirim laporan',
            isLoading: submitting,
            onPressed: submitting ? null : _onSubmit,
          ),
        ],
      ),
    );
  }
}

class _CategoryOption extends StatelessWidget {
  final AdoptionIssueCategory category;
  final bool selected;
  final VoidCallback? onTap;

  const _CategoryOption({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AdoptionTheme.borderMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 22,
                color: selected ? AdoptionTheme.accent : AdoptionTheme.textHint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.labelId,
                  style: AdoptionTheme.bodyStyle.copyWith(
                    color: AdoptionTheme.textMain,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hasil setelah server menyimpan laporan. Hanya menyebut yang benar terjadi.
class _IssueResultView extends StatelessWidget {
  final AdoptionIssueResult result;
  final String catName;
  final AdoptionIssueCategory category;

  const _IssueResultView({
    required this.result,
    required this.catName,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final ticket = result.incident;
    return AdoptionPageBody(
      children: [
        AdoptionHeader(
          overline: 'Laporan kendala $catName',
          title: 'Laporan tersimpan',
          subtitle: 'Laporan ${category.labelId.toLowerCase()} sudah tercatat. '
              'Pengurus adopsi akan meninjaunya. Adopsimu tetap aktif.',
          icon: Icons.check_circle_outline_rounded,
        ),
        if (ticket != null)
          AdoptionBanner(
            variant: 'success',
            icon: Icons.confirmation_number_outlined,
            title: 'Tiket insiden ${ticket.ticketCode}',
            message: ticket.status == 'RECEIVED'
                ? 'Tiket tercatat dengan status Diterima dan masuk antrean admin '
                    'insiden. Pantau perkembangannya di menu Lapor.'
                : 'Tiket tercatat. Pantau perkembangannya di menu Lapor.',
          )
        else if (result.incidentRequested)
          const AdoptionBanner(
            variant: 'warning',
            icon: Icons.info_outline_rounded,
            title: 'Tiket insiden belum dibuat',
            message: 'Permintaan bantuanmu tercatat bersama laporan ini. '
                'Pengurus adopsi akan meninjaunya. Bila kucing dalam bahaya, '
                'segera bawa ke dokter hewan terdekat.',
          ),
        const SizedBox(height: 16),
        AdoptionPrimaryButton(
          label: 'Kembali ke Kucing Saya',
          onPressed: () => context.pop(),
        ),
      ],
    );
  }
}
