import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/page_title.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../core/widgets/shimmer_box.dart';
import '../../../../../shared/models/models.dart';
import '../../../../router/front_routes.dart';
import '../../providers/courier_providers.dart';
import '../widgets/delivery_widgets.dart';

/// Livraisons (onglet du livreur) : courses proposées, course en cours et
/// courses terminées.
class CourierDeliveriesPage extends ConsumerWidget {
  const CourierDeliveriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(availableDeliveriesProvider);
    final mine = ref.watch(myDeliveriesProvider);
    final courier = ref.watch(myCourierProvider).value;
    final current = (mine.value ?? const <Delivery>[])
        .where((d) => d.status.isActive)
        .toList();
    final done = (mine.value ?? const <Delivery>[])
        .where((d) => !d.status.isActive)
        .toList();

    Widget loading() => ShimmerScope(
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        children: [
          for (var i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSizes.md),
              child: SkeletonBox(height: 180, radius: AppSizes.radiusLg),
            ),
        ],
      ),
    );

    Widget listOf(List<Widget> cards) => ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.md,
        AppSizes.pagePadding,
        AppSizes.xl,
      ),
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.md),
      itemBuilder: (_, i) => cards[i]
          .animate(delay: (50 * (i % 6)).ms)
          .fadeIn()
          .slideY(begin: 0.06, end: 0),
    );

    final offline = courier?.status == CourierStatus.offline;

    return DefaultTabController(
      length: 3,
      initialIndex: current.isNotEmpty ? 1 : 0,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.pagePadding,
                  AppSizes.md,
                  AppSizes.pagePadding,
                  AppSizes.sm,
                ),
                child: PageTitle('Livraisons'),
              ),
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.pagePadding - 12,
                ),
                labelColor: AppColors.primary,
                indicatorColor: AppColors.primary,
                unselectedLabelColor: context.palette.textSecondary,
                labelStyle: context.text.labelLarge,
                tabs: [
                  Tab(text: 'Offres (${available.value?.length ?? 0})'),
                  Tab(text: 'En cours (${current.length})'),
                  Tab(text: 'Terminées (${done.length})'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    // Courses proposées
                    if (available.isLoading && available.value == null)
                      loading()
                    else if (offline)
                      EmptyState(
                        icon: Icons.power_settings_new_rounded,
                        title: 'Vous êtes hors ligne',
                        message:
                            'Passez en ligne depuis le tableau de bord pour voir les courses.',
                        actionLabel: 'Aller au tableau de bord',
                        onAction: () => context.go(FrontRoutes.courierDashboard),
                      )
                    else if ((available.value ?? const []).isEmpty)
                      const EmptyState(
                        icon: Icons.hourglass_empty_rounded,
                        title: 'Aucune course disponible',
                        message: 'Les nouvelles courses apparaîtront ici.',
                      )
                    else
                      listOf([
                        for (final d in available.value!)
                          DeliveryCard(
                            key: ValueKey(d.id),
                            delivery: d,
                            actions: _OfferActions(
                              delivery: d,
                              blocked: current.isNotEmpty,
                            ),
                          ),
                      ]),
                    // En cours
                    if (mine.isLoading && mine.value == null)
                      loading()
                    else if (current.isEmpty)
                      const EmptyState(
                        icon: Icons.delivery_dining_rounded,
                        title: 'Aucune course en cours',
                        message: 'Acceptez une course dans l’onglet « Offres ».',
                      )
                    else
                      listOf([
                        for (final d in current)
                          DeliveryCard(
                            key: ValueKey(d.id),
                            delivery: d,
                            onTap: () =>
                                context.push(FrontRoutes.courierDelivery(d.id)),
                            actions: nextStepLabel(d.status) == null
                                ? null
                                : PrimaryButton(
                                    label: nextStepLabel(d.status)!,
                                    height: 48,
                                    onPressed: () =>
                                        advanceDelivery(context, ref, d),
                                  ),
                          ),
                      ]),
                    // Terminées
                    if (mine.isLoading && mine.value == null)
                      loading()
                    else if (done.isEmpty)
                      const EmptyState(
                        icon: Icons.history_rounded,
                        title: 'Aucune course terminée',
                        message: 'Votre historique apparaîtra ici.',
                      )
                    else
                      listOf([
                        for (final d in done)
                          DeliveryCard(
                            key: ValueKey(d.id),
                            delivery: d,
                            onTap: () =>
                                context.push(FrontRoutes.courierDelivery(d.id)),
                          ),
                      ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferActions extends ConsumerStatefulWidget {
  const _OfferActions({required this.delivery, required this.blocked});

  final Delivery delivery;

  /// Une course est déjà en cours.
  final bool blocked;

  @override
  ConsumerState<_OfferActions> createState() => _OfferActionsState();
}

class _OfferActionsState extends ConsumerState<_OfferActions> {
  bool _accepting = false;

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await ref
          .read(availableDeliveriesProvider.notifier)
          .accept(widget.delivery);
      if (!mounted) return;
      AppSnackbar.success(context, 'Course acceptée ! Direction le restaurant.');
      DefaultTabController.maybeOf(context)?.animateTo(1);
    } catch (error) {
      if (mounted) {
        setState(() => _accepting = false);
        AppSnackbar.error(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _accepting
                ? null
                : () => ref
                      .read(availableDeliveriesProvider.notifier)
                      .decline(widget.delivery),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
            ),
            child: const Text('Refuser'),
          ),
        ),
        const SizedBox(width: AppSizes.sm + 4),
        Expanded(
          flex: 2,
          child: PrimaryButton(
            label: widget.blocked ? 'Course en cours' : 'Accepter',
            height: 48,
            isLoading: _accepting,
            onPressed: widget.blocked ? null : _accept,
          ),
        ),
      ],
    );
  }
}
