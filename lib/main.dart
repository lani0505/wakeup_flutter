import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'db.dart';
import 'screens/auth.dart';
import 'screens/home.dart';
import 'screens/ring.dart';
import 'services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi; // SQLite cho may tinh
  }
  await Notif.init();
  runApp(const WakeUpApp());
}

class WakeUpApp extends StatelessWidget {
  const WakeUpApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'WakeUp',
        navigatorKey: Notif.navKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F5BEA)),
          scaffoldBackgroundColor: const Color(0xFFF4F7FF),
        ),
        home: const AppRoot(),
      );
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});
  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late final Future<bool> _logged = Auth.restoreSession();
  Timer? _timer;
  String _lastKey = '';

  @override
  void initState() {
    super.initState();
    Notif.rescheduleAll();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = Notif.pendingAlarmId;
      Notif.pendingAlarmId = null;
      Notif.openRing(id);
    });
    // Khi app dang mo: tu kiem tra moi 15 giay xem co bao thuc den gio chua.
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
  }

  Future<void> _tick() async {
    if (ringActive) return;
    final now = DateTime.now();
    for (final a in await AppDb.I.alarms()) {
      if (!a.enabled || a.hour != now.hour || a.minute != now.minute) continue;
      if (a.days.isNotEmpty && !a.days.contains(now.weekday)) continue;
      final key = '${a.id}-${now.year}${now.month}${now.day}-${now.hour}:${now.minute}';
      if (key == _lastKey) continue;
      _lastKey = key;
      Notif.openRing(a.id);
      break;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: _logged,
        builder: (c, s) {
          if (!s.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          return s.data! ? const HomeScreen() : const LoginScreen();
        },
      );
}
