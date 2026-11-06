import 'package:flutter/material.dart';

import '../services.dart';
import 'home.dart';

void _toHome(BuildContext c) => Navigator.of(c)
    .pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _remember = true, _hide = true, _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    String? err;
    try {
      err = await Auth.login(_email.text, _pass.text, _remember);
    } catch (e) {
      err = 'Lỗi hệ thống: $e';
    }
    if (!mounted) return;
    if (err == null) {
      _toHome(context);
    } else {
      setState(() { _busy = false; _error = err; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 48),
                const Icon(Icons.alarm, size: 72, color: Color(0xFF2F5BEA)),
                const Text('WakeUp', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Color(0xFF2F5BEA))),
                const SizedBox(height: 4),
                const Text('Thức dậy đúng giờ, hoàn thành nhiệm vụ', textAlign: TextAlign.center),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Nhập email hợp lệ' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pass,
                  obscureText: _hide,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu', border: const OutlineInputBorder(), filled: true, fillColor: Colors.white,
                    suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _hide = !_hide)),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Nhập mật khẩu' : null,
                ),
                CheckboxListTile(
                  value: _remember, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Nhớ tài khoản'), onChanged: (v) => setState(() => _remember = v ?? false),
                ),
                if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                FilledButton(onPressed: _busy ? null : _submit, child: const Padding(padding: EdgeInsets.all(12), child: Text('Đăng nhập'))),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: const Text('Chưa có tài khoản? Đăng ký'),
                ),
              ]),
            ),
          ),
        ),
      );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    String? err;
    try {
      err = await Auth.register(_name.text, _email.text, _pass.text);
    } catch (e) {
      err = 'Lỗi hệ thống: $e';
    }
    if (!mounted) return;
    if (err == null) {
      _toHome(context);
    } else {
      setState(() { _busy = false; _error = err; });
    }
  }

  InputDecoration _dec(String l) => InputDecoration(labelText: l, border: const OutlineInputBorder(), filled: true, fillColor: Colors.white);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Đăng ký tài khoản'), backgroundColor: Colors.transparent),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextFormField(controller: _name, decoration: _dec('Họ và tên'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập họ tên' : null),
                const SizedBox(height: 12),
                TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: _dec('Email'), validator: (v) => (v == null || !v.contains('@')) ? 'Nhập email hợp lệ' : null),
                const SizedBox(height: 12),
                TextFormField(controller: _pass, obscureText: true, decoration: _dec('Mật khẩu'), validator: (v) => (v == null || v.length < 6) ? 'Tối thiểu 6 ký tự' : null),
                const SizedBox(height: 12),
                TextFormField(controller: _pass2, obscureText: true, decoration: _dec('Xác nhận mật khẩu'), validator: (v) => v != _pass.text ? 'Mật khẩu không khớp' : null),
                const SizedBox(height: 16),
                if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                FilledButton(onPressed: _busy ? null : _submit, child: const Padding(padding: EdgeInsets.all(12), child: Text('Đăng ký'))),
              ]),
            ),
          ),
        ),
      );
}
