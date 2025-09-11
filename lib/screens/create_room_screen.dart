// lib/screens/create_room_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import 'lobby_screen.dart'; // بعداً می‌سازیم

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomNameController = TextEditingController();
  final _passwordController = TextEditingController();
  int _maxPlayers = 8;
  bool _isPrivate = false;

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await Provider.of<GameProvider>(context, listen: false).createRoom(
        _roomNameController.text,
        _maxPlayers,
        _isPrivate,
        _passwordController.text,
      );

      // بعد از ساخت اتاق موفق، به لابی برو
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (ctx) => const LobbyScreen(), // بعداً می‌سازیم
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در ساخت اتاق: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ساخت اتاق جدید')),
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'لطفاً نام اتاق را وارد کنید';
                    }
                    if (value.length < 3) {
                      return 'نام اتاق باید حداقل ۳ کاراکتر باشد';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _maxPlayers,
                  decoration: const InputDecoration(
                    labelText: 'تعداد بازیکنان',
                    border: OutlineInputBorder(),
                  ),
                  items: [4, 5, 6, 7, 8, 9, 10]
                      .map((number) => DropdownMenuItem(
                            value: number,
                            child: Text('$number نفر'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _maxPlayers = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('اتاق خصوصی'),
                  value: _isPrivate,
                  onChanged: (value) {
                    setState(() {
                      _isPrivate = value;
                    });
                  },
                ),
                if (_isPrivate) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'رمز عبور اتاق',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (_isPrivate && (value == null || value.isEmpty)) {
                        return 'برای اتاق خصوصی باید رمز عبور تعیین کنید';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text(
                    'ساخت اتاق',
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