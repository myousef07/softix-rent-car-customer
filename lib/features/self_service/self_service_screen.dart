import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

import '../../core/form_data.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../../core/i18n.dart';

/// Pickup (from a booking) or return (of a rental) without the counter: photos of the car from
/// every side, the odometer and fuel, and at pickup a signature on the terms. The branch checks
/// it and opens or closes the contract.
class SelfServiceScreen extends ConsumerStatefulWidget {
  const SelfServiceScreen({super.key, required this.pickup, required this.id, this.minPhotos = 4});

  final bool pickup;

  /// The reservation id (pickup) or the contract id (return).
  final int id;
  final int minPhotos;

  @override
  ConsumerState<SelfServiceScreen> createState() => _SelfServiceScreenState();
}

class _SelfServiceScreenState extends ConsumerState<SelfServiceScreen> {
  static List<String> get _sides => [tr('الأمام'), tr('الخلف'), tr('الجانب الأيمن'), tr('الجانب الأيسر')];
  static List<String> get _fuel => [tr('فارغ'), '1/8', '1/4', '3/8', '1/2', '5/8', '3/4', '7/8', tr('ممتلئ')];

  final _form = GlobalKey<FormState>();
  final _odometer = TextEditingController();
  final _notes = TextEditingController();
  final _signature = SignatureController(penStrokeWidth: 2.5, penColor: AppColors.ink);
  final _photos = <XFile>[];
  int _fuelLevel = 8;
  bool _accepted = false;

  @override
  void dispose() {
    _odometer.dispose();
    _notes.dispose();
    _signature.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final picked = await ImagePicker().pickImage(source: kIsWeb ? ImageSource.gallery : ImageSource.camera, maxWidth: 1920, imageQuality: 80);
    if (picked != null) setState(() => _photos.add(picked));
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_photos.length < widget.minPhotos) {
      return showError(context, tr('صوّر السيارة من الجهات الأربع على الأقل ({0} من {1}).', [_photos.length, widget.minPhotos]));
    }
    if (widget.pickup && _signature.isEmpty) return showError(context, tr('وقّع في المربع أولاً.'));
    if (widget.pickup && !_accepted) return showError(context, tr('وافق على شروط العقد أولاً.'));

    try {
      final body = <String, dynamic>{
        'odometer': int.parse(_odometer.text.trim()),
        'fuel_level': _fuelLevel,
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        if (widget.pickup) 'signature': 'data:image/png;base64,${base64Encode((await _signature.toPngBytes())!)}',
        if (widget.pickup) 'accept_terms': true,
      };
      final form = await toFormData(body, fileKey: 'photos', files: _photos);
      await ref.read(repositoryProvider).sendSelfService(pickup: widget.pickup, id: widget.id, form: form);
      if (!mounted) return;
      showSuccess(context, tr('أرسلنا الطلب للفرع. يصلك إشعار عند الاعتماد.'));
      context.pop(true);
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.pickup ? tr('استلام السيارة') : tr('تسليم السيارة'))),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NoticeBanner(
            widget.pickup
                ? tr('افحص السيارة قبل الاستلام وصوّرها من كل الجهات، وأي ضرر موجود صوّره عن قرب. الفرع يراجع الصور ويفتح العقد.')
                : tr('أوقف السيارة في المكان المتفق عليه، وصوّرها من كل الجهات ولوحة العدادات. الفرع يراجع ويغلق العقد.'),
            color: AppColors.primary,
            icon: Icons.photo_camera_outlined,
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: tr('صور السيارة ({0})', [_photos.length]),
            trailing: TextButton.icon(onPressed: _addPhoto, icon: const Icon(Icons.add_a_photo_outlined), label: Text(tr('صورة'))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _photos.length < _sides.length ? tr('التالية: {0}', [_sides[_photos.length]]) : tr('أضف صوراً لأي ضرر أو للعدادات.'),
                  style: const TextStyle(color: AppColors.muted),
                ),
                if (_photos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _photos.length; i++)
                        InputChip(
                          avatar: const Icon(Icons.image_outlined, size: 18),
                          label: Text(i < _sides.length ? _sides[i] : tr('صورة {0}', [i + 1])),
                          onDeleted: () => setState(() => _photos.removeAt(i)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: tr('القراءات'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _odometer,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: tr('قراءة العداد'), suffixText: tr('كم')),
                  validator: (value) => int.tryParse(value?.trim() ?? '') == null ? tr('أدخل قراءة العداد') : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(tr('مستوى الوقود')),
                    const Spacer(),
                    Text(_fuel[_fuelLevel], style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ],
                ),
                Slider(
                  value: _fuelLevel.toDouble(),
                  max: 8,
                  divisions: 8,
                  label: _fuel[_fuelLevel],
                  onChanged: (value) => setState(() => _fuelLevel = value.round()),
                ),
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  maxLength: 500,
                  decoration: InputDecoration(labelText: tr('ملاحظات (اختياري)'), hintText: tr('مثل: خدش في الباب الخلفي')),
                ),
              ],
            ),
          ),
          if (widget.pickup) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: tr('التوقيع'),
              trailing: TextButton(onPressed: _signature.clear, child: Text(tr('مسح'))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 160,
                    decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(8)),
                    clipBehavior: Clip.antiAlias,
                    child: Signature(controller: _signature, backgroundColor: Colors.white),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _accepted,
                    onChanged: (value) => setState(() => _accepted = value ?? false),
                    title: Text(tr('اطلعت على حالة السيارة وشروط العقد ووافقت عليها')),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          BusyButton(label: widget.pickup ? tr('إرسال طلب الاستلام') : tr('إرسال طلب التسليم'), icon: Icons.send_outlined, onPressed: _submit),
        ],
      ),
    ),
  );
}

