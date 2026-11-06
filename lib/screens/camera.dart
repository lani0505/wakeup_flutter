import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Mo camera, chup 1 anh va tra ve duong dan file (Navigator.pop(path)).
class CameraScreen extends StatefulWidget {
  final String title;
  const CameraScreen({super.key, required this.title});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _c;
  String? _error;
  bool _taking = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw 'Không tìm thấy camera';
      final cam = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      final c = CameraController(cam, ResolutionPreset.medium, enableAudio: false);
      await c.initialize();
      if (!mounted) { await c.dispose(); return; }
      setState(() => _c = c);
    } catch (e) {
      if (mounted) setState(() => _error = 'Không mở được camera: $e\nHãy cấp quyền Camera cho ứng dụng (Windows: Settings → Privacy → Camera → cho phép ứng dụng desktop).');
    }
  }

  Future<void> _shoot() async {
    if (_c == null || _taking) return;
    setState(() => _taking = true);
    try {
      final f = await _c!.takePicture();
      if (mounted) Navigator.of(context).pop(f.path);
    } catch (e) {
      if (mounted) setState(() { _taking = false; _error = '$e'; });
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: Text(widget.title), backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center)))
            : _c == null
                ? const Center(child: CircularProgressIndicator())
                : Column(children: [
                    Expanded(child: Center(child: CameraPreview(_c!))),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: GestureDetector(
                        onTap: _shoot,
                        child: Container(
                          width: 76, height: 76,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: Colors.white54, width: 6)),
                          child: _taking ? const Padding(padding: EdgeInsets.all(22), child: CircularProgressIndicator(strokeWidth: 3)) : null,
                        ),
                      ),
                    ),
                  ]),
      );
}
