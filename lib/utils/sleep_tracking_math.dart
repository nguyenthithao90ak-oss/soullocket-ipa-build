/// Tính toán thuần: không suy ra giấc ngủ từ bản ghi Health đã kết thúc.
class SleepInterval {
  const SleepInterval(this.start, this.end);
  final int start;
  final int end;
  int get duration => end - start;
}

class SleepSample extends SleepInterval {
  const SleepSample(super.start, super.end, this.kind);
  final String kind;
}

class SleepRecord extends SleepInterval {
  const SleepRecord(super.start, super.end, this.asleepMs, [this.parts=const []]);
  final int asleepMs;
  final List<SleepInterval> parts;
  Map<String, Object> toMap(String source) => {
    'start_time': start, 'end_time': end, 'duration_ms': asleepMs,
    'source': source, 'sleep_status': 'recorded',
    if(parts.isNotEmpty) 'segments':[for(final p in parts) {'start':p.start,'end':p.end}],
  };
}

int sleepEpoch(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
String sleepConsentScope(String uid,String house,String role)=>'$uid|$house|$role';
String? sleepRole(String? value) => switch(value) {
  'user1' || 'husband' => 'user1', 'user2' || 'wife' => 'user2', _ => null,
};

Map<String, dynamic> sleepRoleData(Map<dynamic, dynamic> data, String role) {
  final raw = data[role] ?? data[role == 'user1' ? 'husband' : 'wife'];
  return raw is Map ? Map<String, dynamic>.from(raw) : {};
}

List<SleepInterval> mergeSleepIntervals(Iterable<SleepInterval> input) {
  final sorted = input.where((s) => s.start > 0 && s.end > s.start).toList()
    ..sort((a,b) => a.start.compareTo(b.start));
  final out = <SleepInterval>[];
  for (final s in sorted) {
    if (out.isEmpty || s.start > out.last.end) { out.add(s); }
    else { final last = out.removeLast(); out.add(SleepInterval(last.start, s.end > last.end ? s.end : last.end)); }
  }
  return out;
}

/// Gộp trùng giữa nguồn/phase, bỏ inBed, trừ awake; không cộng vỏ phiên.
List<SleepRecord> recordedSleep(Iterable<SleepSample> input, {required int now}) {
  const asleep = {'SLEEP_ASLEEP','SLEEP_LIGHT','SLEEP_DEEP','SLEEP_REM'};
  final valid = input.where((s) => s.start > 0 && s.end > s.start && s.end <= now).toList();
  final sleeping = mergeSleepIntervals(valid.where((s) => asleep.contains(s.kind)));
  final awake = mergeSleepIntervals(valid.where((s) => s.kind == 'SLEEP_AWAKE' || s.kind == 'SLEEP_AWAKE_IN_BED'));
  final parts = <SleepInterval>[];
  for (final s in sleeping) {
    var cursor = s.start;
    for (final a in awake) {
      if (a.end <= cursor || a.start >= s.end) continue;
      if (a.start > cursor) parts.add(SleepInterval(cursor, a.start));
      if (a.end > cursor) cursor = a.end;
      if (cursor >= s.end) break;
    }
    if (cursor < s.end) parts.add(SleepInterval(cursor,s.end));
  }
  final records = <SleepRecord>[];
  for (final s in parts) {
    if (records.isEmpty || s.start - records.last.end > const Duration(hours: 1).inMilliseconds) {
      records.add(SleepRecord(s.start,s.end,s.duration,[s]));
    } else {
      final last = records.removeLast(); records.add(SleepRecord(last.start,s.end,last.asleepMs+s.duration,[...last.parts,s]));
    }
  }
  return records;
}

/// Phân ngày theo ngày thức dậy local, không theo khoảng cách 24h từ now.
Map<int,double> sleepWeek(Iterable<Map<String,dynamic>> records, DateTime now) {
  final days = <int,double>{for(var i=0;i<7;i++) i:0};
  final byDay=<int,List<SleepInterval>>{};
  final legacy=<int,List<SleepRecord>>{};
  for (final r in records) {
    final start=sleepEpoch(r['start_time']),end=sleepEpoch(r['end_time']),duration=sleepEpoch(r['duration_ms']);
    if(start<=0||end<=start||end>now.millisecondsSinceEpoch||duration<=0||duration>end-start) continue;
    final wake=DateTime.fromMillisecondsSinceEpoch(end);
    final day=DateTime.utc(now.year,now.month,now.day).difference(DateTime.utc(wake.year,wake.month,wake.day)).inDays;
    if(day<0||day>=7) continue;
    final raw=r['segments'];
    final parts=raw is List?mergeSleepIntervals(raw.whereType<Map>().map((p)=>SleepInterval(sleepEpoch(p['start']),sleepEpoch(p['end'])))): <SleepInterval>[];
    if(parts.isNotEmpty && parts.every((p)=>p.start>=start&&p.end<=end) && parts.fold<int>(0,(n,p)=>n+p.duration)==duration) {
      byDay.putIfAbsent(day,()=>[]).addAll(parts);
    } else if(duration==end-start) {
      byDay.putIfAbsent(day,()=>[]).add(SleepInterval(start,end));
    } else {
      // Bản cũ không lưu segment: chỉ giữ phiên không chồng lấp, tránh bịa thời gian thức.
      legacy.putIfAbsent(day,()=>[]).add(SleepRecord(start,end,duration));
    }
  }
  for(var day=0;day<7;day++) {
    final parts=mergeSleepIntervals(byDay[day]??[]);
    var total=parts.fold<int>(0,(n,p)=>n+p.duration);
    final accepted=<SleepRecord>[];
    final old=legacy[day]??[];old.sort((a,b)=>b.asleepMs.compareTo(a.asleepMs));
    for(final r in old) {
      if(parts.any((p)=>p.start<r.end&&r.start<p.end)||accepted.any((p)=>p.start<r.end&&r.start<p.end)) continue;
      accepted.add(r);total+=r.asleepMs;
    }
    days[day]=total/3600000;
  }
  return days;
}

class SleepPersonSnapshot {
  const SleepPersonSnapshot({required this.state, required this.source, this.start=0, this.end=0, this.duration=0, this.updated=0});
  final String state,source;
  final int start,end,duration,updated;
  factory SleepPersonSnapshot.fromPresence(Map<String,dynamic> p,int now) {
    final source=p['sleep_source']?.toString() ?? 'unknown';
    final updated=sleepEpoch(p['sleep_updated_at']);
    final start=sleepEpoch(p['sleep_start_time']);
    if(p['sleep_tracking_enabled']==false) return SleepPersonSnapshot(state:'disabled',source:source,updated:updated);
    if(source=='healthkit') {
      final end=sleepEpoch(p['sleep_record_end']);
      final recordStart=sleepEpoch(p['sleep_record_start']);
      final duration=sleepEpoch(p['sleep_record_duration']);
      if(end>recordStart && recordStart>0 && end<=now && duration>0 && duration<=end-recordStart) {
        return SleepPersonSnapshot(state:'recorded',source:source,start:recordStart,end:end,duration:duration,updated:updated);
      }
      return SleepPersonSnapshot(state:'unknown',source:source,updated:updated);
    }
    if(source!='manual' && source!='screen_estimate') {
      return SleepPersonSnapshot(state:'unknown',source:'unknown',updated:updated);
    }
    final age=now-updated;
    final fresh=updated>0 && age>=0 && age <= (source=='manual' ? 86400000 : 900000);
    if(!fresh) return SleepPersonSnapshot(state:'unknown',source:source,updated:updated);
    if(p['sleep_mode']==true && start>0 && start<=now && now-start<=86400000) {
      return SleepPersonSnapshot(state:source=='manual'?'manual':'estimated',source:source,start:start,updated:updated);
    }
    final state=p['sleep_status']=='awake'?'active':p['sleep_status']=='inactive'?'inactive':'unknown';
    return SleepPersonSnapshot(state:state,source:source,updated:updated);
  }
  Map<String,Object> toMap(String name) => {'name':name,'state':state,'source':source,'start':start,'end':end,'duration':duration,'updated':updated};
}

/// Ước tính Android: màn hình tắt không phải bằng chứng đã ngủ.
String androidSleepEstimate(Map<String,dynamic> p,DateTime now) {
  final off=sleepEpoch(p['last_screen_off']),on=sleepEpoch(p['last_screen_on']);
  final elapsed=now.millisecondsSinceEpoch-off;
  if(off<=0||off<=on||elapsed<0) return on>0?'awake':'unknown';
  if(elapsed>50400000) return 'unknown';
  final minute=now.hour*60+now.minute;
  if((minute>=1260||minute<360)&&elapsed>=1200000) return 'sleeping';
  if(minute>=690&&minute<810&&elapsed>=1800000) return 'noon_nap';
  return elapsed>=7200000?'inactive':'unknown';
}
