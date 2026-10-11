import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/models/single_match_models.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

class SingleMatchSettingsScreen extends StatefulWidget {
  final String houseId;
  final DatabaseReference? databaseRef;

  const SingleMatchSettingsScreen({
    super.key,
    required this.houseId,
    this.databaseRef,
  });

  @override
  State<SingleMatchSettingsScreen> createState() =>
      _SingleMatchSettingsScreenState();
}

class _SingleMatchSettingsScreenState extends State<SingleMatchSettingsScreen> {
  late final DatabaseReference _dbRef =
      widget.databaseRef ?? FirebaseDatabase.instance.ref();
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _readInProgress = false;

  bool _enabled = true;
  bool _allowAudioCalls = true;
  bool _allowVideoCalls = true;
  int _preferredAgeMin = 20;
  int _preferredAgeMax = 32;

  final TextEditingController _introController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (_readInProgress) return;
    _readInProgress = true;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
      });
    }
    try {
      final snap = await _dbRef
          .child('houses/${widget.houseId}/settings/singleMatch')
          .get()
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;

      if (snap.exists && snap.value is Map) {
        final prefs = SingleMatchPreferences.fromMap(snap.value as Map);
        setState(() {
          _enabled = prefs.enabled;
          _allowAudioCalls = prefs.allowAudioCalls;
          _allowVideoCalls = prefs.allowVideoCalls;
          _preferredAgeMin = prefs.preferredAgeMin;
          _preferredAgeMax = prefs.preferredAgeMax;
          _introController.text = prefs.intro;
        });
      }
    } catch (e) {
      debugPrint('[SingleMatchSettingsScreen] Load error: $e');
      if (mounted) {
        setState(() => _loadFailed = true);
      }
    } finally {
      _readInProgress = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_isLoading || _loadFailed) return;
    try {
      await _dbRef
          .child('houses/${widget.houseId}/settings/singleMatch')
          .update({
        'enabled': _enabled,
        'allowAudioCalls': _allowAudioCalls,
        'allowVideoCalls': _allowVideoCalls,
        'preferredAgeMin': _preferredAgeMin,
        'preferredAgeMax': _preferredAgeMax,
        'intro': _introController.text.trim(),
        'updatedAt': ServerValue.timestamp,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SLSnackBar(
          content: Text(L10nService().translate('core_success')),
          backgroundColor: SLColors.success,
        ),
      );
    } catch (e) {
      debugPrint('[SingleMatchSettingsScreen] Save error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: SLColors.bgMain,
        body: Center(child: CircularProgressIndicator(color: SLColors.primary)),
      );
    }

    if (_loadFailed) {
      return Scaffold(
        backgroundColor: SLColors.bgMain,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(SLSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 42),
                SLSpacing.h12,
                Text(
                  context.tr('settings_initial_load_error'),
                  textAlign: TextAlign.center,
                ),
                SLSpacing.h8,
                FilledButton.icon(
                  onPressed: _loadSettings,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.tr('p5_retry')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SLColors.bgMain,
      appBar: AppBar(
        backgroundColor: SLColors.bgMain,
        elevation: 0,
        centerTitle: true,
        title: Text(
          L10nService().translate('match_poolvmodeg_7fc33d'),
          style: SLTypography.titleMedium.copyWith(color: SLColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: SLColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: Text(
              context.tr('p3_save'),
              style: SLTypography.labelLarge.copyWith(color: SLColors.primary),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(SLSpacing.md),
        children: [
          _buildSectionHeader(
              L10nService().translate('match_poolvmodeg_7fc33d')),
          SwitchListTile(
            title: Text(L10nService().translate('match_xuthintron_5ab706'),
                style: SLTypography.bodyLarge),
            subtitle: Text(L10nService().translate('match_khitthscab_87be09'),
                style: SLTypography.bodySmall),
            value: _enabled,
            activeThumbColor: SLColors.primary,
            onChanged: (val) {
              setState(() => _enabled = val);
            },
          ),
          SLSpacing.h16,
          _buildSectionHeader(
              L10nService().translate('match_chophpgith_5a78ca')),
          SwitchListTile(
            title: Text(L10nService().translate('match_chophpgith_5a78ca'),
                style: SLTypography.bodyLarge),
            subtitle: Text(L10nService().translate('match_gimodenhdb_dfbb74'),
                style: SLTypography.bodySmall),
            value: _allowAudioCalls,
            activeThumbColor: SLColors.primary,
            onChanged: (val) {
              setState(() => _allowAudioCalls = val);
            },
          ),
          SwitchListTile(
            title: Text(L10nService().translate('match_chophpgivi_95d26f'),
                style: SLTypography.bodyLarge),
            subtitle: Text(L10nService().translate('match_chbtkhibnm_10d366'),
                style: SLTypography.bodySmall),
            value: _allowVideoCalls,
            activeThumbColor: SLColors.primary,
            onChanged: (val) {
              setState(() => _allowVideoCalls = val);
            },
          ),
          SLSpacing.h16,
          _buildSectionHeader(
              L10nService().translate('match_limukhimat_05cb9f')),
          TextField(
            controller: _introController,
            maxLines: 3,
            maxLength: 150,
            style: SLTypography.bodyLarge,
            decoration: InputDecoration(
              hintText: L10nService().translate('match_vdmnhthchn_afb6c9'),
              filled: true,
              fillColor: SLColors.bgCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SLRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SLSpacing.h32,
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SLSpacing.xs),
      child: Text(
        title,
        style: SLTypography.titleSmall.copyWith(color: SLColors.textSecondary),
      ),
    );
  }
}
