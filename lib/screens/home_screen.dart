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
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRooms();
    });
  }

  Future<void> _loadRooms() async {
    final gameProvider = context.read<GameProvider>();
    try {
      await gameProvider.fetchRooms();
    } catch (e) {
      if (e.toString().contains('احراز هویت')) {
        context.read<AuthProvider>().logout();
      } else {
        _showSnackBar('خطا در دریافت اتاق‌ها: $e');
      }
    }
  }

  void _joinRoom(String roomName) {
    // استفاده از Future.microtask برای اجرای بعد از build phase
    Future.microtask(() async {
      final gameProvider = context.read<GameProvider>();
      try {
        await gameProvider.joinRoom(roomName);
        await gameProvider.connectToWebSocket(roomName);
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => const LobbyScreen(),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('خطا در پیوستن به اتاق: $e');
        }
      }
    });
  }

  void _handleLogout() {
    context.read<AuthProvider>().logout();
  }

  void _handleRefresh() {
    _loadRooms();
  }

  void _showSnackBar(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('اتاق‌های بازی'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleLogout,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _handleRefresh,
            ),
          ],
        ),
        body: Consumer<GameProvider>(
          builder: (context, gameProvider, child) {
            return gameProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : gameProvider.errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('خطا: ${gameProvider.errorMessage}'),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _handleRefresh,
                              child: const Text('تلاش مجدد'),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
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
                                          onPressed: () => _joinRoom(room.name),
                                          child: const Text('پیوستن'),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
          },
        ),
      ),
    );
  }
}