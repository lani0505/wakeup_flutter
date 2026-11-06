import 'dart:io';

import 'package:flutter/material.dart';

import '../db.dart';
import '../services.dart';
import 'alarm_edit.dart';
import 'auth.dart';
import 'ring.dart';
import 'task_edit.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    const tabs = [AlarmsTab(), TasksTab(), HistoryTab(), SettingsTab()];
    return Scaffold(
      body: SafeArea(child: tabs[_i]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.alarm), label: 'Báo thức'),
          NavigationDestination(icon: Icon(Icons.task_alt), label: 'Nhiệm vụ'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Lịch sử'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Cài đặt'),
        ],
      ),
    );
  }
}

// ---------------- Bao thuc ----------------
class AlarmsTab extends StatefulWidget {
  const AlarmsTab({super.key});
  @override
  State<AlarmsTab> createState() => _AlarmsTabState();
}

class _AlarmsTabState extends State<AlarmsTab> {
  List<AlarmItem> _alarms = [];
  Map<int, String> _taskNames = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await AppDb.I.alarms();
    final t = await AppDb.I.tasks();
    if (mounted) setState(() { _alarms = a; _taskNames = {for (final x in t) x.id!: x.name}; });
  }

  Future<void> _edit([AlarmItem? a]) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlarmEditScreen(alarm: a)));
    _load();
  }

  Future<void> _toggle(AlarmItem a, bool v) async {
    a.enabled = v;
    await AppDb.I.saveAlarm(a);
    await Notif.schedule(a);
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton(onPressed: () => _edit(), child: const Icon(Icons.add)),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Danh sách báo thức', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_alarms.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Chưa có báo thức. Bấm + để thêm.'))),
          for (final a in _alarms)
            Card(
              child: ListTile(
                onTap: () => _edit(a),
                title: Text(hm(a.hour, a.minute), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                subtitle: Text('${a.label.isEmpty ? 'Báo thức' : a.label} · ${a.daysText}\nNhiệm vụ: ${_taskNames[a.taskId] ?? 'Không có'}'),
                isThreeLine: true,
                trailing: Switch(value: a.enabled, onChanged: (v) => _toggle(a, v)),
              ),
            ),
        ]),
      );
}

// ---------------- Nhiem vu ----------------
class TasksTab extends StatefulWidget {
  const TasksTab({super.key});
  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  List<TaskItem> _tasks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await AppDb.I.tasks();
    if (mounted) setState(() => _tasks = t);
  }

  Future<void> _edit([TaskItem? t]) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskEditScreen(task: t)));
    _load();
  }

  Future<void> _delete(TaskItem t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xóa nhiệm vụ?'),
        content: Text('Xóa "${t.name}". Các báo thức đang dùng nhiệm vụ này sẽ không còn nhiệm vụ.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok == true) {
      await AppDb.I.deleteTask(t.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton(onPressed: () => _edit(), child: const Icon(Icons.add_a_photo)),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Nhiệm vụ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_tasks.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Chưa có nhiệm vụ. Bấm nút máy ảnh để chụp đồ vật mẫu.'))),
          for (final t in _tasks)
            Card(
              child: ListTile(
                onTap: () => _edit(t),
                leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(t.imagePath), width: 56, height: 56, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40))),
                title: Text(t.name),
                subtitle: Text(t.hint.isEmpty ? 'Chạm để sửa' : t.hint),
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(t)),
              ),
            ),
        ]),
      );
}

// ---------------- Lich su ----------------
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});
  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  List<HistoryItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await AppDb.I.history();
    if (mounted) setState(() => _items = h);
  }

  String _fmt(DateTime t) =>
      '${hm(t.hour, t.minute)} · ${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          const Expanded(child: Text('Lịch sử báo thức', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          if (_items.isNotEmpty) TextButton(onPressed: () async { await AppDb.I.clearHistory(); _load(); }, child: const Text('Xóa hết')),
        ]),
        const SizedBox(height: 12),
        if (_items.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Chưa có lịch sử.'))),
        for (final h in _items)
          Card(
            child: ListTile(
              leading: Icon(h.success ? Icons.check_circle : Icons.cancel, color: h.success ? Colors.green : Colors.red),
              title: Text('${h.alarmLabel} · ${h.taskName}'),
              subtitle: Text('${_fmt(h.time)} · ${h.attempts} lần chụp'),
              trailing: Text(h.success ? 'Thành công' : 'Chưa thành công', style: TextStyle(color: h.success ? Colors.green : Colors.red, fontSize: 12)),
            ),
          ),
      ]);
}

// ---------------- Cai dat ----------------
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});
  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  double _th = 0.6;
  String _name = '', _email = '';

  @override
  void initState() {
    super.initState();
    Prefs.threshold().then((v) => mounted ? setState(() => _th = v) : null);
    Auth.current().then((u) => mounted ? setState(() { _name = u.name; _email = u.email; }) : null);
  }

  Future<AlarmItem?> _firstAlarm() async {
    final l = await AppDb.I.alarms();
    if (l.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hãy tạo ít nhất một báo thức trước')));
      return null;
    }
    return l.first;
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Cài đặt', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(_name), subtitle: Text(_email))),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Độ nghiêm ngặt khi nhận diện: ${(_th * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w600)),
              const Text('Cao hơn = ảnh phải giống ảnh mẫu hơn. Nếu chụp đúng mà vẫn bị báo sai, hãy giảm xuống.', style: TextStyle(fontSize: 12, color: Colors.black54)),
              Slider(
                value: _th, min: 0.3, max: 0.9, divisions: 12,
                label: '${(_th * 100).round()}%',
                onChanged: (v) => setState(() => _th = v),
                onChangeEnd: Prefs.setThreshold,
              ),
            ]),
          ),
        ),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('Báo thức thử sau 20 giây'),
              subtitle: const Text('Dùng báo thức đầu tiên trong danh sách. Có thể khóa màn hình để thử.'),
              onTap: () async {
                final a = await _firstAlarm();
                if (a == null) return;
                await Notif.scheduleTest(a);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã hẹn báo thức thử sau 20 giây')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('Xem thử màn hình báo thức'),
              onTap: () async {
                final a = await _firstAlarm();
                if (a != null && !ringActive) Notif.openRing(a.id);
              },
            ),
          ]),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await Auth.logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
            },
          ),
        ),
      ]);
}
