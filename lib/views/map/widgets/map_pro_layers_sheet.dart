import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../utils/services/l10n_service.dart';
import '../map_pro_access.dart';

class MapProLayersSheet extends StatefulWidget {
  const MapProLayersSheet({
    super.key,
    required this.access,
    required this.options,
  });

  final ValueListenable<bool> access;
  final MapProViewOptions options;

  @override
  State<MapProLayersSheet> createState() => _MapProLayersSheetState();
}

class _MapProLayersSheetState extends State<MapProLayersSheet> {
  late MapProViewOptions _options = widget.options;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: widget.access,
    builder: (context, allowed, _) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(context.tr('map_pro_layers'),
                    style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  tooltip: context.tr('p9_map_search_back'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!allowed)
              Text(context.tr('map_pro_required'))
            else ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final layer in MapProBaseLayer.values)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: ChoiceChip(
                        key: ValueKey('map_pro_layer_${layer.name}'),
                        avatar: Icon(layer == MapProBaseLayer.satellite
                            ? Icons.satellite_alt_rounded : Icons.map_outlined),
                        label: Text(context.tr(layer == MapProBaseLayer.satellite
                            ? 'map_pro_satellite' : 'map_pro_standard')),
                        selected: _options.baseLayer == layer,
                        onSelected: (_) => setState(() {
                          _options = _options.copyWith(baseLayer: layer);
                        }),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                key: const ValueKey('map_pro_3d_switch'),
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('map_pro_3d')),
                subtitle: Text(context.tr('map_pro_3d_hint')),
                value: _options.threeDimensional,
                onChanged: (value) => setState(() {
                  _options = _options.copyWith(threeDimensional: value);
                }),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const ValueKey('map_pro_apply_layers'),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () {
                  if (widget.access.value) Navigator.pop(context, _options);
                },
                icon: const Icon(Icons.check_rounded),
                label: Text(context.tr('map_pro_apply')),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
