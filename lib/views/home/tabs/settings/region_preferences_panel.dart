import 'package:flutter/material.dart';
import '../../../../core/constants/market_catalog.dart';
import '../../../../utils/services/l10n_service.dart';
import '../../../../utils/services/market_service.dart';

class RegionPreferencesPanel extends StatefulWidget {
  const RegionPreferencesPanel({super.key, this.service});
  final MarketService? service;

  @override
  State<RegionPreferencesPanel> createState() => _RegionPreferencesPanelState();
}

class _RegionPreferencesPanelState extends State<RegionPreferencesPanel> {
  late final MarketService _service = widget.service ?? MarketService.instance;
  late String _scope;
  String? _market;
  bool _defaults = true;
  Set<String> _packs = {};
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
    _service.addListener(_onServiceChanged);
  }

  void _load() {
    _dirty = false;
    _scope = _service.accountScope;
    final saved = _service.preferences;
    _market = saved.marketCode;
    _defaults = saved.holidayPacks == null;
    _packs = _service
        .holidayPacks(languageCode: L10nService().locale.languageCode)
        .toSet();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    setState(() {
      if (_scope != _service.accountScope || (!_dirty && !_saving)) _load();
    });
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  Future<void> _chooseMarket() async {
    var query = '';
    final scope = _scope;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final choices =
              [
                    (code: 'device', key: 'region_device'),
                    for (final profile in MarketCatalog.profiles)
                      (code: profile.code, key: profile.nameKey),
                  ]
                  .where(
                    (choice) =>
                        choice.code.toLowerCase().contains(query) ||
                        context.tr(choice.key).toLowerCase().contains(query),
                  )
                  .toList();
          return AlertDialog(
            title: Text(context.tr('region_choose')),
            content: SizedBox(
              width: 420,
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: context.tr('region_search'),
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => setDialogState(
                      () => query = value.trim().toLowerCase(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: choices.length,
                      itemBuilder: (context, index) {
                        final choice = choices[index];
                        final active = choice.code == (_market ?? 'device');
                        return ListTile(
                          selected: active,
                          title: Text(context.tr(choice.key)),
                          trailing: active
                              ? const Icon(Icons.check_rounded)
                              : null,
                          onTap: () =>
                              Navigator.pop(dialogContext, choice.code),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted || selected == null || scope != _service.accountScope) return;
    setState(() {
      _market = selected == 'device' ? null : selected;
      _dirty = true;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_scope != _service.accountScope) {
      setState(_load);
      return;
    }
    final scope = _scope;
    setState(() => _saving = true);
    try {
      await _service.save(
        MarketPreferences(
          marketCode: _market,
          holidayPacks: _defaults ? null : _packs.toList(growable: false),
        ),
      );
      if (!mounted || scope != _service.accountScope) return;
      setState(_load);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('region_saved'))));
    } catch (_) {
      if (!mounted || scope != _service.accountScope) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('region_save_error'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('region_title'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(context.tr('region_hint')),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr(switch (_service.syncState) {
                      MarketSyncState.localOnly => 'region_sync_local',
                      MarketSyncState.syncing => 'region_sync_working',
                      MarketSyncState.synced => 'region_sync_done',
                      MarketSyncState.pending => 'region_sync_pending',
                    }),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (_service.syncState == MarketSyncState.pending)
                  IconButton(
                    onPressed: _service.retryCloudSync,
                    tooltip: context.tr('region_sync_retry'),
                    icon: const Icon(Icons.sync_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _saving ? null : _chooseMarket,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('region_market'),
                            style: theme.textTheme.labelMedium,
                          ),
                          Text(
                            context.tr(
                              _market == null
                                  ? 'region_device'
                                  : 'market_$_market',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.expand_more_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('region_defaults')),
              value: _defaults,
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _defaults = value;
                      _dirty = true;
                      if (!value) {
                        _packs = _service
                            .defaultHolidayPacks(
                              marketCode: _market,
                              languageCode: L10nService().locale.languageCode,
                            )
                            .toSet();
                      }
                    }),
            ),
            if (!_defaults) ...[
              Text(
                context.tr('region_custom'),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(context.tr('region_packs_hint')),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final code in MarketCatalog.holidayPackCodes)
                    FilterChip(
                      label: Text(
                        context.tr(
                          code == 'ALL' ? 'region_shared' : 'market_$code',
                        ),
                      ),
                      selected: _packs.contains(code),
                      onSelected: _saving
                          ? null
                          : (selected) => setState(() {
                              _dirty = true;
                              if (selected) {
                                _packs.add(code);
                              } else {
                                _packs.remove(code);
                              }
                            }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(context.tr('region_save')),
            ),
          ],
        ),
      ),
    );
  }
}
