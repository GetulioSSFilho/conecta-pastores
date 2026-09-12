import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../churches/data/churches_providers.dart';
import '../data/map_providers.dart';
import '../domain/map_models.dart';

/// Mapa das igrejas da rede, com os pontos que a API autoriza ver.
class ChurchMapScreen extends ConsumerStatefulWidget {
  const ChurchMapScreen({super.key});

  @override
  ConsumerState<ChurchMapScreen> createState() => _ChurchMapScreenState();
}

class _ChurchMapScreenState extends ConsumerState<ChurchMapScreen> {
  final _controller = MapController();
  ChurchMapPoint? _selected;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.windowSize.pagePadding;
    final points = ref.watch(churchMapProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mapa',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                switch (points) {
                  AsyncData(:final value) =>
                    '${value.length} ${value.length == 1 ? 'igreja localizada' : 'igrejas localizadas'}',
                  _ => 'Igrejas com endereço cadastrado',
                },
                style: const TextStyle(color: AppColors.mutedInk),
              ),
              const SizedBox(height: AppTokens.space12),
              const _CountryFilter(),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              padding,
              AppTokens.space16,
              padding,
              AppTokens.space16,
            ),
            child: AsyncValueView(
              value: points,
              onRetry: () => ref.invalidate(churchMapProvider),
              loading: const Center(child: CircularProgressIndicator()),
              data: (list) => list.isEmpty
                  ? const InlineEmpty(
                      icon: Icons.location_off_outlined,
                      message: 'Nenhuma igreja com coordenadas no seu escopo.',
                    )
                  : _Map(
                      controller: _controller,
                      points: list,
                      selected: _selected,
                      onSelect: (point) => setState(() => _selected = point),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CountryFilter extends ConsumerWidget {
  const _CountryFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(mapCountryFilterProvider);

    return AsyncValueView(
      value: ref.watch(countriesProvider),
      hideWhenForbidden: true,
      loading: const SizedBox.shrink(),
      data: (countries) => countries.length < 2
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Todos os países'),
                    selected: selected == null,
                    onSelected: (_) => ref.read(mapCountryFilterProvider.notifier).set(null),
                  ),
                  for (final country in countries) ...[
                    const SizedBox(width: AppTokens.space8),
                    ChoiceChip(
                      label: Text(country.name),
                      selected: selected == country.id,
                      onSelected: (isOn) => ref
                          .read(mapCountryFilterProvider.notifier)
                          .set(isOn ? country.id : null),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _Map extends StatelessWidget {
  const _Map({
    required this.controller,
    required this.points,
    required this.selected,
    required this.onSelect,
  });

  final MapController controller;
  final List<ChurchMapPoint> points;
  final ChurchMapPoint? selected;
  final void Function(ChurchMapPoint) onSelect;

  @override
  Widget build(BuildContext context) {
    final bounds = LatLngBounds.fromPoints(points.map((p) => p.position).toList());

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radius16),
      child: Stack(
        children: [
          FlutterMap(
            mapController: controller,
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(48),
              ),
              minZoom: 1,
              maxZoom: 16,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'dev.pastoral.app',
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  for (final point in points)
                    Marker(
                      point: point.position,
                      width: 44,
                      height: 44,
                      child: _Pin(
                        point: point,
                        isSelected: selected?.id == point.id,
                        onTap: () => onSelect(point),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const Positioned(
            right: 6,
            bottom: 4,
            child: _Attribution(),
          ),
          if (selected != null)
            Positioned(
              left: AppTokens.space12,
              right: AppTokens.space12,
              bottom: AppTokens.space12,
              child: _SelectedCard(point: selected!),
            ),
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.point, required this.isSelected, required this.onTap});

  final ChurchMapPoint point;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${point.name}, ${point.pastorsText}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '${point.pastorCount}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({required this.point});

  final ChurchMapPoint point;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.softPrimary,
              borderRadius: BorderRadius.circular(AppTokens.radius12),
            ),
            child: const Icon(Icons.church_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${point.city} · ${point.pastorsText}',
                  style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go('/churches/${point.id}'),
            child: const Text('Abrir'),
          ),
        ],
      ),
    );
  }
}

/// Atribuição exigida pelo uso dos tiles do OpenStreetMap.
class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: Colors.white70,
      child: const Text(
        '© OpenStreetMap contributors',
        style: TextStyle(fontSize: 10, color: AppColors.ink),
      ),
    );
  }
}
