import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_form.dart';
import '../../../core/widgets/app_form_fields.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../shared/models/models.dart';
import 'communication_controllers.dart';

/// Création ([campaign] null) ou modification d'une campagne de
/// notifications (brouillon ou programmée).
Future<bool> openCampaignForm(
  BuildContext context, {
  NotificationCampaign? campaign,
}) => showAppForm(context, CampaignForm(campaign: campaign));

class CampaignForm extends ConsumerStatefulWidget {
  const CampaignForm({super.key, this.campaign});

  final NotificationCampaign? campaign;

  @override
  ConsumerState<CampaignForm> createState() => _CampaignFormState();
}

class _CampaignFormState extends ConsumerState<CampaignForm> {
  late final NotificationCampaign? _c = widget.campaign;
  late final _title = TextEditingController(text: _c?.title);
  late final _body = TextEditingController(text: _c?.body);
  late CampaignAudience _audience = _c?.audience ?? CampaignAudience.all;
  late DateTime? _scheduledAt = _c?.scheduledAt;

  @override
  void initState() {
    super.initState();
    // L'aperçu suit la saisie.
    _title.addListener(() => setState(() {}));
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _scheduledAt ?? now.add(const Duration(hours: 2));
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(
      () => _scheduledAt = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _save() {
    final base =
        _c ??
        NotificationCampaign(
          id: '',
          title: '',
          body: '',
          createdAt: DateTime.now(),
        );
    return ref
        .read(campaignsControllerProvider.notifier)
        .save(
          base.copyWith(
            title: _title.text.trim(),
            body: _body.text.trim(),
            audience: _audience,
            scheduledAt: _scheduledAt,
            status: _scheduledAt == null
                ? CampaignStatus.draft
                : CampaignStatus.scheduled,
          ),
          isNew: _c == null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = _c == null;
    return AppForm(
      title: isNew ? 'Nouvelle campagne' : 'Modifier la campagne',
      subtitle: 'Notification push envoyée dans l’application mobile.',
      icon: Icons.campaign_rounded,
      successMessage: _scheduledAt == null
          ? 'Brouillon enregistré'
          : 'Campagne programmée',
      onSubmit: _save,
      children: [
        _Preview(title: _title.text, body: _body.text),
        AppTextField(
          controller: _title,
          label: 'Titre',
          hint: '🍕 -30 % sur les pizzas ce soir',
          maxLength: 60,
          validator: (v) => Validators.required(v, field: 'Le titre'),
        ),
        AppTextField(
          controller: _body,
          label: 'Message',
          maxLines: 3,
          maxLength: 160,
          validator: (v) => Validators.required(v, field: 'Le message'),
        ),
        AppDropdownField<CampaignAudience>(
          label: 'Destinataires',
          prefixIcon: Icons.groups_outlined,
          value: _audience,
          items: CampaignAudience.values,
          itemLabel: (a) => a.label,
          onChanged: (a) => setState(() => _audience = a ?? _audience),
        ),
        AppSwitchField(
          title: 'Programmer l’envoi',
          subtitle: _scheduledAt == null
              ? 'Sinon, la campagne reste en brouillon.'
              : 'Envoi le ${Formatters.dateTime(_scheduledAt!)}',
          icon: Icons.schedule_rounded,
          value: _scheduledAt != null,
          onChanged: (on) => on
              ? _pickDate()
              : setState(() => _scheduledAt = null),
        ),
        if (_scheduledAt != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.edit_calendar_rounded),
              label: const Text('Changer la date'),
            ),
          ),
      ],
    );
  }
}

/// Aperçu de la notification sur un écran verrouillé.
class _Preview extends StatelessWidget {
  const _Preview({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B2B33), Color(0xFF15151A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppLogo(size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'SUPERFASTER',
                        style: context.text.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'maintenant',
                        style: context.text.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    title.isEmpty ? 'Titre de la notification' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    body.isEmpty ? 'Votre message apparaîtra ici.' : body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
