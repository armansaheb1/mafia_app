import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/auth_provider.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isReady = false;
  bool _isDisposed = false;
  GameProvider? _gameProvider;
  AuthProvider? _authProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gameProvider = Provider.of<GameProvider>(context, listen: false);
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    _setupWebSocket();
  }

  void _setupWebSocket() {
    final room = _gameProvider?.currentRoom;
    
    if (room != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await _gameProvider?.connectToWebSocket(room.name);
          _gameProvider?.addListener(_onGameStateChanged);
        } catch (e) {
          if (mounted && !_isDisposed) {
            _showSnackBar('خطا در اتصال: $e');
          }
        }
      });
    }
  }

  void _onGameStateChanged() {
  if (mounted && !_isDisposed) {
    setState(() {});
    _scrollChatToBottom();
  }
}


  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _sendChatMessage() {
    if (_chatController.text.trim().isEmpty) return;
    
    _gameProvider?.sendChatMessage(_chatController.text.trim());
    _chatController.clear();
    _scrollChatToBottom();
  }

  void _toggleReady() {
    if (_isDisposed) return;
    
    setState(() {
      _isReady = !_isReady;
    });
    _gameProvider?.sendReadyStatus();
  }

  void _startGame() {
    _gameProvider?.startGame();
    
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && !_isDisposed) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (ctx) => const GameScreen()),
        );
      }
    });
  }

  Future<void> _leaveRoom() async {
    await _gameProvider?.leaveRoom();
    
    if (mounted && !_isDisposed) {
      Navigator.pop(context);
    }
  }

  void _showSnackBar(String message) {
    if (mounted && !_isDisposed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _testStartGame() {
    _gameProvider?.testStartGame();
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (ctx) => const GameScreen()),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _chatController.dispose();
    _scrollController.dispose();
    _gameProvider?.removeListener(_onGameStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.authData?.user;
    final isHost = gameProvider.isRoomHost(currentUser?.username ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('لابی بازی'),
        automaticallyImplyLeading: false,
        actions: [
          if (isHost && gameProvider.canStartGame())
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'شروع بازی',
              onPressed: _startGame,
            ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _leaveRoom,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      gameProvider.currentRoom?.name ?? 'اتاق',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'بازیکنان: ${gameProvider.currentPlayers.length}/${gameProvider.currentRoom?.maxPlayers ?? 8}',
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          gameProvider.isWebSocketConnected 
                            ? Icons.wifi 
                            : Icons.wifi_off,
                          color: gameProvider.isWebSocketConnected 
                            ? Colors.green 
                            : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          gameProvider.isWebSocketConnected ? 'متصل' : 'قطع',
                          style: TextStyle(
                            color: gameProvider.isWebSocketConnected 
                              ? Colors.green 
                              : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('وضعیت آماده‌باش:'),
                Switch(
                  value: _isReady,
                  onChanged: (value) => _toggleReady(),
                ),
                Text(_isReady ? 'آماده' : 'آماده نیستم'),
              ],
            ),
          ),

          if (gameProvider.canStartGame() && isHost)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'اتاق کامل شد! می‌توانید بازی را شروع کنید',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          Expanded(
            flex: 2,
            child: gameProvider.currentPlayers.isEmpty
              ? const Center(child: Text('هیچ بازیکنی در اتاق نیست'))
              : ListView.builder(
                  itemCount: gameProvider.currentPlayers.length,
                  itemBuilder: (context, index) {
                    final player = gameProvider.currentPlayers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: player.isReady ? Colors.green : Colors.grey,
                        child: Text(
                          player.username[0],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        player.username,
                        style: TextStyle(
                          fontWeight: player.username == currentUser?.username 
                            ? FontWeight.bold 
                            : null,
                        ),
                      ),
                      trailing: Icon(
                        player.isReady ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: player.isReady ? Colors.green : Colors.grey,
                      ),
                      subtitle: player.username == currentUser?.username 
                        ? const Text('شما') 
                        : null,
                    );
                  },
                ),
          ),

          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8.0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.chat, size: 16),
                        SizedBox(width: 4),
                        Text('چت اتاق'),
                      ],
                    ),
                  ),

                  Expanded(
                    child: gameProvider.chatMessages.isEmpty
                      ? const Center(child: Text('هیچ پیامی وجود ندارد'))
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: gameProvider.chatMessages.length,
                          itemBuilder: (context, index) {
                            final message = gameProvider.chatMessages[index];
                            return ListTile(
                              title: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${message['username']}: ',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(text: message['message']),
                                  ],
                                ),
                              ),
                              dense: true,
                            );
                          },
                        ),
                  ),

                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            decoration: InputDecoration(
                              hintText: 'پیام...',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.send),
                                onPressed: _sendChatMessage,
                                iconSize: 20,
                              ),
                            ),
                            onSubmitted: (_) => _sendChatMessage(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (gameProvider.currentPlayers.length >= 2) ...[
                  ElevatedButton(
                    onPressed: _testStartGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('تست شروع بازی (2 نفر)'),
                  ),
                  const SizedBox(height: 8),
                ],

                ElevatedButton.icon(
                  onPressed: _leaveRoom,
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('خروج از اتاق'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}