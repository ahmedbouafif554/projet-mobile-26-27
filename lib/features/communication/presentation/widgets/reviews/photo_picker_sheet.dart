import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../../../core/widgets/pressable.dart';
import '../../../../../core/widgets/primary_button.dart';

/// Galerie simulée pour joindre des photos à un avis.
/// (À remplacer par image_picker quand le téléversement sera branché à l'API.)
Future<List<String>?> showPhotoPickerSheet(
  BuildContext context, {
  required List<String> gallery,
  required List<String> selected,
  int max = 4,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _PhotoPickerSheet(gallery: gallery, initial: selected, max: max),
  );
}

class _PhotoPickerSheet extends StatefulWidget {
  const _PhotoPickerSheet({
    required this.gallery,
    required this.initial,
    required this.max,
  });

  final List<String> gallery;
  final List<String> initial;
  final int max;

  @override
  State<_PhotoPickerSheet> createState() => _PhotoPickerSheetState();
}

class _PhotoPickerSheetState extends State<_PhotoPickerSheet> {
  late final List<String> _selected = [...widget.initial];

  void _toggle(String url) {
    setState(() {
      if (_selected.contains(url)) {
        _selected.remove(url);
      } else if (_selected.length < widget.max) {
        _selected.add(url);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.pagePadding,
          0,
          AppSizes.pagePadding,
          AppSizes.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ajouter des photos', style: context.text.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Jusqu\'à ${widget.max} photos • galerie de démonstration',
              style: context.text.bodySmall,
            ),
            const SizedBox(height: AppSizes.md),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (final (i, url) in widget.gallery.indexed)
                    _PhotoCell(
                          url: url,
                          order: _selected.indexOf(url),
                          onTap: () => _toggle(url),
                        )
                        .animate(delay: (35 * i).ms)
                        .fadeIn()
                        .scaleXY(begin: 0.85, end: 1),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.md),
            PrimaryButton(
              label: _selected.isEmpty
                  ? 'Aucune photo'
                  : 'Ajouter ${_selected.length} photo${_selected.length > 1 ? 's' : ''}',
              icon: Icons.add_photo_alternate_rounded,
              onPressed: () => Navigator.pop(context, _selected),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoCell extends StatelessWidget {
  const _PhotoCell({
    required this.url,
    required this.order,
    required this.onTap,
  });

  final String url;

  /// Position dans la sélection (-1 si non sélectionnée).
  final int order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = order >= 0;
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedPadding(
            duration: AppDurations.fast,
            padding: EdgeInsets.all(selected ? 6 : 0),
            child: AppNetworkImage(
              url,
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
          ),
          AnimatedContainer(
            duration: AppDurations.fast,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: AnimatedScale(
              scale: selected ? 1 : 0,
              duration: AppDurations.fast,
              curve: Curves.easeOutBack,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${order + 1}',
                  style: context.text.labelMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
