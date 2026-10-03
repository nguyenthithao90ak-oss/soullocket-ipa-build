import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../../core/sl_theme.dart';
import '../../../utils/sleep_tracking_math.dart';
import '../../../utils/services/l10n_service.dart';

String sleepStateKey(String state)=>switch(state){
  'manual'=>'sleep_state_manual','estimated'=>'sleep_state_estimated',
  'recorded'=>'sleep_state_recorded','disabled'=>'sleep_state_disabled',
  'active'=>'p3_sleep_active','inactive'=>'p3_sleep_offline',_=>'sleep_state_unknown',
};
String sleepSourceLabel(String source)=>source=='healthkit'?'Apple Health':L10nService().translate(source=='manual'?'sleep_source_manual':source=='screen_estimate'?'sleep_source_estimate':'sleep_sync_hint');
String sleepDurationText(int duration)=>L10nService().format('sleep_duration',{'hours':duration~/3600000,'minutes':duration~/60000%60});
String sleepPersonDetail(SleepPersonSnapshot p,DateTime now) {
  if(p.state=='recorded')return sleepDurationText(p.duration)+' · '+DateFormat('dd/MM HH:mm').format(DateTime.fromMillisecondsSinceEpoch(p.end));
  if(p.state=='manual'||p.state=='estimated')return L10nService().format('p3_sleep_started_at',{'time':DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(p.start))})+' · '+sleepDurationText(now.millisecondsSinceEpoch-p.start);
  return L10nService().translate('sleep_sync_hint');
}
class SleepStatusCard extends StatelessWidget {
  const SleepStatusCard({super.key,required this.name,required this.person,required this.now,required this.avatarKey});
  final String name,avatarKey;final SleepPersonSnapshot person;final DateTime now;
  @override Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.all(20),decoration:BoxDecoration(borderRadius:BorderRadius.circular(24),gradient:const LinearGradient(colors:[Color(0xFF292943),Color(0xFF44425F)],begin:Alignment.topLeft,end:Alignment.bottomRight)),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Container(width:64,height:72,padding:const EdgeInsets.all(6),decoration:BoxDecoration(color:const Color(0xFFF6EFDF),borderRadius:BorderRadius.circular(23)),child:SvgPicture.asset('assets/images/widget_stickers/avatar_'+avatarKey+'.svg')),
      const SizedBox(width:16),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Expanded(child:Text(name,maxLines:2,overflow:TextOverflow.ellipsis,style:SLTheme.quicksand(fontSize:18,fontWeight:FontWeight.w800,color:const Color(0xFFFFF8E8)))),const SizedBox(width:8),Icon(person.state=='recorded'||person.state=='manual'||person.state=='estimated'?Icons.bedtime_rounded:Icons.cloud_outlined,color:const Color(0xFFDCCBEF),size:20)]),
        const SizedBox(height:8),Text(context.tr(sleepStateKey(person.state)),style:SLTheme.quicksand(fontSize:14,fontWeight:FontWeight.w700,color:const Color(0xFFE4D2FF))),
        const SizedBox(height:7),Text(sleepPersonDetail(person,now),style:const TextStyle(color:Color(0xFFCDC6DA),fontSize:12,height:1.4)),const SizedBox(height:12),
        Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.08),borderRadius:BorderRadius.circular(10)),child:Text(sleepSourceLabel(person.source),style:const TextStyle(color:Color(0xFFDED7EA),fontSize:11))),
      ])),
    ]));
}
