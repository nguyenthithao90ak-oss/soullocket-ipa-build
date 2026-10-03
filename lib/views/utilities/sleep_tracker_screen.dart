import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/sleep_history_query.dart';
import '../../utils/services/house_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/core/background_tracking_service.dart';
import '../../utils/services/l10n_service.dart';
import '../../utils/services/sleep_tracking_service.dart';
import '../../utils/services/widget_service.dart';
import '../../utils/sleep_tracking_math.dart';
import 'widgets/sleep_status_card.dart';

class SleepTrackerScreen extends StatefulWidget {
  const SleepTrackerScreen({super.key,required this.houseId,required this.myName});
  final String houseId,myName;
  @override State<SleepTrackerScreen> createState()=>_SleepTrackerScreenState();
}
class _SleepTrackerScreenState extends State<SleepTrackerScreen> with WidgetsBindingObserver {
  final _subscriptions=<StreamSubscription<DatabaseEvent>>[];
  final _presence=<String,dynamic>{};
  final _history=<String,List<Map<String,dynamic>>>{};
  StreamSubscription<Map<String,List<Map<String,dynamic>>>>? _historySub;
  StreamSubscription<User?>? _authSub; int _generation=0; String? _uid;
  final _names=<String,String>{};
  String _role='user1';bool _enabled=false,_busy=false;Timer? _clock;
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);unawaited(_init());
    _authSub=FirebaseAuth.instance.authStateChanges().listen((u){if(mounted&&u?.uid!=_uid)unawaited(_init());});
    _clock=Timer.periodic(const Duration(minutes:1),(_){if(mounted)setState((){});});}
  Future<void> _init() async {
    final generation=++_generation,houseId=widget.houseId;
    final uid=FirebaseAuth.instance.currentUser?.uid;_uid=uid;
    bool current()=>mounted&&generation==_generation&&widget.houseId==houseId&&FirebaseAuth.instance.currentUser?.uid==uid;
    final previous=[..._subscriptions];_subscriptions.clear();
    await Future.wait(previous.map((s)=>s.cancel()));await _historySub?.cancel();_historySub=null;
    if(!current())return;setState((){_presence.clear();_history.clear();_names.clear();});
    if(uid==null||await HouseService().getCurrentHouseId()!=houseId||!current())return;
    final prefs=await SharedPreferences.getInstance();if(!current())return;
    final enabled=await SleepTrackingService.isEnabled();if(!current())return;
    setState((){_role=sleepRole(prefs.getString('il_role')??prefs.getString('il_rel_role'))??'user1';_enabled=enabled;});
    final db=FirebaseDatabase.instance.ref('houses/'+houseId);
    for(final role in ['user1','user2']) {
      final nameKey=role=='user1'?'nameU1':'nameU2';
      _subscriptions.add(db.child('settings/'+nameKey).onValue.listen((event){if(!current())return;setState(()=>_names[role]=event.snapshot.value?.toString()??'');},onError:(Object e){if(current())_error(e);}));
      _subscriptions.add(db.child('presence/'+role).onValue.listen((event){if(!current())return;final raw=event.snapshot.value;setState(()=>_presence[role]=raw is Map?Map<String,dynamic>.from(raw):<String,dynamic>{});unawaited(WidgetService.syncSleepWidgetData(houseId:widget.houseId).catchError((Object e){if(current())_error(e);}));},onError:(Object e){if(current())_error(e);}));
    }
    _historySub=watchSleepHistory(root:FirebaseDatabase.instance.ref(),houseId:houseId,uid:uid,role:_role,now:DateTime.now(),isCurrentScope:current).listen((history){if(!current())return;setState((){_history.clear();_history.addAll(history);});},onError:(Object e){if(current())_error(e);});
    if(_enabled&&!kIsWeb&&Platform.isIOS) await _refresh();
  }
  void _error(Object error){if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(context.tr('sleep_tracking_failed'))));}
  Future<void> _refresh() async {
    if(_busy)return;setState(()=>_busy=true);
    try{if(!kIsWeb&&Platform.isIOS&&_enabled)await SleepTrackingService.refreshHealth();await WidgetService.syncSleepWidgetData(houseId:widget.houseId);}catch(e){_error(e);}finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _toggle(bool value) async {
    if(_busy)return;
    if(value) {
      final approved=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(c.tr('p3_sleep_title')),content:Text(c.tr('sleep_tracking_consent')),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:Text(c.tr('cancel'))),FilledButton(onPressed:()=>Navigator.pop(c,true),child:Text(c.tr('confirm')))]));
      if(approved!=true||!mounted)return;
    }
    setState(()=>_busy=true);
    try{if(value){await BackgroundTrackingService.start(houseId:widget.houseId,uid:_uid);}else{await BackgroundTrackingService.stop();}if(mounted)setState(()=>_enabled=value);}catch(e){_error(e);}finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _manual(bool sleeping) async {
    if(_busy)return;setState(()=>_busy=true);
    try{await SleepTrackingService.setManualSleep(sleeping,houseId:widget.houseId,expectedUid:_uid);}catch(e){_error(e);}finally{if(mounted)setState(()=>_busy=false);}
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed)unawaited(_refresh());}
  @override void didUpdateWidget(covariant SleepTrackerScreen old){super.didUpdateWidget(old);if(old.houseId!=widget.houseId)unawaited(_init());}
  @override void dispose(){_generation++;unawaited(_authSub?.cancel());unawaited(_historySub?.cancel());WidgetsBinding.instance.removeObserver(this);_clock?.cancel();for(final s in _subscriptions){unawaited(s.cancel());}super.dispose();}
  String _name(String role)=>_names[role]?.trim().isNotEmpty==true?_names[role]!:context.tr(role=='user1'?'p3_sleep_default_me':'p3_sleep_default_partner');
  @override Widget build(BuildContext context) {
    final now=DateTime.now();final own=sleepRoleData(_presence,_role);final manualActive=own['sleep_source']=='manual'&&own['sleep_mode']==true;
    final ios=!kIsWeb&&Platform.isIOS;
    return Scaffold(backgroundColor:const Color(0xFFF6F4FA),appBar:AppBar(title:Text(context.tr('p3_sleep_title')),backgroundColor:const Color(0xFFF6F4FA),actions:[IconButton(onPressed:_busy?null:_refresh,icon:const Icon(Icons.refresh_rounded))]),
      body:SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.all(16),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:600),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
          SwitchListTile.adaptive(contentPadding:EdgeInsets.zero,title:Text(context.tr('p3_sleep_title')),value:_enabled,onChanged:_busy||kIsWeb?null:_toggle),
          Text(context.tr(ios?'sleep_tracking_info_ios':'sleep_tracking_info_android'),style:const TextStyle(color:Color(0xFF746B88),height:1.5)),
          if(_busy)const Padding(padding:EdgeInsets.only(top:12),child:LinearProgressIndicator()),
          if(_enabled)Padding(padding:const EdgeInsets.only(top:14),child:SizedBox(width:double.infinity,height:52,child:FilledButton.icon(onPressed:_busy?null:()=>_manual(!manualActive),icon:Icon(manualActive?Icons.wb_sunny_rounded:Icons.bedtime_rounded),label:Text(context.tr(manualActive?'sleep_manual_stop':'sleep_manual_start'))))),
        ]))),
        const SizedBox(height:14),
        for(final role in ['user1','user2'])...[
          SleepStatusCard(name:_name(role),person:SleepPersonSnapshot.fromPresence(sleepRoleData(_presence,role),now.millisecondsSinceEpoch),avatarKey:role=='user1'?'warm':'cream',now:now),
          const SizedBox(height:14),
          _week(role,now),const SizedBox(height:20),
        ],
      ]))))));
  }
  Widget _week(String role,DateTime now) {
    final p=sleepRoleData(_presence,role);
    final canonical=_history[role];
    final records=canonical?.isNotEmpty==true?canonical!:_history[role=='user1'?'husband':'wife']??(role==_role?_history[_uid]:null)??[];
    final importId=sleepEpoch(p['sleep_import_id']);
    final selected=p['sleep_source']=='healthkit'?records.where((r)=>r['source']=='healthkit'&&(importId==0||sleepEpoch(r['import_id'])==importId)):records;
    final week=sleepWeek(selected,now);
    return Card(color:Colors.white,child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(L10nService().format('p3_sleep_week_title',{'name':_name(role)}),style:SLTheme.quicksand(fontSize:16,fontWeight:FontWeight.w800)),const SizedBox(height:20),
      Row(crossAxisAlignment:CrossAxisAlignment.end,children:[for(var i=6;i>=0;i--)Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:3),child:Column(children:[
        FittedBox(child:Text(week[i]!>0?week[i]!.toStringAsFixed(1):'—',style:const TextStyle(fontSize:12))),const SizedBox(height:8),
        Container(height:90,width:18,alignment:Alignment.bottomCenter,decoration:BoxDecoration(color:const Color(0xFFF2EEF8),borderRadius:BorderRadius.circular(12)),child:Container(height:(week[i]!/12*90).clamp(0,90),decoration:BoxDecoration(color:const Color(0xFF9E8ACB),borderRadius:BorderRadius.circular(12)))),const SizedBox(height:8),
        FittedBox(child:Text(DateFormat('E',L10nService().localeCode).format(DateTime(now.year,now.month,now.day-i)),style:const TextStyle(fontSize:11))),
      ])))]),
    ])));
  }
}
