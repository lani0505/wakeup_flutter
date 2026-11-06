import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db.dart';
import 'camera.dart';

/// Tao / sua nhiem vu: ten + huong dan + anh do vat mau (chup bang camera).
class TaskEditScreen extends StatefulWidget {
  final TaskItem? task;
  const TaskEditScreen({super.key, this.task});
  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  late final _name = TextEditingController(text: widget.task?.name ?? '');
  late final _hint = TextEditingController(text: widget.task?.hint ?? '');
  late String? _image = widget.task?.imagePath;
  bool _changedImage = false;

  Future<void> _capture() async {
    final path = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const CameraScreen(title: 'Chụp đồ vật mẫu')));
    if (path != null) setState(() { _image = path; _changedImage = true; });
  }

  Future<void> _pickFile() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (f != null) setState(() { _image = f.path; _changedImage = true; });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return _msg('Hãy đặt tên nhiệm vụ');
    if (_image == null) return _msg('Hãy chụp ảnh đồ vật mẫu');
    var path = _image!;
    if (_changedImage) {
      final dir = await getApplicationDocumentsDirectory();
      final dest = p.join(dir.path, 'task_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(path).copy(dest);
      path = dest;
    }
    final t = TaskItem(id: widget.task?.id, name: _name.text.trim(), imagePath: path, hint: _hint.text.trim());
    await AppDb.I.saveTask(t);
    if (mounted) Navigator.of(context).pop(true);
  }

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.task == null ? 'Tạo nhiệm vụ' : 'Sửa nhiệm vụ')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Tên nhiệm vụ (vd: Bàn chải đánh răng)', border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
          const SizedBox(height: 12),
          TextField(controller: _hint, decoration: const InputDecoration(labelText: 'Hướng dẫn (vd: Đến phòng tắm)', border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
          const SizedBox(height: 16),
          Container(
            height: 240,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: _image == null
                ? const Center(child: Text('Chưa có ảnh mẫu'))
                : Image.file(File(_image!), fit: BoxFit.cover),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _capture, icon: const Icon(Icons.photo_camera), label: const Text('Chụp bằng camera'))),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.photo_library), label: const Text('Chọn ảnh có sẵn'))),
          ]),
          const SizedBox(height: 8),
          const Text('Mẹo: chụp đồ vật ở đúng chỗ và ánh sáng bạn sẽ chụp lúc báo thức, vật chiếm phần giữa khung hình.',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Padding(padding: EdgeInsets.all(12), child: Text('Lưu'))),
        ]),
      );
}
