// lib/screens/join_room_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import 'lobby_screen.dart'; // بعداً می‌سازیم

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomNameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPasswordField = false;

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await Provider.of<GameProvider>(context, listen: false).joinRoom(
        _roomNameController.text,
        _passwordController.text,
      );

      // بعد از پیوستن موفق، به لابی برو
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (ctx) => const LobbyScreen(), // بعداً می‌سازیم
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در پیوستن به اتاق: $e')),
      );
    }
  }

  void _checkRoomStatus() async {
    if (_roomNameController.text.isEmpty) return;

    // اینجا می‌توانی یک API برای بررسی وضعیت اتاق اضافه کنی
    // فعلاً فقط نمایش فیلد رمز عبور برای تست
    setState(() {
      _showPasswordField = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('پیوستن به اتاق')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _roomNameController,
                  decoration: const InputDecoration(
                    labelText: 'نام اتاق',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _checkRoomStatus(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'لطفاً نام اتاق را وارد کنید';
                    }
                    return null;
                  },
                ),
                if (_showPasswordField) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'رمز عبور (در صورت نیاز)',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text(
                    'پیوستن به اتاق',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}