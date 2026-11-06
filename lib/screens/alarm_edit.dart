import 'package:flutter/material.dart';

import '../db.dart';
import '../services.dart';

/// Tao / sua bao thuc: chon gio, ten, ngay lap, nhiem vu.
class AlarmEditScreen extends StatefulWidget {
  final AlarmItem? alarm;
  const AlarmEditScreen({super.key, this.alarm});
  @override
  State<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends State<AlarmEditScreen> {
  late TimeOfDay _time = TimeOfDay(hour: widget.alarm?.hour ?? 6, minute: widget.alarm?.minute ?? 0);
  late final _label = TextEditingController(text: widget.alarm?.label ?? '');
  late final Set<int> _days = {...?widget.alarm?.days};
  late int? _taskId = widget.alarm?.taskId;
  List<TaskItem> _tasks = [];

  @override
  void initState() {
    super.initState();
    AppDb.I.tasks().then((t) {
      if (!mounted) return;
      setState(() {
        _tasks = t;
        if (_taskId != null && !t.any((x) => x.id == _taskId)) _taskId = null;
      });
    });
  }

  Future<void> _pick() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _save() async {
    final a = AlarmItem(
      id: widget.alarm?.id,
      hour: _time.hour,
      minute: _time.minute,
      label: _label.text.trim(),
      days: _days.toList()..sort(),
      enabled: true,
      taskId: _taskId,
    );
    a.id = await AppDb.I.saveAlarm(a);
    await Notif.schedule(a);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final a = widget.alarm!;
    await Notif.cancel(a);
    await AppDb.I.deleteAlarm(a.id!);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.alarm == null ? 'Thêm báo thức' : 'Sửa báo thức'),
          actions: [if (widget.alarm != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline))],
        ),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          InkWell(
            onTap: _pick,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Text(hm(_time.hour, _time.minute), style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold)),
                const Text('Chạm để chọn giờ'),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: _label, decoration: const InputDecoration(labelText: 'Tên báo thức', border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
          const SizedBox(height: 16),
          const Text('Ngày lặp lại (bỏ trống = một lần)'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (var d = 1; d <= 7; d++)
              FilterChip(
                label: Text(dayNames[d - 1]),
                selected: _days.contains(d),
                onSelected: (s) => setState(() => s ? _days.add(d) : _days.remove(d)),
              ),
          ]),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            value: _taskId,
            decoration: const InputDecoration(labelText: 'Nhiệm vụ để tắt báo thức', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Không dùng nhiệm vụ')),
              for (final t in _tasks) DropdownMenuItem<int?>(value: t.id, child: Text(t.name)),
            ],
            onChanged: (v) => setState(() => _taskId = v),
          ),
          if (_tasks.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 6), child: Text('Chưa có nhiệm vụ nào. Vào tab "Nhiệm vụ" để tạo.', style: TextStyle(fontSize: 12, color: Colors.black54))),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Padding(padding: EdgeInsets.all(12), child: Text('Lưu'))),
        ]),
      );
}
