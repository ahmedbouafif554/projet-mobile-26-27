import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/selectable_tile.dart';
import '../../data/profile_mock_data.dart';
import '../controllers/profile_controller.dart';

/// Choix de la langue (démo : l'interface reste en français).
class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileController.instance;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        leading: const Center(child: AppBackButton()),
        title: const Text('Langue'),
      ),
      body: ListenableBuilder(
        listenable: profile,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            for (final (i, language) in ProfileMockData.languages.indexed)
              Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SelectableTile(
                      leading: Text(
                        language.flag,
                        style: const TextStyle(fontSize: 28),
                      ),
                      title: language.name,
                      subtitle: language.code.toUpperCase(),
                      selected: profile.languageCode == language.code,
                      onTap: () {
                        profile.setLanguage(language.code);
                        AppSnackbar.success(
                          context,
                          'Langue : ${language.name} (démo, textes en français)',
                        );
                      },
                    ),
                  )
                  .animate(delay: (50 * i).ms)
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.2, end: 0),
            const SizedBox(height: AppSizes.sm),
            Text(
              "La traduction complète sera branchée avec les fichiers de localisation (flutter_localizations / intl).",
              style: context.text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
