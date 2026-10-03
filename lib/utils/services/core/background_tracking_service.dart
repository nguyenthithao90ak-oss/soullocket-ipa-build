import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:screen_state/screen_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../../sleep_tracking_math.dart';
import '../../sleep_presence_state.dart';
import '../sleep_tracking_service.dart';
import '../widget_service.dart';
import '../l10n_service.dart';

const sleepTaskIdentifier='com.soullocket.app.sleep.refresh';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task,inputData) async {
    try {
      DartPluginRegistrant.ensureInitialized();
      await Firebase.initializeApp();
      await SleepTrackingService.refreshHealth();
      return true;
    } catch(error) {
      debugPrint('[SleepTracker] Health refresh failed: $error');
      return false;
    }
  });
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp();
  final prefs=await SharedPreferences.getInstance(); await prefs.reload();
  final uid=FirebaseAuth.instance.currentUser?.uid;
  final house=prefs.getString('il_house_id') ?? prefs.getString('il_rel_house_id');
  final role=sleepRole(prefs.getString('il_role') ?? prefs.getString('il_rel_role'));
  if(uid==null||house==null||house.isEmpty||role==null||prefs.getBool('is_sleep_tracking_enabled')!=true||prefs.getString('sleep_tracking_scope')!=sleepConsentScope(uid,house,role)) { await service.stopSelf();return; }
  final ref=FirebaseDatabase.instance.ref('houses/$house/presence/$role');
  Timer? timer; StreamSubscription<ScreenStateEvent>? screenSub;
  StreamSubscription<Map<String,dynamic>?>? stopSub;
  Future<void> pending=Future.value(); bool stopped=false;
  Future<bool> current() async {
    await prefs.reload();
    return !stopped && FirebaseAuth.instance.currentUser?.uid==uid && prefs.getBool('is_sleep_tracking_enabled')==true && prefs.getString('sleep_tracking_scope')==sleepConsentScope(uid,house,role) &&
      (prefs.getString('il_house_id')??prefs.getString('il_rel_house_id'))==house &&
      sleepRole(prefs.getString('il_role')??prefs.getString('il_rel_role'))==role;
  }
  void enqueue(Future<void> Function() job) {
    pending=pending.then((_) async {if(await current()) await job();}).catchError((Object e){debugPrint('[SleepTracker] Screen estimate failed: $e');});
  }
  Future<void> sync() async { if(await current()) await WidgetService.syncSleepWidgetData(houseId:house); }
  Future<void> apply(Map<String,dynamic> Function(Map<String,dynamic>) change,{bool recordOnWake=false}) async {
    if(!await current()) return;
    await ref.get();
    if(!await current()) return;
    SleepRecord? ended;
    final result=await ref.runTransaction((raw) {
      ended=null;
      if(stopped || FirebaseAuth.instance.currentUser?.uid!=uid || raw is! Map) return Transaction.abort();
      final p=Map<String,dynamic>.from(raw);
      final next=automatedSleepPresence(p,change(p));
      if(next==null) return Transaction.abort();
      final now=DateTime.now().millisecondsSinceEpoch,start=sleepEpoch(p['sleep_start_time']);
      if(recordOnWake && p['sleep_source']=='screen_estimate' && p['sleep_mode']==true && start>0 && now>start && now-start<=50400000) ended=SleepRecord(start,now,now-start);
      return Transaction.success(next);
    },applyLocally:false);
    final completed=ended;
    if(result.committed && completed!=null && await current()) {
      await FirebaseDatabase.instance.ref('houses/'+house+'/sleep_history/'+role+'/estimate_'+completed.start.toString()).set(completed.toMap('screen_estimate'));
    }
    if(result.committed) await sync();
  }
  stopSub=service.on('stopService').listen((_) async {
    stopped=true; timer?.cancel(); await screenSub?.cancel();await stopSub?.cancel();await service.stopSelf();
  });
  timer=Timer.periodic(const Duration(minutes:5),(_) => enqueue(() async {
    await apply((p) {
      final state=androidSleepEstimate(p,DateTime.now());
      return {'sleep_mode':state=='sleeping'||state=='noon_nap','sleep_status':state,
        'sleep_start_time':state=='sleeping'||state=='noon_nap'?sleepEpoch(p['last_screen_off']):0,
        'sleep_source':'screen_estimate','sleep_updated_at':ServerValue.timestamp};
    });
  }));
  screenSub=Screen().screenStateStream.listen((event)=>enqueue(() async {
    final now=DateTime.now().millisecondsSinceEpoch;
    if(event==ScreenStateEvent.screenOff) {
      await apply((p)=>{'last_screen_off':now,'sleep_mode':false,'sleep_status':'unknown','sleep_source':'screen_estimate',
        'sleep_start_time':0,'sleep_updated_at':ServerValue.timestamp});
    } else if(event==ScreenStateEvent.screenOn) {
      // Mở máy là hoạt động đã xác nhận, không giữ cờ ngủ sau đó.
      await apply((p)=>{'last_screen_on':now,'last_active':now,'last_wake_time':now,
        'sleep_mode':false,'sleep_status':'awake','sleep_start_time':0,
        'sleep_source':'screen_estimate','sleep_updated_at':ServerValue.timestamp},recordOnWake:true);
    }
  }));
}

