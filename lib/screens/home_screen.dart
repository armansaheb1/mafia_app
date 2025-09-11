// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/auth_provider.dart';
import 'create_room_screen.dart';
import 'join_room_screen.dart';
import 'lobby_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      await Provider.of<GameProvider>(context, listen: false).fetchRooms();
    } catch (e) {
      // اگر خطای احراز هویت بود، کاربر را به صفحه لاگین ببر
      if (e.toString().contains('احراز هویت')) {
        Provider.of<AuthProvider>(context, listen: false).logout();
        // Navigator.pushReplacementNamed(context, '/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در دریافت اتاق‌ها: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('اتاق‌های بازی'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authProvider.logout();
              // Navigator.pushReplacementNamed(context, '/login');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRooms,
          ),
        ],
      ),
      body: gameProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : gameProvider.errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('خطا: ${gameProvider.errorMessage}'),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loadRooms,
                        child: const Text('تلاش مجدد'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // دکمه‌های اصلی...
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => const CreateRoomScreen(),
                                ),
                              );
                            },
                            child: const Text('ساخت اتاق جدید'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => const JoinRoomScreen(),
                                ),
                              );
                            },
                            child: const Text('پیوستن به اتاق'),
                          ),
                        ],
                      ),
                    ),
                    // لیست اتاق‌ها...
                    Expanded(
                      child: gameProvider.rooms.isEmpty
                          ? const Center(
                              child: Text('هیچ اتاقی موجود نیست'),
                            )
                          : ListView.builder(
                              itemCount: gameProvider.rooms.length,
                              itemBuilder: (ctx, index) {
                                final room = gameProvider.rooms[index];
                                return ListTile(
                                  title: Text(room.name),
                                  subtitle: Text(
                                      'سازنده: ${room.hostName} - بازیکنان: ${room.currentPlayers}/${room.maxPlayers}'),
                                  trailing: ElevatedButton(
                                    onPressed: () async {
                                      try {
                                        await gameProvider.joinRoom(room.name);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (ctx) => const LobbyScreen(),
                                          ),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('خطا: $e')),
                                        );
                                      }
                                    },
                                    child: const Text('پیوستن'),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}