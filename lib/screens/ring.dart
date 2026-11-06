import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart'; // AM THANH
import 'package:flutter/material.dart';

import '../db.dart';
import '../services.dart';
import 'camera.dart';

/// true khi man hinh bao thuc dang hien (tranh mo trung).
bool ringActive = false;

class RingScreen extends StatefulWidget {
  final int alarmId;
  const RingScreen({super.key, required this.alarmId});
  @override
  State<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends State<RingScreen> {
  AlarmItem? _alarm;
  TaskItem? _task;
  int _attempts = 0;
  String? _msg;
  bool _busy = false;
  DateTime _now = DateTime.now();
  Timer? _clock;
  final _player = AudioPlayer(); // AM THANH

  @override
  void initState() {
    super.initState();
    ringActive = true;
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
    _load();
    if (!Notif.supported) _startSound(); // AM THANH: Windows tu phat am bao thuc
  }

  // AM THANH
  Future<void> _startSound() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('alarm.wav'));
    } catch (_) {}
  }

  Future<void> _load() async {
    final a = await AppDb.I.alarmById(widget.alarmId);
    final t = (a?.taskId != null) ? await AppDb.I.taskById(a!.taskId!) : null;
    if (mounted) setState(() { _alarm = a; _task = t; });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _player.dispose(); // AM THANH
    ringActive = false;
    super.dispose();
  }

  Future<void> _capture() async {
    final path = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => CameraScreen(title: 'Chụp: ${_task!.name}')));
    if (path == null || !mounted) return;
    setState(() { _busy = true; _msg = null; });
    try {
      final score = await ImageMatcher.score(_task!.imagePath, path);
      final th = await Prefs.threshold();
      _attempts++;
      if (score >= th) {
        await _finish(true);
      } else if (mounted) {
        setState(() {
          _busy = false;
          _msg = 'Chưa đúng đồ vật (độ giống ${(score * 100).round()}%, cần ${(th * 100).round()}%). Hãy chụp lại!';
        });
      }
    } catch (e) {
      if (mounted) setState(() { _busy = false; _msg = 'Không xử lý được ảnh: $e'; });
    }
  }

  Future<void> _finish(bool success) async {
    final a = _alarm;
    if (a != null) {
      await AppDb.I.addHistory(HistoryItem(
        alarmLabel: a.label.isEmpty ? hm(a.hour, a.minute) : a.label,
        taskName: _task?.name ?? '—',
        time: DateTime.now(),
        success: success,
        attempts: _attempts,
      ));
      await Notif.cancel(a); // dung chuong
      if (a.days.isEmpty) a.enabled = false; // bao thuc mot lan
      await AppDb.I.saveAlarm(a);
      await Notif.schedule(a); // hen lan lap tiep theo
    }
    await _player.stop(); // AM THANH: dung am thanh khi hoan thanh
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: Icon(success ? Icons.check_circle : Icons.info, color: success ? Colors.green : Colors.orange, size: 56),
        title: Text(success ? 'Hoàn thành nhiệm vụ!' : 'Đã tắt báo thức'),
        content: Text(success ? 'Bạn đã chụp đúng đồ vật. Chúc một ngày tốt lành!' : 'Báo thức đã tắt mà chưa hoàn thành nhiệm vụ.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tiếp tục'))],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final a = _alarm;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF1B2547),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: a == null
                ? const Center(child: CircularProgressIndicator())
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SizedBox(height: 24),
                    const Icon(Icons.alarm, color: Colors.white, size: 64),
                    Text(hm(_now.hour, _now.minute), textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold)),
                    Text(a.label.isEmpty ? 'Báo thức' : a.label, textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 22)),
                    const SizedBox(height: 24),
                    if (_task != null) ...[
                      Text('Nhiệm vụ: chụp ảnh "${_task!.name}"', textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                      if (_task!.hint.isNotEmpty)
                        Padding(padding: const EdgeInsets.only(top: 6), child: Text(_task!.hint, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))),
                      const SizedBox(height: 16),
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(File(_task!.imagePath), height: 140, width: 140, fit: BoxFit.cover),
                        ),
                      ),
                    ] else
                      const Text('Không có nhiệm vụ cho báo thức này.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    if (_msg != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFE5484D), borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          const Icon(Icons.cancel, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_msg!, style: const TextStyle(color: Colors.white))),
                        ]),
                      ),
                    const Spacer(),
                    if (_busy)
                      const Center(child: CircularProgressIndicator(color: Colors.white))
                    else if (_task != null)
                      FilledButton.icon(
                        onPressed: _capture,
                        icon: const Icon(Icons.photo_camera),
                        label: const Padding(padding: EdgeInsets.all(14), child: Text('Mở camera')),
                      )
                    else
                      FilledButton(onPressed: () => _finish(true), child: const Padding(padding: EdgeInsets.all(14), child: Text('Tắt báo thức'))),
                    if (_attempts >= 5)
                      TextButton(onPressed: () => _finish(false), child: const Text('Tắt khẩn cấp (không tính hoàn thành)', style: TextStyle(color: Colors.white70))),
                  ]),
          ),
        ),
      ),
    );
  }
}