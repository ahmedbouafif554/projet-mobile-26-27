import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/location/geocoding_service.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_sizes.dart';
import '../../../../../core/theme/theme_extensions.dart';
import '../../../../../core/widgets/app_snackbar.dart';

/// Carte de l'adresse de livraison : le client place exactement sa position
/// (le repère reste au centre, on déplace la carte ou on touche un point),
/// se localise par GPS ou retrouve l'adresse saisie. La position est
/// obligatoire : le livreur reçoit ces coordonnées avec la course.
class AddressMapField extends StatefulWidget {
  const AddressMapField({
    super.key,
    required this.initial,
    required this.onChanged,
    required this.onAddressFound,
    required this.searchQuery,
    this.geocoding,
    this.height = 260,
  });

  /// Position déjà placée (null : à placer).
  final LatLng? initial;
  final ValueChanged<LatLng> onChanged;

  /// Adresse trouvée pour la position choisie (remplit les champs).
  final ValueChanged<GeocodedAddress> onAddressFound;

  /// Adresse saisie dans le formulaire, pour « Trouver l'adresse saisie ».
  final String Function() searchQuery;
  final GeocodingService? geocoding;
  final double height;

  /// Centre de la carte tant que rien n'est placé (Paris).
  static const fallbackCenter = LatLng(48.8566, 2.3522);

  @override
  State<AddressMapField> createState() => _AddressMapFieldState();
}

class _AddressMapFieldState extends State<AddressMapField> {
  late final GeocodingService _geo = widget.geocoding ?? GeocodingService();
  final _map = MapController();
  late LatLng? _position = widget.initial;
  GeocodedAddress? _found;
  bool _busy = false;
  Timer? _debounce;
  final _fieldKey = GlobalKey<FormFieldState<LatLng>>();

  @override
  void dispose() {
    _debounce?.cancel();
    _map.dispose();
    super.dispose();
  }

  /// Nouvelle position choisie par le client.
  void _place(LatLng position, {bool move = false, bool lookup = true}) {
    if (move) {
      _map.move(position, _map.camera.zoom < 16 ? 17 : _map.camera.zoom);
    }
    setState(() => _position = position);
    _fieldKey.currentState?.didChange(position);
    widget.onChanged(position);
    if (!lookup) return;
    // Nominatim : au plus une requête par seconde.
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 900),
      () => _reverse(position),
    );
  }

  Future<void> _reverse(LatLng position) async {
    final found = await _geo.reverse(position);
    if (!mounted || found == null || _position != position) return;
    setState(() => _found = found);
  }

  Future<void> _locate() async {
    setState(() => _busy = true);
    try {
      final here = await _geo.currentPosition();
      if (!mounted) return;
      _place(here, move: true);
    } on LocationException catch (e) {
      if (mounted) AppSnackbar.error(context, e.message);
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(
          context,
          'Position introuvable. Placez le repère à la main.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _searchTyped() async {
    final query = widget.searchQuery();
    if (query.trim().length < 3) {
      AppSnackbar.info(
        context,
        'Saisissez d’abord l’adresse, le code postal et la ville.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final found = await _geo.search(query);
      if (!mounted) return;
      if (found == null) {
        AppSnackbar.info(
          context,
          'Adresse introuvable : placez le repère sur la carte.',
        );
        return;
      }
      _place(found.position, move: true, lookup: false);
      setState(() => _found = found);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<LatLng>(
      key: _fieldKey,
      initialValue: _position,
      validator: (value) =>
          value == null ? 'Placez votre adresse exacte sur la carte.' : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Position exacte', style: context.text.labelLarge),
          const SizedBox(height: AppSizes.xs),
          Text(
            'Déplacez la carte pour mettre le repère sur votre porte : '
            'le livreur reçoit cette position.',
            style: context.text.bodySmall?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            child: Container(
              height: widget.height,
              decoration: BoxDecoration(
                border: Border.all(
                  color: field.hasError
                      ? AppColors.error
                      : context.colors.outlineVariant,
                  width: field.hasError ? 1.4 : 1,
                ),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter:
                          _position ?? AddressMapField.fallbackCenter,
                      initialZoom: _position == null ? 12 : 17,
                      minZoom: 3,
                      maxZoom: 19,
                      onTap: (_, point) => _place(point, move: true),
                      // Le repère suit le centre quand le client déplace la carte.
                      onPositionChanged: (camera, hasGesture) {
                        if (hasGesture) _place(camera.center);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.superfaster.app',
                      ),
                      const RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            '© les contributeurs d’OpenStreetMap',
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Repère fixe au centre (sa pointe marque la position).
                  IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 40),
                        child: Icon(
                          Icons.location_on_rounded,
                          size: 44,
                          color: _position == null
                              ? Colors.grey
                              : AppColors.primary,
                          shadows: const [
                            Shadow(blurRadius: 6, color: Colors.black26),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_position == null)
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 12,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.surface.withValues(
                              alpha: 0.92,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusSm,
                            ),
                          ),
                          child: Text(
                            'Touchez la carte ou utilisez « Ma position »',
                            textAlign: TextAlign.center,
                            style: context.text.bodySmall,
                          ),
                        ),
                      ),
                    ),
                  if (_busy)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x33000000),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.sm,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _locate,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Ma position'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _searchTyped,
                icon: const Icon(Icons.travel_explore_rounded),
                label: const Text('Trouver l’adresse saisie'),
              ),
            ],
          ),
          if (_position != null) ...[
            const SizedBox(height: AppSizes.xs),
            Text(
              'GPS : ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
              style: context.text.labelSmall?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ],
          if (_found != null && _found!.label.isNotEmpty) ...[
            const SizedBox(height: AppSizes.sm),
            Material(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.place_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_found!.label, style: context.text.bodySmall),
                    ),
                    TextButton(
                      onPressed: () => widget.onAddressFound(_found!),
                      child: const Text('Utiliser'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (field.hasError) ...[
            const SizedBox(height: 6),
            Text(
              field.errorText!,
              style: context.text.bodySmall?.copyWith(color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }
}
