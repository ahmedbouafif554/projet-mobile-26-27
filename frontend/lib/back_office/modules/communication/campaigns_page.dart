import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_data_table.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/status_chips.dart';
import '../../shared/bo_widgets.dart';
import '../../shell/bo_page.dart';
import 'campaign_form.dart';
import 'communication_controllers.dart';

/// Module 5 (admin) : campagnes de notifications push.
class CampaignsPage extends ConsumerWidget {
  const CampaignsPage({super.key});

  Future<void> _send(
    BuildContext context,
    WidgetRef ref,
    NotificationCampaign campaign,
  ) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Envoyer maintenant ?',
      message:
          '« ${campaign.title} » sera envoyée à : ${campaign.audience.label.toLowerCase()}.',
      confirmLabel: 'Envoyer',
      icon: Icons.send_rounded,
    );
    if (!confirmed) return;
    try {
      await ref.read(campaignsControllerProvider.notifier).send(campaign);
      if (context.mounted) AppSnackbar.success(context, 'Campagne envoyée 🚀');
    } catch (error) {
      if (context.mounted) AppSnackbar.error(context, error);
    }
  }

  Future<void> _duplicate(
    BuildContext context,
    WidgetRef ref,
    NotificationCampaign campaign,
  ) async {
    try {
      await ref
          .read(campaignsControllerProvider.notifier)
          .save(
            NotificationCampaign(
              id: '',
              title: '${campaign.title} (copie)',
              body: campaign.body,
              audience: campaign.audience,
              createdAt: DateTime.now(),
            ),
            isNew: true,
          );
      if (context.mounted) AppSnackbar.success(context, 'Brouillon dupliqué');
    } catch (error) {
      if (context.mounted) AppSnackbar.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaigns = ref.watch(campaignsControllerProvider);
    final all = campaigns.value ?? const <NotificationCampaign>[];
    final sent = all.where((c) => c.status == CampaignStatus.sent).toList();
    final recipients = sent.fold<int>(0, (s, c) => s + c.recipientCount);
    final openRate = sent.isEmpty
        ? 0.0
        : sent.fold<double>(0, (s, c) => s + c.openRate) / sent.length * 100;

    return BoPage(
      title: 'Campagnes',
      subtitle: 'Notifications push envoyées à vos utilisateurs.',
      onAdd: () => openCampaignForm(context),
      addLabel: 'Nouvelle campagne',
      children: [
        ResponsiveGrid(
          maxColumns: 3,
          children: [
            StatCard(
              label: 'Campagnes envoyées',
              value: sent.length,
              icon: Icons.send_rounded,
              caption: '${all.length - sent.length} en attente',
            ),
            StatCard(
              label: 'Notifications envoyées',
              value: recipients,
              format: Formatters.compact,
              icon: Icons.notifications_active_rounded,
              color: AppColors.info,
              caption: 'Toutes campagnes confondues',
            ),
            StatCard(
              label: "Taux d'ouverture moyen",
              value: openRate,
              format: (v) => '${Formatters.rating(v)} %',
              icon: Icons.touch_app_rounded,
              color: AppColors.success,
              caption: 'Moyenne du secteur : 20 %',
            ),
          ],
        ),
        boGap,
        AppDataTable<NotificationCampaign>(
          items: campaigns.value,
          isLoading: campaigns.isLoading,
          error: campaigns.error,
          onRetry: () => ref.invalidate(campaignsControllerProvider),
          searchHint: 'Titre, message…',
          searchText: (c) => '${c.title} ${c.body}',
          initialSortColumn: 4,
          initialSortAscending: false,
          filters: [
            AppTableFilter(
              label: 'Statut',
              options: {for (final s in CampaignStatus.values) s.name: s.label},
              test: (c, v) => c.status.name == v,
            ),
            AppTableFilter(
              label: 'Audience',
              icon: Icons.groups_outlined,
              options: {
                for (final a in CampaignAudience.values) a.name: a.label,
              },
              test: (c, v) => c.audience.name == v,
            ),
          ],
          columns: [
            AppTableColumn(
              label: 'Campagne',
              primary: true,
              flex: 5,
              sortValue: (c) => c.title,
              cell: (context, c) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall,
                  ),
                  Text(
                    c.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AppTableColumn(
              label: 'Audience',
              flex: 2,
              sortValue: (c) => c.audience.index,
              cell: (context, c) =>
                  Text(c.audience.label, style: context.text.bodySmall),
            ),
            AppTableColumn(
              label: 'Statut',
              sortValue: (c) => c.status.index,
              cell: (_, c) => campaignStatusChip(c.status),
            ),
            AppTableColumn(
              label: 'Ouverture',
              flex: 2,
              sortValue: (c) => c.openRate,
              cell: (context, c) => c.status != CampaignStatus.sent
                  ? Text('—', style: context.text.bodySmall)
                  : Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: c.openRate,
                              minHeight: 6,
                              color: AppColors.success,
                              backgroundColor: context.palette.surfaceMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(c.openRate * 100).round()} %',
                          style: context.text.labelMedium,
                        ),
                      ],
                    ),
            ),
            AppTableColumn(
              label: 'Date',
              flex: 2,
              sortValue: (c) => c.sentAt ?? c.scheduledAt ?? c.createdAt,
              cell: (context, c) => Text(
                switch (c.status) {
                  CampaignStatus.sent =>
                    'Envoyée ${Formatters.relative(c.sentAt ?? c.createdAt).toLowerCase()}\n${Formatters.compact(c.recipientCount)} destinataires',
                  CampaignStatus.scheduled =>
                    'Prévue le ${Formatters.dateTime(c.scheduledAt ?? c.createdAt)}',
                  CampaignStatus.draft =>
                    'Créée le ${Formatters.date(c.createdAt)}',
                },
                style: context.text.bodySmall,
              ),
            ),
          ],
          onEdit: (c) => c.status == CampaignStatus.sent
              ? AppSnackbar.info(
                  context,
                  'Une campagne envoyée ne peut plus être modifiée : dupliquez-la.',
                )
              : openCampaignForm(context, campaign: c),
          onDelete: (c) =>
              ref.read(campaignsControllerProvider.notifier).remove(c.id),
          deleteMessage: (c) => '« ${c.title} » sera supprimée.',
          actions: [
            AppTableAction(
              label: 'Envoyer maintenant',
              icon: Icons.send_rounded,
              isVisible: (c) => c.status != CampaignStatus.sent,
              onSelected: (c) => _send(context, ref, c),
            ),
            AppTableAction(
              label: 'Dupliquer',
              icon: Icons.copy_rounded,
              onSelected: (c) => _duplicate(context, ref, c),
            ),
          ],
        ),
      ],
    );
  }
}
