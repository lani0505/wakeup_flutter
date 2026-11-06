import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'db.dart';
import 'screens/ring.dart';

// ============ Cai dat don gian (SharedPreferences) ============
class Prefs {
  static Future<double> threshold() async =>
      (await SharedPreferences.getInstance()).getDouble('threshold') ?? 0.6;
  static Future<void> setThreshold(double v) async =>
      (await SharedPreferences.getInstance()).setDouble('threshold', v);
}

// ============ Dang ky / Dang nhap (luu cuc bo bang SQLite) ============
// De doi sang Firebase Authentication: chi can thay noi dung register/login.
class Auth {
  static String _hash(String salt, String pass) =>
      sha256.convert(utf8.encode('$salt:$pass')).toString();

  static Future<String?> register(String name, String email, String pass) async {
    email = email.trim().toLowerCase();
    if (await AppDb.I.userByEmail(email) != null) return 'Email này đã được đăng ký';
    final salt = base64Url.encode(List<int>.generate(16, (_) => Random.secure().nextInt(256)));
    final id = await AppDb.I.insertUser(name.trim(), email, salt, _hash(salt, pass));
    await _saveSession(id, name.trim(), email, true);
    return null;
  }

  static Future<String?> login(String email, String pass, bool remember) async {
    email = email.trim().toLowerCase();
    final u = await AppDb.I.userByEmail(email);
    if (u == null || _hash(u['salt'] as String, pass) != u['hash']) {
      return 'Email hoặc mật khẩu không đúng';
    }
    await _saveSession(u['id'] as int, u['name'] as String, email, remember);
    return null;
  }

  static Future<void> _saveSession(int id, String name, String email, bool remember) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('uid', id);
    await p.setString('uname', name);
    await p.setString('uemail', email);
    await p.setBool('remember', remember);
  }

  /// Goi khi mo app: neu khong chon "Nho tai khoan" thi dang xuat.
  static Future<bool> restoreSession() async {
    final p = await SharedPreferences.getInstance();
    if (p.getInt('uid') == null) return false;
    if (!(p.getBool('remember') ?? false)) {
      await logout();
      return false;
    }
    return true;
  }

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    for (final k in ['uid', 'uname', 'uemail', 'remember']) {
      await p.remove(k);
    }
  }

  static Future<({String name, String email})> current() async {
    final p = await SharedPreferences.getInstance();
    return (name: p.getString('uname') ?? '', email: p.getString('uemail') ?? '');
  }
}

// ============ Thong bao + hen gio bao thuc ============
class Notif {
  static final plugin = FlutterLocalNotificationsPlugin();
  static final navKey = GlobalKey<NavigatorState>();
  static int? pendingAlarmId; // mo app tu thong bao khi app dang tat

  static bool get supported => Platform.isAndroid || Platform.isIOS;

