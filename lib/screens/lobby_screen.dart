// lib/screens/lobby_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';

class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('لابی بازی'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            gameProvider.clearRoom();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (gameProvider.currentRoom != null)
              Text(
                'اتاق: ${gameProvider.currentRoom!.name}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 20),
            const Text('صفحه لابی - به زودی تکمیل می‌شود...'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // برگشت به صفحه اصلی
                gameProvider.clearRoom();
                Navigator.of(context).pop();
              },
              child: const Text('بازگشت به صفحه اصلی'),
            ),
          ],
        ),
      ),
    );
  }
}