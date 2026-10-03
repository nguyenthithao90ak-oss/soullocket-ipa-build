import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../sleep_tracking_math.dart';
import '../sleep_presence_state.dart';
import 'widget_service.dart';

class _SleepScope {
  const _SleepScope(this.uid,this.house,this.role);
  final String uid,house,role;
  String get token=>sleepConsentScope(uid,house,role);
  static Future<_SleepScope?> read() async {
    final prefs=await SharedPreferences.getInstance(); await prefs.reload();
    final uid=FirebaseAuth.instance.currentUser?.uid;
    final house=prefs.getString('il_house_id') ?? prefs.getString('il_rel_house_id');
    final role=sleepRole(prefs.getString('il_role') ?? prefs.getString('il_rel_role'));
    final cachedUid=prefs.getString('il_auth_uid');
    if(uid==null || house==null || house.isEmpty || RegExp(r'[.#$\[\]/\\]').hasMatch(house) || role==null || (cachedUid!=null && cachedUid!=uid)) return null;
    return _SleepScope(uid,house,role);
  }
  Future<bool> current() async {
    final other=await read(); return other!=null&&other.uid==uid&&other.house==house&&other.role==role;
  }
}

/// HealthKit trả bản ghi lịch sử, không phải cảm biến trạng thái ngủ realtime.
/// Chỉ xuất nguồn/timestamp thật; thao tác manual phải do chính người dùng bấm.
class SleepTrackingService {
  static const healthTypes=[HealthDataType.SLEEP_ASLEEP,HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,HealthDataType.SLEEP_REM,HealthDataType.SLEEP_AWAKE];
  static Future<void>? _refresh;
  static Future<bool> isEnabled() async {
    final scope=await _SleepScope.read();
    if(scope==null) return false;
    final prefs=await SharedPreferences.getInstance();
    return prefs.getBool('is_sleep_tracking_enabled')==true && prefs.getString('sleep_tracking_scope')==scope.token;
  }
  static Future<bool> requestHealthAccess() async {
    if(!Platform.isIOS) return true;
    final health=Health(); await health.configure();
    return health.requestAuthorization(healthTypes,
      permissions: List.filled(healthTypes.length,HealthDataAccess.READ));
  }
  static Future<void> refreshHealth() {
    return _refresh ??= _readHealth().whenComplete(()=>_refresh=null);
  }
  static Future<void> _readHealth() async {
    if(!Platform.isIOS) return;
    final scope=await _SleepScope.read(); if(scope==null) return;
    final prefs=await SharedPreferences.getInstance();
    if(prefs.getBool('is_sleep_tracking_enabled')!=true || prefs.getString('sleep_tracking_scope')!=scope.token) return;
    final now=DateTime.now(); final health=Health(); await health.configure();
    // Không mở hộp thoại xin quyền từ background hoặc mỗi lần refresh.
    final points=await health.getHealthDataFromTypes(startTime:now.subtract(const Duration(days:8)),endTime:now,types:healthTypes);
    final records=recordedSleep(points.map((p)=>SleepSample(p.dateFrom.millisecondsSinceEpoch,p.dateTo.millisecondsSinceEpoch,p.type.name)),now:now.millisecondsSinceEpoch);
    if(!await scope.current()) return;
    await prefs.reload(); if(prefs.getBool('is_sleep_tracking_enabled')!=true || prefs.getString('sleep_tracking_scope')!=scope.token) return;
    final db=FirebaseDatabase.instance.ref('houses/'+scope.house);
    await db.child('presence/'+scope.role).get();
    if(!await scope.current()) return;
    final updates=<String,dynamic>{};
    final importId=now.millisecondsSinceEpoch;
    for(final r in records) { updates['sleep_history/'+scope.role+'/health_'+r.start.toString()]={...r.toMap('healthkit'),'import_id':importId}; }
    // Không ghi đè phiên người dùng đang chủ động ghi nhận.
    if(await scope.current()) {
      final last=records.isEmpty?null:records.last;
      await prefs.reload();
      if(prefs.getBool('is_sleep_tracking_enabled')!=true || prefs.getString('sleep_tracking_scope')!=scope.token) return;
      if(updates.isNotEmpty) await db.update(updates);
      await db.child('presence/'+scope.role).runTransaction((value) {
        if(FirebaseAuth.instance.currentUser?.uid!=scope.uid || value is! Map) return Transaction.abort();
        final next=automatedSleepPresence(Map<String,dynamic>.from(value),{
          'sleep_mode':false,'sleep_status':'unknown','sleep_source':'healthkit',
          'sleep_start_time':0,'sleep_updated_at':ServerValue.timestamp,
          'sleep_record_start':last?.start??0,'sleep_record_end':last?.end??0,
          'sleep_record_duration':last?.asleepMs??0,'sleep_import_id':importId});
        return next==null?Transaction.abort():Transaction.success(next);
      },applyLocally:false);
    }

    if(await scope.current()) await WidgetService.syncSleepWidgetData(houseId:scope.house);
  }
  static Future<void> setManualSleep(bool sleeping,{required String houseId,String? expectedUid}) async {
    final scope=await _SleepScope.read(); if(scope==null || scope.house!=houseId || (expectedUid!=null && scope.uid!=expectedUid)) throw StateError('sleep_scope_missing');
    final prefs=await SharedPreferences.getInstance();
    if(prefs.getBool('is_sleep_tracking_enabled')!=true || prefs.getString('sleep_tracking_scope')!=scope.token) throw StateError('sleep_tracking_disabled');
    final db=FirebaseDatabase.instance.ref('houses/'+scope.house);
    final ref=db.child('presence/'+scope.role);
    await ref.get();
    if(!await scope.current()) throw StateError('sleep_scope_changed');
    final now=DateTime.now().millisecondsSinceEpoch;
    SleepRecord? ended;
    final result=await ref.runTransaction((value) {
      ended=null;
      if(FirebaseAuth.instance.currentUser?.uid!=scope.uid || value is! Map) return Transaction.abort();
      final p=Map<String,dynamic>.from(value);
      final next=manualSleepPresence(p,sleeping,now,ServerValue.timestamp);
      if(next==null) return Transaction.abort();
      final start=sleepEpoch(p['sleep_start_time']);
      if(!sleeping && p['sleep_source']=='manual' && p['sleep_mode']==true && start>0 && now>start && now-start<=86400000) {
        ended=SleepRecord(start,now,now-start);
      }
      return Transaction.success(next);
    },applyLocally:false);
    if(!result.committed) throw StateError('sleep_tracking_disabled');
    final completed=ended;
    if(completed!=null && await scope.current()) {
      await db.child('sleep_history/'+scope.role+'/manual_'+completed.start.toString()).set(completed.toMap('manual'));
    }
    if(await scope.current()) await WidgetService.syncSleepWidgetData(houseId:scope.house);
  }
  static Future<void> setEnabled(bool enabled,{String? expectedHouseId,String? expectedUid}) async {
    final scope=await _SleepScope.read();
    if(scope==null || (expectedHouseId!=null && scope.house!=expectedHouseId) || (expectedUid!=null && scope.uid!=expectedUid)) {if(enabled) throw StateError('sleep_scope_missing');return;}
    final ref=FirebaseDatabase.instance.ref('houses/'+scope.house+'/presence/'+scope.role);
    await ref.get();
    if(!await scope.current()) throw StateError('sleep_scope_changed');
    final result=await ref.runTransaction((value) {
      if(FirebaseAuth.instance.currentUser?.uid!=scope.uid) return Transaction.abort();
      final p=value is Map?Map<String,dynamic>.from(value):<String,dynamic>{};
      return Transaction.success(enabledSleepPresence(p,enabled,ServerValue.timestamp));
    },applyLocally:false);
    if(!result.committed || !await scope.current()) throw StateError('sleep_scope_changed');
    final prefs=await SharedPreferences.getInstance();
    if(enabled) {await prefs.setString('sleep_tracking_scope',scope.token);}
    else {await prefs.remove('sleep_tracking_scope');}
    await prefs.setBool('is_sleep_tracking_enabled',enabled);
    if(await scope.current()) await WidgetService.syncSleepWidgetData(houseId:scope.house);
  }
  static Future<void> disable() => setEnabled(false);
}