/// On a booking or a rental: pick up / return from the app when possible, or how the request
/// already sent stands. Hidden when the company does not offer it.
class SelfServiceCard extends ConsumerStatefulWidget {
  const SelfServiceCard({super.key, required this.pickup, required this.id});

  final bool pickup;
  final int id;

  @override
  ConsumerState<SelfServiceCard> createState() => _SelfServiceCardState();
}

class _SelfServiceCardState extends ConsumerState<SelfServiceCard> {
  late Future<SelfServiceStatus> _status = _load();

  Future<SelfServiceStatus> _load() {
    final repository = ref.read(repositoryProvider);
    return widget.pickup ? repository.selfPickupStatus(widget.id) : repository.selfReturnStatus(widget.id);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SelfServiceStatus>(
    future: _status,
    builder: (context, snapshot) {
      final status = snapshot.data;
      if (status == null) return const SizedBox.shrink();
      // A company without self-service: nothing to show.
      if (!status.available && !status.isPending && (status.reason ?? '').contains(tr('غير مفعّل'))) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SectionCard(
          title: widget.pickup ? tr('الاستلام من التطبيق') : tr('التسليم من التطبيق'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (status.isPending)
                NoticeBanner(tr('طلبك {0}. يصلك إشعار عند الاعتماد.', [status.pendingLabel]), icon: Icons.hourglass_top_outlined)
              else ...[
                if (status.rejectedReason != null) ...[
                  NoticeBanner(tr('لم يُعتمد الطلب السابق: {0}', [status.rejectedReason]), color: AppColors.danger),
                  const SizedBox(height: 8),
                ],
                if (status.available)
                  FilledButton.icon(
                    onPressed: () async {
                      final sent = await context.push<bool>(
                        '/self-service/${widget.pickup ? 'pickup' : 'return'}/${widget.id}?photos=${status.minPhotos}',
                      );
                      if (sent == true && mounted) setState(() => _status = _load());
                    },
                    icon: Icon(widget.pickup ? Icons.key_outlined : Icons.assignment_return_outlined),
                    label: Text(widget.pickup ? tr('استلم السيارة الآن') : tr('سلّم السيارة الآن')),
                  )
                else
                  Text(status.reason ?? '', style: const TextStyle(color: AppColors.muted)),
              ],
            ],
          ),
        ),
      );
    },
  );
}
