import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
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
  int? _firstWeekday;
  bool? _use24HourFormat;
  String? _secondaryCalendar;
  String? _timeZoneId;
  final _timeZoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _loadRevision = 0;
  bool _holidayRemindersEnabled = false;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
    _service.addListener(_onServiceChanged);
  }

  void _load() {
    _loadRevision++;
    _dirty = false;
    _scope = _service.accountScope;
    final saved = _service.preferences;
    _market = saved.marketCode;
    _defaults = saved.holidayPacks == null;
    _firstWeekday = saved.firstWeekday;
    _use24HourFormat = saved.use24HourFormat;
    _secondaryCalendar = saved.secondaryCalendar;
    _timeZoneId = saved.timeZoneId;
    _timeZoneController.text = _timeZoneId ?? '';
    _holidayRemindersEnabled = saved.holidayRemindersEnabled;
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
    _timeZoneController.dispose();
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
          return SLAlertDialog(
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
              SLDialogAction(
                primary: true,

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
    if (_formKey.currentState?.validate() != true) return;
    final scope = _scope;
    setState(() => _saving = true);
    try {
      await _service.save(
        MarketPreferences(
          marketCode: _market,
          holidayPacks: _defaults ? null : _packs.toList(growable: false),
          firstWeekday: _firstWeekday,
          use24HourFormat: _use24HourFormat,
          secondaryCalendar: _secondaryCalendar,
          timeZoneId: _timeZoneId?.trim().isEmpty == true
              ? null
              : _timeZoneId?.trim(),
          holidayRemindersEnabled: _holidayRemindersEnabled,
        ),
      );
      if (!mounted || scope != _service.accountScope) return;
      setState(_load);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SLSnackBar(content: Text(context.tr('region_saved'))));
    } catch (_) {
      if (!mounted || scope != _service.accountScope) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(content: Text(context.tr('region_save_error'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Card(
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
            const Divider(height: 28),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: false,
              title: Text(context.tr('region_display_title')),
              subtitle: Text(context.tr('region_display_hint')),
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey('weekday-$_scope-$_loadRevision'),
                  isExpanded: true,
                  itemHeight: null,
                  initialValue: switch (_firstWeekday) {
                    DateTime.monday => 'monday',
                    DateTime.saturday => 'saturday',
                    DateTime.sunday => 'sunday',
                    _ => 'default',
                  },
                  decoration: InputDecoration(
                    labelText: context.tr('region_first_weekday'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'default',
                      child: Text(context.tr('region_default_value')),
                    ),
                    DropdownMenuItem(
                      value: 'monday',
                      child: Text(context.tr('region_monday')),
                    ),
                    DropdownMenuItem(
                      value: 'saturday',
                      child: Text(context.tr('region_saturday')),
                    ),
                    DropdownMenuItem(
                      value: 'sunday',
                      child: Text(context.tr('region_sunday')),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _dirty = true;
                          _firstWeekday = switch (value) {
                            'monday' => DateTime.monday,
                            'saturday' => DateTime.saturday,
                            'sunday' => DateTime.sunday,
                            _ => null,
                          };
                        }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('clock-$_scope-$_loadRevision'),
                  isExpanded: true,
                  itemHeight: null,
                  initialValue: _use24HourFormat == null
                      ? 'default'
                      : _use24HourFormat!
                      ? '24'
                      : '12',
                  decoration: InputDecoration(
                    labelText: context.tr('region_time_format'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'default',
                      child: Text(context.tr('region_default_value')),
                    ),
                    DropdownMenuItem(
                      value: '12',
                      child: Text(context.tr('region_time_12')),
                    ),
                    DropdownMenuItem(
                      value: '24',
                      child: Text(context.tr('region_time_24')),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _dirty = true;
                          _use24HourFormat = switch (value) {
                            '12' => false,
                            '24' => true,
                            _ => null,
                          };
                        }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('secondary-$_scope-$_loadRevision'),
                  isExpanded: true,
                  itemHeight: null,
                  initialValue: _secondaryCalendar ?? 'none',
                  decoration: InputDecoration(
                    labelText: context.tr('region_secondary_calendar'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'none',
                      child: Text(context.tr('region_none')),
                    ),
                    DropdownMenuItem(
                      value: 'buddhist',
                      child: Text(context.tr('region_buddhist')),
                    ),
                    DropdownMenuItem(
                      value: 'islamic-civil',
                      child: Text(context.tr('region_islamic_civil')),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _dirty = true;
                          _secondaryCalendar = value == 'none' ? null : value;
                        }),
                ),
                if (_secondaryCalendar == 'islamic-civil')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(context.tr('region_secondary_hint')),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _timeZoneController,
                  enabled: !_saving,
                  textDirection: TextDirection.ltr,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  validator: (value) {
                    final id = value?.trim() ?? '';
                    return id.isEmpty || MarketPreferences.isValidTimeZoneId(id)
                        ? null : context.tr('region_timezone_invalid');
                  },
                  decoration: InputDecoration(
                    labelText: context.tr('region_timezone'),
                    hintText: context.tr('region_timezone_hint'),
                  ),
                  onChanged: (value) {
                    _dirty = true;
                    _timeZoneId = value;
                  },
                ),
                const SizedBox(height: 4),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr('region_holiday_reminders')),
                  subtitle: Text(context.tr('region_holiday_reminders_hint')),
                  value: _holidayRemindersEnabled,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _dirty = true;
                          _holidayRemindersEnabled = value;
                        }),
                ),
              ],
            ),
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
      ),
    );
  }
}
