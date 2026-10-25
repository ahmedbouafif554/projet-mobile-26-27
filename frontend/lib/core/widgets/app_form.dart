import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/theme_extensions.dart';
import 'app_snackbar.dart';

/// Formulaire de création / modification commun aux deux apps.
///
/// Affichez-le avec [showAppForm] (panneau latéral sur grand écran, plein
/// écran sur téléphone), [showAppFormDialog] ou [showAppFormPanel]. Ces
/// fonctions acceptent aussi un widget qui construit un AppForm (un
/// StatefulWidget qui possède les TextEditingController, par exemple).
/// [onSubmit] n'est appelé que si tous les champs sont valides ; s'il lève
/// une erreur, elle est affichée et le formulaire reste ouvert. En cas de
/// succès, le formulaire se ferme et renvoie `true`.
///
/// ```dart
/// final saved = await showAppForm(context, AppForm(
///   title: 'Nouvel utilisateur',
///   onSubmit: () => repository.create(user),
///   children: [AppTextField(label: 'Nom', validator: Validators.name)],
/// ));
/// ```
class AppForm extends StatefulWidget {
  const AppForm({
    super.key,
    required this.title,
    required this.children,
    required this.onSubmit,
    this.subtitle,
    this.icon = Icons.edit_note_rounded,
    this.submitLabel = 'Enregistrer',
    this.successMessage,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  /// Champs du formulaire (AppTextField, AppDropdownField…).
  final List<Widget> children;
  final Future<void> Function() onSubmit;
  final String submitLabel;

  /// Message affiché après l'enregistrement (ex. « Utilisateur créé »).
  final String? successMessage;

  @override
  State<AppForm> createState() => _AppFormState();
}

class _AppFormState extends State<AppForm> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _submitted = false;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    // Récupéré avant la fermeture : le contexte du formulaire disparaît.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    try {
      await widget.onSubmit();
      navigator.pop(true);
      if (widget.successMessage != null && messenger != null) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(widget.successMessage!)),
              ],
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: _submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(form: widget, onClose: () => Navigator.pop(context, false)),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children:
                    [
                          for (final (i, field) in widget.children.indexed) ...[
                            if (i > 0) const SizedBox(height: AppSizes.md),
                            field,
                          ],
                        ]
                        .animate(interval: 40.ms)
                        .fadeIn(duration: 250.ms)
                        .slideY(begin: 0.08, end: 0),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: AppSizes.sm),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(widget.submitLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.form, required this.onClose});

  final AppForm form;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.sm,
        AppSizes.md,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Icon(form.icon, color: AppColors.primary),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(form.title, style: context.text.titleLarge),
                if (form.subtitle != null)
                  Text(
                    form.subtitle!,
                    style: context.text.bodySmall?.copyWith(
                      color: context.palette.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Fermer',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

/// Formulaire en boîte de dialogue centrée.
Future<bool> showAppFormDialog(BuildContext context, Widget form) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: form,
        ),
      ),
    ) ??
    false;

/// Formulaire en panneau latéral qui glisse depuis la droite.
Future<bool> showAppFormPanel(BuildContext context, Widget form) async =>
    await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: Colors.black38,
      transitionDuration: AppDurations.medium,
      pageBuilder: (context, _, _) {
        final width = math.min(500.0, MediaQuery.sizeOf(context).width);
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: context.colors.surface,
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(AppSizes.radiusXl),
            ),
            child: SizedBox(
              width: width,
              height: double.infinity,
              child: SafeArea(child: form),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) => SlideTransition(
        position: animation.drive(
          Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
        ),
        child: child,
      ),
    ) ??
    false;

/// Choix automatique : panneau latéral sur grand écran, plein écran sur
/// téléphone.
Future<bool> showAppForm(BuildContext context, Widget form) async {
  if (MediaQuery.sizeOf(context).width >= Breakpoints.compact) {
    return showAppFormPanel(context, form);
  }
  return await showDialog<bool>(
        context: context,
        builder: (context) => Dialog.fullscreen(child: SafeArea(child: form)),
      ) ??
      false;
}
