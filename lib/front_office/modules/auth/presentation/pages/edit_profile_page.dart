import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/auth/auth_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/app_form_fields.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../../../core/widgets/app_snackbar.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/widgets/primary_button.dart';
import '../../../../../shared/mock/mock_images.dart';
import '../../../../../shared/models/user.dart';
import '../../providers/profile_providers.dart';
import '../widgets/profile_widgets.dart';

/// Modification du profil : photo, nom, e-mail et téléphone.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final User _user = ref.read(authServiceProvider).user!;
  late final _firstName = TextEditingController(text: _user.firstName);
  late final _lastName = TextEditingController(text: _user.lastName);
  late final _email = TextEditingController(text: _user.email);
  late final _phone = TextEditingController(text: _user.phone);
  late String? _avatarUrl = _user.avatarUrl;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _email, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(profileControllerProvider)
          .save(
            _user.copyWith(
              firstName: _firstName.text.trim(),
              lastName: _lastName.text.trim(),
              email: _email.text.trim(),
              phone: _phone.text.trim(),
              avatarUrl: _avatarUrl,
            ),
          );
      if (!mounted) return;
      AppSnackbar.success(context, 'Profil mis à jour');
      context.pop();
    } catch (error) {
      if (mounted) AppSnackbar.error(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Choix d'une photo (galerie de démonstration).
  Future<void> _pickAvatar() async {
    final photos = [
      for (var i = 0; i < 4; i++) portrait(woman: true, index: i),
      for (var i = 0; i < 4; i++) portrait(woman: false, index: i),
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            0,
            AppSizes.lg,
            AppSizes.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Photo de profil', style: context.text.titleLarge),
              const SizedBox(height: AppSizes.md),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (i, url) in photos.indexed)
                    InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.pop(context, url),
                          child: ClipOval(
                            child: AppNetworkImage(url, width: 64, height: 64),
                          ),
                        )
                        .animate(delay: (30 * i).ms)
                        .scaleXY(begin: 0.6, curve: Curves.easeOutBack),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              TextButton.icon(
                onPressed: () => Navigator.pop(context, ''),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Retirer la photo'),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      setState(() => _avatarUrl = picked.isEmpty ? null : picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _user.copyWith(
      avatarUrl: _avatarUrl,
      firstName: _firstName.text.isEmpty ? _user.firstName : _firstName.text,
      lastName: _lastName.text.isEmpty ? _user.lastName : _lastName.text,
    );
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        leading: const Center(child: AccountBackButton()),
        title: const Text('Informations personnelles'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Hero(
                      tag: profileAvatarHeroTag,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: context.palette.softShadow,
                        ),
                        child: UserAvatar(user: preview, size: 112),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Material(
                        color: AppColors.primary,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Changer la photo',
                          onPressed: _pickAvatar,
                          icon: const Icon(
                            Icons.photo_camera_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.xl),
              ...[
                    AppFormRow(
                      children: [
                        AppTextField(
                          controller: _firstName,
                          label: 'Prénom',
                          textCapitalization: TextCapitalization.words,
                          validator: Validators.name,
                          onChanged: (_) => setState(() {}),
                        ),
                        AppTextField(
                          controller: _lastName,
                          label: 'Nom',
                          textCapitalization: TextCapitalization.words,
                          validator: Validators.name,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      controller: _email,
                      label: 'Adresse e-mail',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      controller: _phone,
                      label: 'Téléphone',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: Validators.phone,
                    ),
                  ]
                  .animate(interval: 50.ms)
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.1, end: 0),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.sm,
            AppSizes.lg,
            AppSizes.md,
          ),
          child: PrimaryButton(
            label: 'Enregistrer',
            icon: Icons.check_rounded,
            isLoading: _saving,
            onPressed: _save,
          ),
        ),
      ),
    );
  }
}
