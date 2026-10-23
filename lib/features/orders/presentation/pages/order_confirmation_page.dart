import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../models/order.dart';
import '../controllers/orders_controller.dart';

/// Confirmation de commande avec animation Lottie de succès.
/// Le retour arrière ramène à l'accueil (la commande est déjà passée).
class OrderConfirmationPage extends StatelessWidget {
  const OrderConfirmationPage({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final order = OrdersController.instance.byId(orderId);
    final eta = (order?.createdAt ?? DateTime.now()).add(
      Duration(minutes: order?.etaMinutes ?? 30),
    );
    final isParcel = order?.type == OrderType.parcel;
    // Animation plus petite sur les écrans peu hauts.
    final lottieSize = (context.screenSize.height * 0.3).clamp(150.0, 230.0);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: Scaffold(
        body: SafeArea(
          // Défilable sur les petits écrans, centré verticalement sinon.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - AppSizes.lg * 2,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: CircleIconButton(
                          icon: Icons.close_rounded,
                          tooltip: "Retour à l'accueil",
                          onTap: () => context.go(AppRoutes.home),
                        ),
                      ),
                      const Spacer(),
                      Lottie.asset(
                        AppAssets.lottieSuccess,
                        width: lottieSize,
                        height: lottieSize,
                        repeat: false,
                      ),
                      Text(
                            isParcel
                                ? 'Coursier en route !'
                                : 'Commande confirmée !',
                            style: context.text.headlineMedium,
                            textAlign: TextAlign.center,
                          )
                          .animate(delay: 700.ms)
                          .fadeIn(duration: 500.ms)
                          .slideY(begin: 0.4, end: 0),
                      const SizedBox(height: AppSizes.sm),
                      Text(
                        isParcel
                            ? 'Un coursier va récupérer votre colis dans quelques minutes.'
                            : 'Merci ! ${order?.title ?? 'Le restaurant'} prépare déjà votre commande.',
                        textAlign: TextAlign.center,
                        style: context.text.bodyLarge?.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ).animate(delay: 850.ms).fadeIn(duration: 500.ms),
                      const SizedBox(height: AppSizes.lg),
                      Container(
                            padding: const EdgeInsets.all(AppSizes.md),
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusLg,
                              ),
                              boxShadow: context.palette.softShadow,
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _InfoColumn(
                                      label: 'N° de commande',
                                      value:
                                          order?.displayNumber ?? '#$orderId',
                                    ),
                                  ),
                                  const VerticalDivider(width: 24),
                                  Expanded(
                                    child: _InfoColumn(
                                      label: 'Arrivée estimée',
                                      value: Formatters.time(eta),
                                      valueColor: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .animate(delay: 1000.ms)
                          .fadeIn(duration: 500.ms)
                          .scaleXY(
                            begin: 0.9,
                            end: 1,
                            curve: Curves.easeOutBack,
                          ),
                      const Spacer(),
                      PrimaryButton(
                            label: 'Suivre ma commande',
                            icon: Icons.delivery_dining_rounded,
                            onPressed: () =>
                                context.go(AppRoutes.trackingOf(orderId)),
                          )
                          .animate(delay: 1200.ms)
                          .fadeIn()
                          .slideY(begin: 0.5, end: 0),
                      const SizedBox(height: 12),
                      OutlinedButton(
                            onPressed: () => context.go(AppRoutes.home),
                            child: const Text("Retour à l'accueil"),
                          )
                          .animate(delay: 1300.ms)
                          .fadeIn()
                          .slideY(begin: 0.5, end: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: context.text.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: context.text.titleLarge?.copyWith(color: valueColor),
        ),
      ],
    );
  }
}
