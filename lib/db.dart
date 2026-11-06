import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const dayNames = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']; // weekday 1..7

String hm(int h, int m) =>
    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

class TaskItem {
  int? id;
  String name;
  String imagePath;
  String hint;
  TaskItem({this.id, required this.name, required this.imagePath, this.hint = ''});

  Map<String, Object?> toMap() =>
      {'id': id, 'name': name, 'image_path': imagePath, 'hint': hint};

  factory TaskItem.fromMap(Map<String, Object?> m) => TaskItem(
        id: m['id'] as int?,
        name: m['name'] as String,
        imagePath: m['image_path'] as String,
        hint: (m['hint'] as String?) ?? '',
      );
}

class AlarmItem {
  int? id;
  int hour;
  int minute;
  String label;
  List<int> days; // rong = bao thuc mot lan
  bool enabled;
  int? taskId;
  AlarmItem({
    this.id,
    required this.hour,
    required this.minute,
    this.label = '',
    this.days = const [],
    this.enabled = true,
    this.taskId,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'label': label,
        'days': days.join(','),
        'enabled': enabled ? 1 : 0,
        'task_id': taskId,
      };

  factory AlarmItem.fromMap(Map<String, Object?> m) {
    final d = (m['days'] as String?) ?? '';
    return AlarmItem(
      id: m['id'] as int?,
      hour: m['hour'] as int,
      minute: m['minute'] as int,
      label: (m['label'] as String?) ?? '',
      days: d.isEmpty ? [] : d.split(',').map(int.parse).toList(),
      enabled: (m['enabled'] as int) == 1,
      taskId: m['task_id'] as int?,
    );
  }

  String get daysText => days.isEmpty
      ? 'Một lần'
      : (days.length == 7 ? 'Mỗi ngày' : (List.of(days)..sort()).map((d) => dayNames[d - 1]).join(', '));
}

class HistoryItem {
  final int? id;
  final String alarmLabel;
  final String taskName;
  final DateTime time;
  final bool success;
  final int attempts;
  HistoryItem({
    this.id,
    required this.alarmLabel,
    required this.taskName,
    required this.time,
    required this.success,
    required this.attempts,
  });
}

class AppDb {
  static final AppDb I = AppDb._();
  AppDb._();
  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'wakeup.db');
    return openDatabase(path, version: 1, onCreate: (d, v) async {
      await d.execute(
          'CREATE TABLE users(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, email TEXT UNIQUE, salt TEXT, hash TEXT)');
      await d.execute(
          'CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, image_path TEXT, hint TEXT)');
      await d.execute(
          'CREATE TABLE alarms(id INTEGER PRIMARY KEY AUTOINCREMENT, hour INTEGER, minute INTEGER, label TEXT, days TEXT, enabled INTEGER, task_id INTEGER)');
      await d.execute(
          'CREATE TABLE history(id INTEGER PRIMARY KEY AUTOINCREMENT, alarm_label TEXT, task_name TEXT, time TEXT, success INTEGER, attempts INTEGER)');
    });
  }

  // ---- users
  Future<int> insertUser(String name, String email, String salt, String hash) async =>
      (await db).insert('users', {'name': name, 'email': email, 'salt': salt, 'hash': hash});

  Future<Map<String, Object?>?> userByEmail(String email) async {
    final r = await (await db).query('users', where: 'email = ?', whereArgs: [email]);
    return r.isEmpty ? null : r.first;
  }

  // ---- tasks
  Future<List<TaskItem>> tasks() async =>
      (await (await db).query('tasks', orderBy: 'id DESC')).map(TaskItem.fromMap).toList();

  Future<TaskItem?> taskById(int id) async {
    final r = await (await db).query('tasks', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : TaskItem.fromMap(r.first);
  }

  Future<int> saveTask(TaskItem t) async {
    final d = await db;
    if (t.id == null) return d.insert('tasks', t.toMap()..remove('id'));
    await d.update('tasks', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
    return t.id!;
  }

  Future<void> deleteTask(int id) async {
    final d = await db;
    await d.delete('tasks', where: 'id = ?', whereArgs: [id]);
    await d.update('alarms', {'task_id': null}, where: 'task_id = ?', whereArgs: [id]);
  }

  // ---- alarms
  Future<List<AlarmItem>> alarms() async =>
      (await (await db).query('alarms', orderBy: 'hour, minute')).map(AlarmItem.fromMap).toList();

  Future<AlarmItem?> alarmById(int id) async {
    final r = await (await db).query('alarms', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : AlarmItem.fromMap(r.first);
  }

  Future<int> saveAlarm(AlarmItem a) async {
    final d = await db;
    if (a.id == null) return d.insert('alarms', a.toMap()..remove('id'));
    await d.update('alarms', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
    return a.id!;
  }

  Future<void> deleteAlarm(int id) async =>
      (await db).delete('alarms', where: 'id = ?', whereArgs: [id]);

  // ---- history
  Future<void> addHistory(HistoryItem h) async => (await db).insert('history', {
        'alarm_label': h.alarmLabel,
        'task_name': h.taskName,
        'time': h.time.toIso8601String(),
        'success': h.success ? 1 : 0,
        'attempts': h.attempts,
      });

  Future<List<HistoryItem>> history() async =>
      (await (await db).query('history', orderBy: 'id DESC')).map((m) => HistoryItem(
            id: m['id'] as int?,
            alarmLabel: (m['alarm_label'] as String?) ?? '',
            taskName: (m['task_name'] as String?) ?? '',
            time: DateTime.parse(m['time'] as String),
            success: (m['success'] as int) == 1,
            attempts: m['attempts'] as int,
          )).toList();

  Future<void> clearHistory() async => (await db).delete('history');
}
