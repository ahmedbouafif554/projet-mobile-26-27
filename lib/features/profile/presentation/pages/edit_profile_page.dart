import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/circle_icon_button.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/primary_button.dart';
import '../controllers/profile_controller.dart';

/// Modification des informations personnelles.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _user = ProfileController.instance.user;
  late final _firstName = TextEditingController(text: _user.firstName);
  late final _lastName = TextEditingController(text: _user.lastName);
  late final _email = TextEditingController(text: _user.email);
  late final _phone = TextEditingController(text: _user.phone);
  bool _saving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    ProfileController.instance.updateUser(
      _user.copyWith(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
      ),
    );
    AppSnackbar.success(context, 'Profil mis à jour');
    context.pop();
  }

  void _changePhoto() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.md,
            0,
            AppSizes.md,
            AppSizes.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Photo de profil', style: context.text.titleMedium),
              const SizedBox(height: AppSizes.sm),
              for (final (icon, label) in [
                (Icons.photo_camera_outlined, 'Prendre une photo'),
                (Icons.photo_library_outlined, 'Choisir dans la galerie'),
              ])
                ListTile(
                  leading: Icon(icon, color: AppColors.primary),
                  title: Text(label),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    AppSnackbar.show(
                      context,
                      'Fonction disponible avec le backend',
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 68,
        leading: const Center(child: AppBackButton()),
        title: const Text('Mes informations'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            Center(
              child:
                  Pressable(
                    onTap: _changePhoto,
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: AppNetworkImage(
                              _user.avatarUrl,
                              width: 110,
                              height: 110,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.colors.surface,
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.photo_camera_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().scaleXY(
                    begin: 0.7,
                    end: 1,
                    duration: 600.ms,
                    curve: Curves.easeOutBack,
                  ),
            ),
            const SizedBox(height: AppSizes.xl),
            ...[
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _firstName,
                          label: 'Prénom',
                          prefixIcon: Icons.person_outline_rounded,
                          textCapitalization: TextCapitalization.words,
                          validator: Validators.name,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          controller: _lastName,
                          label: 'Nom',
                          textCapitalization: TextCapitalization.words,
                          validator: Validators.name,
                        ),
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
                    prefixIcon: Icons.phone_iphone_rounded,
                    keyboardType: TextInputType.phone,
                    validator: Validators.phone,
                  ),
                ]
                .animate(interval: 60.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.15, end: 0),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.sm,
            AppSizes.pagePadding,
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
