import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../services/house_settings_service.dart';
import '../../../../../utils/flexible_date_input.dart';
import '../../../../../utils/services/l10n_service.dart';

class SettingsIdentityDraft {
  const SettingsIdentityDraft({
    required this.houseId,
    required this.houseName,
    required this.previousHouseName,
    required this.nameU1,
    required this.nameU2,
    required this.startDate,
    required this.dobU1,
    required this.dobU2,
    required this.greetingQuote,
    required this.dayUnit,
    required this.relationshipMode,
    required this.homeShowHouseName,
    required this.homeShowTimer,
  });

  final String houseId;
  final String houseName;
  final String previousHouseName;
  final String nameU1;
  final String nameU2;
  final String startDate;
  final String dobU1;
  final String dobU2;
  final String greetingQuote;
  final String dayUnit;
  final String relationshipMode;
  final bool homeShowHouseName;
  final bool homeShowTimer;

  bool get isCouple => relationshipMode == 'couple';
  bool get showPartnerFields => isCouple;
  bool get isHouseNameChanged => houseName != previousHouseName;
  String get normalizedHouseName => houseName.trim();
  String get normalizedNameU1 => nameU1.trim();
  String get normalizedNameU2 => nameU2.trim();
  String get normalizedGreetingQuote => greetingQuote.trim();
  String get normalizedDayUnit =>
      dayUnit.trim().isEmpty ? L10nService().translate('home_ngyyu_722b21') : dayUnit.trim();
}

class SettingsIdentityController {
  const SettingsIdentityController();

  String? validateDraft(SettingsIdentityDraft draft) {
    if (draft.nameU1.trim().isEmpty) {
      return 'missing_name_u1';
    }
    if (draft.isCouple && draft.nameU2.trim().isEmpty) {
      return 'missing_name_u2';
    }
    return null;
  }

  Future<bool> canRenameHouse({
    required DatabaseReference dbRef,
    required SettingsIdentityDraft draft,
    Duration cooldown = const Duration(days: 7),
  }) async {
    if (!draft.isHouseNameChanged) {
      return true;
    }

    final snapshot = await dbRef
        .child('houses/${draft.houseId}/settings/lastUsernameUpdate')
        .get();
    if (!snapshot.exists || snapshot.value is! int) {
      return true;
    }

    final lastUpdate = snapshot.value as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastUpdate) >= cooldown.inMilliseconds;
  }

  Future<void> persistDraft({
    required DatabaseReference dbRef,
    required HouseSettingsService houseSettingsService,
    required SharedPreferences prefs,
    required SettingsIdentityDraft draft,
  }) async {
    await houseSettingsService.updateIdentityBundle(
      houseId: draft.houseId,
      houseName: draft.houseName,
      nameU1: draft.nameU1,
      nameU2: draft.nameU2,
      startDate: draft.startDate,
      dobU1: draft.dobU1,
      dobU2: draft.dobU2,
      dayUnit: draft.dayUnit,
      greetingQuote: draft.greetingQuote,
    );

    // Shared Info is allowed from Settings; skip the device trust gate here.

    await prefs.setString('il_greeting_quote_text', draft.greetingQuote);
    await prefs.setString('il_love_unit_text', draft.dayUnit);

    await dbRef.child('houses/${draft.houseId}/settings').update({
      'homeShowHouseName': draft.homeShowHouseName,
      'homeShowTimer': draft.homeShowTimer,
    });

    if (draft.isHouseNameChanged) {
      await dbRef
          .child('houses/${draft.houseId}/settings/lastUsernameUpdate')
          .set(ServerValue.timestamp);
    }
  }

  Future<String> updateStartDate({
    required HouseSettingsService houseSettingsService,
    required String houseId,
    required String rawDate,
  }) async {
    final normalizedDate = DateInputUtils.normalizeToIsoDate(
      rawDate,
      firstYear: 1900,
      lastYear: DateTime.now().year,
    );
    if (normalizedDate == null) {
      throw L10nService().translate('home_ngykhnghpl_b660fe');
    }

    await houseSettingsService.updateStartDate(houseId, normalizedDate);
    return normalizedDate;
  }
}
