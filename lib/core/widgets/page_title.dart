import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../theme/theme_extensions.dart';
import 'circle_icon_button.dart';

/// Grand titre de page. Ajoute un bouton retour quand la page a été ouverte
/// par-dessus une autre (ex. : la recherche depuis l'accueil).
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (Navigator.of(context).canPop()) ...[
          const AppBackButton(),
          const SizedBox(width: AppSizes.sm + 4),
        ],
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.headlineMedium,
          ),
        ),
      ],
    );
  }
}