  static Future<void> init() async {
    if (!supported) return; // Windows: khong dung thong bao he thong
    tzdata.initializeTimeZones();
    await plugin.initialize(
      const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      onDidReceiveNotificationResponse: (r) => openRing(int.tryParse(r.payload ?? '')),
    );
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      pendingAlarmId = int.tryParse(launch!.notificationResponse?.payload ?? '');
    }
  }

  static void openRing(int? alarmId) {
    if (alarmId == null || ringActive) return;
    navKey.currentState?.push(MaterialPageRoute(builder: (_) => RingScreen(alarmId: alarmId)));
  }

  static NotificationDetails get _details => NotificationDetails(
        android: AndroidNotificationDetails(
          'wakeup_alarm',
          'Báo thức',
          channelDescription: 'Báo thức WakeUp',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          ongoing: true,
          autoCancel: false,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT: lap am thanh den khi huy
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );

  static Future<void> _zoned(int id, String title, DateTime when, int alarmId) async {
    if (!supported) return;
    await plugin.zonedSchedule(
        id,
        title,
        'Chụp ảnh đồ vật để tắt báo thức',
        tz.TZDateTime.from(when, tz.local),
        _details,
        payload: '$alarmId',
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancel(AlarmItem a) async {
    if (!supported || a.id == null) return;
    for (var d = 0; d <= 7; d++) {
      await plugin.cancel(a.id! * 10 + d);
    }
    await plugin.cancel(990000 + a.id!);
  }

  /// Hen cac lan bao thuc tiep theo (moi ngay lap lai = 1 thong bao).
  static Future<void> schedule(AlarmItem a) async {
    await cancel(a);
    if (!a.enabled || a.id == null) return;
    final now = DateTime.now();
    final days = a.days.isEmpty ? [0] : a.days;
    for (final d in days) {
      var t = DateTime(now.year, now.month, now.day, a.hour, a.minute);
      while ((d != 0 && t.weekday != d) || !t.isAfter(now)) {
        t = DateTime(t.year, t.month, t.day + 1, a.hour, a.minute);
      }
      await _zoned(a.id! * 10 + d, a.label.isEmpty ? 'Báo thức' : a.label, t, a.id!);
    }
  }

  static Future<void> scheduleTest(AlarmItem a, {int seconds = 20}) async {
    if (!supported) {
      // May tinh: khong co thong bao he thong, mo thang man hinh bao thuc sau N giay.
      Future.delayed(Duration(seconds: seconds), () => openRing(a.id));
      return;
    }
    await _zoned(990000 + a.id!, a.label.isEmpty ? 'Báo thức thử' : a.label,
        DateTime.now().add(Duration(seconds: seconds)), a.id!);
  }

  static Future<void> rescheduleAll() async {
    for (final a in await AppDb.I.alarms()) {
      await schedule(a);
    }
  }
}

// ============ So khop anh (Dart thuan, khong can mo hinh) ============
// Dac trung: histogram mau 4x4x4 + tuong quan anh xam 32x32 o vung giua.
// Day la phuong an co ban. De chinh xac hon: xem README (LiteRT/TFLite).
class ImageMatcher {
  static Future<double> score(String refPath, String newPath) =>
      compute(_score, <String>[refPath, newPath]);
}

class _Feat {
  final List<double> hist;
  final List<double> gray;
  _Feat(this.hist, this.gray);
}

_Feat _feat(String path) {
  var im = img.decodeImage(File(path).readAsBytesSync())!;
  im = img.bakeOrientation(im);
  final w = im.width, h = im.height;
  im = img.copyCrop(im,
      x: (w * 0.15).round(), y: (h * 0.15).round(), width: (w * 0.7).round(), height: (h * 0.7).round());
  final s = img.copyResize(im, width: 32, height: 32);
  final hist = List<double>.filled(64, 0);
  final gray = <double>[];
  for (var y = 0; y < 32; y++) {
    for (var x = 0; x < 32; x++) {
      final px = s.getPixel(x, y);
      final r = px.r.toInt(), g = px.g.toInt(), b = px.b.toInt();
      hist[(r ~/ 64) * 16 + (g ~/ 64) * 4 + (b ~/ 64)] += 1;
      gray.add(0.299 * r + 0.587 * g + 0.114 * b);
    }
  }
  for (var i = 0; i < 64; i++) {
    hist[i] /= 1024;
  }
  return _Feat(hist, gray);
}

double _score(List<String> paths) {
  final a = _feat(paths[0]), b = _feat(paths[1]);
  var inter = 0.0;
  for (var i = 0; i < 64; i++) {
    inter += min(a.hist[i], b.hist[i]);
  }
  final n = a.gray.length;
  final ma = a.gray.reduce((x, y) => x + y) / n, mb = b.gray.reduce((x, y) => x + y) / n;
  var cov = 0.0, va = 0.0, vb = 0.0;
  for (var i = 0; i < n; i++) {
    final x = a.gray[i] - ma, y = b.gray[i] - mb;
    cov += x * y;
    va += x * x;
    vb += y * y;
  }
  final corr = (va == 0 || vb == 0) ? 0.0 : cov / sqrt(va * vb);
  return 0.6 * inter + 0.4 * max(0.0, corr);
}
