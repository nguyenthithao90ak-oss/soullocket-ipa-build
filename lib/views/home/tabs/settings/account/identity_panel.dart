import '../controllers/settings_identity_controller.dart';

typedef SettingsPanelVoidCallback = void Function();
typedef SettingsPanelToggleChanged = void Function(bool value);

class SettingsIdentityPanelState {
  const SettingsIdentityPanelState({
    required this.isSingle,
    required this.draft,
    required this.loveDateDisplay,
    required this.dobU1Display,
    required this.dobU2Display,
    required this.homeShowHouseName,
    required this.homeShowTimer,
  });

  final bool isSingle;
  final SettingsIdentityDraft draft;
  final String loveDateDisplay;
  final String dobU1Display;
  final String dobU2Display;
  final bool homeShowHouseName;
  final bool homeShowTimer;

  bool get showPartnerFields => !isSingle;
  bool get hasLoveDate => loveDateDisplay.trim().isNotEmpty;
  bool get hasDobU1 => dobU1Display.trim().isNotEmpty;
  bool get hasDobU2 => dobU2Display.trim().isNotEmpty;
}

class SettingsIdentityPanelActions {
  const SettingsIdentityPanelActions({
    required this.onPickLoveDate,
    required this.onPickDobU1,
    required this.onPickDobU2,
    required this.onSave,
    required this.onToggleShowHouseName,
    required this.onToggleShowTimer,
  });

  final SettingsPanelVoidCallback onPickLoveDate;
  final SettingsPanelVoidCallback onPickDobU1;
  final SettingsPanelVoidCallback onPickDobU2;
  final SettingsPanelVoidCallback onSave;
  final SettingsPanelToggleChanged onToggleShowHouseName;
  final SettingsPanelToggleChanged onToggleShowTimer;
}
