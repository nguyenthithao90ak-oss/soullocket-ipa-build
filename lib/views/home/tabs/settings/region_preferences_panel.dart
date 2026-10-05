import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'package:flutter/material.dart';
import '../../../../core/sl_theme.dart';
import '../../../../widgets/sl_settings_kit.dart';
import '../../../../core/constants/market_catalog.dart';
import '../../../../utils/services/l10n_service.dart';
import '../../../../utils/services/market_service.dart';
import '../../../../utils/services/calendar_reminder_service.dart';
import '../../../../utils/services/notification_service.dart';

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
                    style: slSettingsInputTextStyle(),
                    decoration: slSettingsInputDecoration(
                      hint: context.tr('region_search'),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
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
                          selectedColor: SLSettingsColors.accentStrong,
                          selectedTileColor: SLSettingsColors.accentSoft,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          title: Text(
                            context.tr(choice.key),
                            style: SLSettingsText.body(
                              active
                                  ? SLSettingsColors.accentStrong
                                  : SLSettingsColors.ink,
                            ),
                          ),
                          trailing: active
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: SLSettingsColors.accent,
                                )
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
    final syncState = _service.syncState;
    return Form(
      key: _formKey,
      child: SLSettingsCard(
        margin: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SLSettingsBlockHeading(
              icon: Icons.public_rounded,
              iconColor: SLSettingsColors.sky,
              title: context.tr('region_title'),
              subtitle: context.tr('region_hint'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Flexible(
                  child: SLSettingsPill(
                    label: context.tr(switch (syncState) {
                      MarketSyncState.localOnly => 'region_sync_local',
                      MarketSyncState.syncing => 'region_sync_working',
                      MarketSyncState.synced => 'region_sync_done',
                      MarketSyncState.pending => 'region_sync_pending',
                    }),
                    icon: switch (syncState) {
                      MarketSyncState.synced => Icons.cloud_done_outlined,
                      MarketSyncState.syncing => Icons.cloud_sync_outlined,
                      MarketSyncState.pending => Icons.cloud_off_outlined,
                      MarketSyncState.localOnly => Icons.phone_android_rounded,
                    },
                    tone: switch (syncState) {
                      MarketSyncState.synced => SLSettingsTone.success,
                      MarketSyncState.syncing => SLSettingsTone.info,
                      MarketSyncState.pending => SLSettingsTone.warning,
                      MarketSyncState.localOnly => SLSettingsTone.neutral,
                    },
                  ),
                ),
                if (syncState == MarketSyncState.pending)
                  IconButton(
                    onPressed: _service.retryCloudSync,
                    tooltip: context.tr('region_sync_retry'),
                    color: SLSettingsColors.inkSecondary,
                    icon: const Icon(Icons.sync_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SLSettingsSelectField(
              icon: Icons.flag_outlined,
              label: context.tr('region_market'),
              value: context.tr(
                _market == null ? 'region_device' : 'market_$_market',
              ),
              onTap: _saving ? null : _chooseMarket,
            ),
            const SizedBox(height: 8),
            SLSettingsSwitchRow(
              padding: const EdgeInsets.symmetric(vertical: 6),
              title: context.tr('region_defaults'),
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
                style: SLSettingsText.title(SLSettingsColors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('region_packs_hint'),
                style: SLSettingsText.caption(SLSettingsColors.inkSecondary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final code in MarketCatalog.holidayPackCodes)
                    FilterChip(
                      selectedColor: SLSettingsColors.accentSoft,
                      checkmarkColor: SLSettingsColors.accentStrong,
                      backgroundColor: SLSettingsColors.surfaceMuted,
                      side: const BorderSide(color: SLSettingsColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      labelStyle: SLTheme.quicksand(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: SLSettingsColors.ink,
                      ),
                      label: Text(
                        context.tr(
                          code == 'ALL'
                              ? 'region_shared'
                              : code == 'ES'
                              ? 'region_pack_catalonia'
                              : 'market_$code',
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
            const Divider(height: 28, color: SLSettingsColors.divider),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: false,
              shape: const Border(),
              collapsedShape: const Border(),
              iconColor: SLSettingsColors.inkSecondary,
              collapsedIconColor: SLSettingsColors.inkTertiary,
              title: Text(
                context.tr('region_display_title'),
                style: SLSettingsText.title(SLSettingsColors.ink),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  context.tr('region_display_hint'),
                  style: SLSettingsText.caption(SLSettingsColors.inkSecondary),
                ),
              ),
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
                    child: Text(
                      context.tr('region_secondary_hint'),
                      style: SLSettingsText.caption(
                        SLSettingsColors.inkSecondary,
                      ),
                    ),
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
                        ? null
                        : context.tr('region_timezone_invalid');
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
                SLSettingsSwitchRow(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  title: context.tr('region_holiday_reminders'),
                  subtitle: context.tr('region_holiday_reminders_hint'),
                  value: _holidayRemindersEnabled,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _dirty = true;
                          _holidayRemindersEnabled = value;
                        }),
                ),
                if (_holidayRemindersEnabled)
                  ListenableBuilder(
                    listenable: CalendarReminderService.instance,
                    builder: (context, _) {
                      final status = CalendarReminderService.supported
                          ? CalendarReminderService.instance.status
                          : CalendarReminderStatus.unsupported;
                      final key = switch (status) {
                        CalendarReminderStatus.permissionDenied =>
                          'event_reminder_permission',
                        CalendarReminderStatus.disabled =>
                          'event_reminder_disabled',
                        CalendarReminderStatus.unsupported =>
                          'event_reminder_unsupported',
                        CalendarReminderStatus.limited =>
                          'event_reminder_limited',
                        CalendarReminderStatus.failed =>
                          'event_reminder_failed',
                        _ => 'event_reminder_limited',
                      };
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SLSettingsNotice(
                            tone: SLSettingsTone.info,
                            message: context.tr(key),
                          ),
                          if (status == CalendarReminderStatus.permissionDenied)
                            TextButton(
                              onPressed: _saving
                                  ? null
                                  : () async {
                                      await NotificationService()
                                          .requestPermissionAndInit();
                                      await CalendarReminderService.instance
                                          .refresh();
                                    },
                              child: Text(
                                context.tr('event_reminder_settings'),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SLSettingsButton(
              onPressed: _saving ? null : _save,
              loading: _saving,
              icon: Icons.check_rounded,
              label: context.tr('region_save'),
            ),
          ],
        ),
      ),
    );
  }
}
