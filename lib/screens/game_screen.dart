import 'package:flutter/material.dart';
import 'package:mafia_app/models/user.dart';
import 'package:mafia_app/screens/lobby_screen.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/auth_provider.dart';
import '../models/player.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();
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
    _gameProvider?.addListener(_onGameStateChanged);
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

  void _leaveGame() {
    _gameProvider?.leaveRoom();
    if (mounted && !_isDisposed) {
      Navigator.pop(context);
    }
  }

  void _performVote(String targetUsername) {
    _gameProvider?.sendVote(targetUsername);
  }

  void _performNightAction(String actionType, String targetUsername) {
    _gameProvider?.sendNightAction(actionType, targetUsername);
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
    final currentPhase = gameProvider.currentPhase;

    return Scaffold(
      appBar: AppBar(
        title: const Text('بازی مافیا'),
        automaticallyImplyLeading: false,
      ),
      body: WillPopScope(
        onWillPop: () async => false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        _getPhaseName(gameProvider.currentPhase),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _getPhaseColor(gameProvider.currentPhase ?? ''),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('روز: ${gameProvider.currentGameState?.dayNumber ?? 1}'),
                      if (currentUser != null && gameProvider.userRole != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'نقش شما: ${_getRoleName(gameProvider.userRole!)}',
                          style: TextStyle(
                            color: _getRoleColor(gameProvider.userRole!),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getRoleDescription(gameProvider.userRole!),
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              color: _getPhaseColor(gameProvider.currentPhase ?? '').withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getPhaseDescription(gameProvider.currentPhase ?? ''),
                    style: TextStyle(
                      color: _getPhaseColor(gameProvider.currentPhase ?? ''),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (gameProvider.hasVoted || gameProvider.hasNightAction)
                    const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
            ),

            Expanded(
              flex: 2,
              child: gameProvider.currentPlayers.isEmpty
                ? const Center(child: Text('هیچ بازیکنی وجود ندارد'))
                : ListView.builder(
                    itemCount: gameProvider.currentPlayers.length,
                    itemBuilder: (context, index) {
                      final player = gameProvider.currentPlayers[index];
                      return _buildPlayerTile(gameProvider, player, currentUser);
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
                          Text('چت بازی'),
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

            if (currentPhase == 'night') 
              _buildNightActions(gameProvider),
            
            if (currentPhase == 'day') 
              _buildDayActions(gameProvider),
            if (gameProvider.currentPhase == 'finished') 
  Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: ElevatedButton.icon(
      onPressed: () {
        gameProvider.returnToLobby();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (ctx) => const LobbyScreen()),
            );
          },
          icon: const Icon(Icons.group),
          label: const Text('بازگشت به لابی'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _leaveGame,
                icon: const Icon(Icons.exit_to_app),
                label: const Text('خروج از بازی'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerTile(GameProvider gameProvider, Player player, User? currentUser) {
    final isCurrentUser = player.username == currentUser?.username;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: player.isAlive 
          ? _getRoleColor(player.role)
          : Colors.grey,
        child: Text(
          player.username[0],
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(
        player.username,
        style: TextStyle(
          color: player.isAlive ? Colors.black : Colors.grey,
          decoration: player.isAlive ? null : TextDecoration.lineThrough,
          fontWeight: isCurrentUser ? FontWeight.bold : null,
        ),
      ),
      subtitle: isCurrentUser 
        ? const Text('شما') 
        : Text(player.isAlive ? _getRoleStatus(player.role) : 'مرده'),
      trailing: _buildActionButtons(gameProvider, player, currentUser),
    );
  }

  Widget? _buildActionButtons(GameProvider gameProvider, Player player, User? currentUser) {
    if (!player.isAlive || player.username == currentUser?.username) {
      return null;
    }

    if (gameProvider.currentPhase == 'night' && gameProvider.canPerformNightAction()) {
      return IconButton(
        icon: Icon(_getNightActionIcon(gameProvider.userRole)),
        onPressed: () => _performNightAction(
          _getNightActionType(gameProvider.userRole),
          player.username
        ),
        tooltip: _getNightActionTooltip(gameProvider.userRole),
      );
    }

    if (gameProvider.currentPhase == 'day' && gameProvider.canVote()) {
      return IconButton(
        icon: const Icon(Icons.how_to_vote),
        onPressed: () => _performVote(player.username),
        tooltip: 'رای دادن',
      );
    }

    return null;
  }

  Widget _buildNightActions(GameProvider gameProvider) {
    if (!gameProvider.canPerformNightAction()) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        _getNightActionInstruction(gameProvider.userRole),
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDayActions(GameProvider gameProvider) {
    if (!gameProvider.canVote()) return const SizedBox();

    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Text(
        'به کسی که فکر می‌کنید مافیا است رای دهید',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  String _getPhaseName(String? phase) {
    switch (phase) {
      case 'night': return 'شب';
      case 'day': return 'روز';
      case 'voting': return 'رای‌گیری';
      case 'finished': return 'پایان بازی';
      default: return 'در انتظار';
    }
  }

  String _getRoleName(String? role) {
    switch (role) {
      case 'mafia': return 'مافیا';
      case 'detective': return 'کارآگاه';
      case 'doctor': return 'دکتر';
      case 'citizen': return 'شهروند';
      default: return 'نقش نامشخص';
    }
  }

  Color _getPhaseColor(String phase) {
    switch (phase) {
      case 'night': return Colors.blue[800]!;
      case 'day': return Colors.orange[800]!;
      case 'voting': return Colors.red[800]!;
      case 'finished': return Colors.green[800]!;
      default: return Colors.grey;
    }
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'mafia': return Colors.red;
      case 'detective': return Colors.blue;
      case 'doctor': return Colors.green;
      case 'citizen': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _getPhaseDescription(String phase) {
    switch (phase) {
      case 'night': return 'شب است. همه چشم‌ها بسته...';
      case 'day': return 'روز است. بحث کنید و رای دهید.';
      case 'voting': return 'زمان رای‌گیری نهایی';
      case 'finished': return 'بازی به پایان رسیده است';
      default: return 'در حال انتظار...';
    }
  }

  String _getRoleDescription(String? role) {
    switch (role) {
      case 'mafia': return 'شب‌ها یک نفر را می‌کشید';
      case 'detective': return 'شب‌ها نقش یک نفر را کشف می‌کنید';
      case 'doctor': return 'شب‌ها یک نفر را درمان می‌کنید';
      case 'citizen': return 'باید مافیایی‌ها را پیدا کنید';
      default: return 'نقش نامشخص';
    }
  }

  String _getRoleStatus(String? role) {
    if (role == null) return 'نقش نامشخص';
    return _getRoleName(role);
  }

  IconData _getNightActionIcon(String? role) {
    switch (role) {
      case 'mafia': return Icons.nightlight_round;
      case 'detective': return Icons.search;
      case 'doctor': return Icons.healing;
      default: return Icons.question_mark;
    }
  }

  String _getNightActionTooltip(String? role) {
    switch (role) {
      case 'mafia': return 'کشتن این بازیکن';
      case 'detective': return 'تحقیق درباره این بازیکن';
      case 'doctor': return 'درمان این بازیکن';
      default: return 'عمل شبانه';
    }
  }

  String _getNightActionInstruction(String? role) {
    switch (role) {
      case 'mafia': return 'شب است. یک نفر را برای کشتن انتخاب کنید.';
      case 'detective': return 'شب است. یک نفر را برای تحقیق انتخاب کنید.';
      case 'doctor': return 'شب است. یک نفر را برای درمان انتخاب کنید.';
      default: return 'شب است. در خواب هستید...';
    }
  }

  String _getNightActionType(String? role) {
    switch (role) {
      case 'mafia': return 'kill';
      case 'detective': return 'investigate';
      case 'doctor': return 'heal';
      default: return '';
    }
  }
}