class BackgroundTrackingService {
  static Future<void> initialize() async {
    final enabled=await SleepTrackingService.isEnabled();
    if(Platform.isIOS) {
      if(enabled) { await _schedule(); await SleepTrackingService.refreshHealth(); }
      return;
    }
    if(!Platform.isAndroid) return;
    const channel=AndroidNotificationChannel('background_tracking_channel','SoulLocket',importance:Importance.low);
    await FlutterLocalNotificationsPlugin().resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
    await FlutterBackgroundService().configure(androidConfiguration:AndroidConfiguration(
      onStart:onStart,autoStart:enabled,isForegroundMode:true,notificationChannelId:'background_tracking_channel',
      initialNotificationTitle:'SoulLocket',initialNotificationContent:L10nService().translate('sleep_source_estimate'),foregroundServiceNotificationId:888),
      iosConfiguration:IosConfiguration(autoStart:false));
    if(!enabled) FlutterBackgroundService().invoke('stopService');
  }
  static Future<void> _schedule() async {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(sleepTaskIdentifier,sleepTaskIdentifier,frequency:const Duration(minutes:30));
  }
  static Future<void> start({required String houseId,String? uid}) async {
    final prefs=await SharedPreferences.getInstance();
    // UI hỏi quyền trước; không lưu trạng thái bật nếu khởi tạo thất bại.
    if(Platform.isIOS && !await SleepTrackingService.requestHealthAccess()) throw StateError('sleep_authorization_failed');
    try {
      await SleepTrackingService.setEnabled(true,expectedHouseId:houseId,expectedUid:uid);
      if(Platform.isIOS) { await _schedule();await SleepTrackingService.refreshHealth(); }
      else if(Platform.isAndroid) { await initialize();final ok=await FlutterBackgroundService().isRunning() || await FlutterBackgroundService().startService();if(!ok) throw StateError('sleep_start_failed'); }
    } catch(e) {
      await prefs.setBool('is_sleep_tracking_enabled',false);
      try { await SleepTrackingService.setEnabled(false,expectedHouseId:houseId,expectedUid:uid); } catch(_) { /* Giữ lỗi khởi tạo gốc. */ }
      rethrow;
    }
  }
  static Future<void> stop() async {
    final prefs=await SharedPreferences.getInstance();await prefs.setBool('is_sleep_tracking_enabled',false);
    try {
      if(Platform.isAndroid) FlutterBackgroundService().invoke('stopService');
      else if(Platform.isIOS) await Workmanager().cancelByUniqueName(sleepTaskIdentifier);
    } finally { await SleepTrackingService.disable(); }
  }
}
