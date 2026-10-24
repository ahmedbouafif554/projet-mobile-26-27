import 'package:flutter/material.dart';

import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/app_network_image.dart';
import '../../../../../core/widgets/circle_icon_button.dart';

/// Paramètres de la visionneuse (passés via `extra` de go_router).
class PhotoViewerArgs {
  const PhotoViewerArgs({
    required this.photos,
    required this.heroTags,
    this.initialIndex = 0,
  });

  final List<String> photos;
  final List<String> heroTags;
  final int initialIndex;
}

/// Tag Hero d'une photo d'avis (unique par liste affichée).
String reviewPhotoTag(String origin, String reviewId, int index) =>
    'review-photo-$origin-$reviewId-$index';

/// Visionneuse plein écran : glisser entre les photos, pincer pour zoomer.
class PhotoViewerPage extends StatefulWidget {
  const PhotoViewerPage({super.key, required this.args});

  final PhotoViewerArgs? args;

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late int _index = widget.args?.initialIndex ?? 0;
  late final _controller = PageController(initialPage: _index);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (args == null || args.photos.isEmpty)
              Center(
                child: Text(
                  'Aucune photo à afficher',
                  style: context.text.bodyLarge?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              )
            else
              PageView.builder(
                controller: _controller,
                itemCount: args.photos.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Hero(
                      tag: args.heroTags[i],
                      child: AppNetworkImage(
                        args.photos[i],
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: AppSizes.sm,
              left: AppSizes.md,
              right: AppSizes.md,
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.close_rounded,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    iconColor: Colors.white,
                    tooltip: 'Fermer',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  if (args != null && args.photos.length > 1)
                    Text(
                      '${_index + 1} / ${args.photos.length}',
                      style: context.text.titleSmall?.copyWith(
                        color: Colors.white,
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
