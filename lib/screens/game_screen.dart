import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../models/player.dart';
import '../models/game_state.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _isDisposed = false;
  GameProvider? _gameProvider;
  String? _selectedPlayerForVote;
  String? _selectedPlayerForAction;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gameProvider = Provider.of<GameProvider>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    _gameProvider?.addListener(_onGameStateChanged);
    _refreshGameInfo();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _gameProvider?.removeListener(_onGameStateChanged);
    super.dispose();
  }

  void _onGameStateChanged() {
    if (mounted && !_isDisposed) {
      setState(() {});
    }
  }

  Future<void> _refreshGameInfo() async {
    await _gameProvider?.refreshGameInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, gameProvider, child) {
        final gameState = gameProvider.currentGameState;
        final currentPhase = gameProvider.currentPhase;
        final currentRoom = gameProvider.currentRoom;

        if (gameState == null || currentRoom == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // مستقیماً به میز بازی برو
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/game-table');
        });

        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  Widget _buildGameInfoCard(GameState gameState) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem('روز', '${gameState.dayNumber}'),
                _buildInfoItem('فاز', _getPhaseTitle(gameState.phase)),
                _buildInfoItem('بازیکنان زنده', '${gameState.players.length}'),
                if (gameState.playerRole != null)
                  _buildInfoItem('نقش شما', gameState.playerRole!),
              ],
            ),
            if (gameState.phaseTimeRemaining > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: gameState.phase == 'night' 
                          ? gameState.phaseTimeRemaining / 30  // 30 ثانیه برای شب
                          : gameState.phaseTimeRemaining / 300, // 5 دقیقه برای روز
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        gameState.phase == 'night' ? Colors.blue : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${gameState.phaseTimeRemaining} ثانیه باقی مانده',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildNightPhase(GameState gameState) {
    return Column(
      children: [
        // لیست بازیکنان برای اقدامات شب
        Expanded(
          child: _buildPlayersList(
            gameState.players,
            onPlayerSelected: (player) {
              setState(() {
                _selectedPlayerForAction = player.username;
              });
            },
            selectedPlayer: _selectedPlayerForAction,
            showRole: false,
          ),
        ),
        
        // دکمه‌های اقدامات شب
        _buildNightActions(gameState),
      ],
    );
  }

  Widget _buildDayPhase(GameState gameState) {
    return Column(
      children: [
        // لیست بازیکنان برای رای‌گیری
        Expanded(
          child: _buildPlayersList(
            gameState.players,
            onPlayerSelected: (player) {
              setState(() {
                _selectedPlayerForVote = player.username;
              });
            },
            selectedPlayer: _selectedPlayerForVote,
            showRole: false,
          ),
        ),
        
        // دکمه رای‌گیری
        _buildVotingActions(gameState),
      ],
    );
  }

  Widget _buildPlayersList(
    List<Player> players, {
    required Function(Player) onPlayerSelected,
    String? selectedPlayer,
    required bool showRole,
  }) {
    return ListView.builder(
      itemCount: players.length,
      itemBuilder: (context, index) {
        final player = players[index];
        final isSelected = selectedPlayer == player.username;
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: isSelected ? Colors.blue.withOpacity(0.3) : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: player.isAlive ? Colors.green : Colors.red,
              child: Text(
                player.username[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(player.username),
            subtitle: showRole && player.role != null
                ? Text('نقش: ${player.role}')
                : null,
            trailing: player.isAlive
                ? const Icon(Icons.person, color: Colors.green)
                : const Icon(Icons.person_off, color: Colors.red),
            onTap: player.isAlive ? () => onPlayerSelected(player) : null,
          ),
        );
      },
    );
  }

  Widget _buildNightActions(GameState gameState) {
    final playerRole = gameState.playerRole;
    
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'اقدامات شب',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            if (playerRole == 'mafia')
              _buildActionButton(
                'قتل مافیا',
                'mafia_kill',
                Icons.dangerous,
                Colors.red,
              ),
            
            if (playerRole == 'doctor')
              _buildActionButton(
                'نجات دکتر',
                'doctor_save',
                Icons.medical_services,
                Colors.green,
              ),
            
            if (playerRole == 'detective')
              _buildActionButton(
                'تحقیق کارآگاه',
                'detective_investigate',
                Icons.search,
                Colors.blue,
              ),
            
            if (playerRole == 'sheriff')
              _buildActionButton(
                'دستگیری کلانتر',
                'sheriff_arrest',
                Icons.gavel,
                Colors.orange,
              ),
            
            if (playerRole == 'mayor')
              _buildActionButton(
                'افشای شهردار',
                'mayor_reveal',
                Icons.campaign,
                Colors.purple,
              ),
            
            if (playerRole == 'citizen' || playerRole == null)
              const Text(
                'شما شهروند عادی هستید. منتظر بمانید...',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    String actionType,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _selectedPlayerForAction != null
              ? () => _performNightAction(actionType)
              : null,
          icon: Icon(icon),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildVotingActions(GameState gameState) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'رای‌گیری روز',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            if (_selectedPlayerForVote != null)
              Text(
                'شما به $_selectedPlayerForVote رای می‌دهید',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedPlayerForVote != null
                    ? () => _performVote()
                    : null,
                icon: const Icon(Icons.how_to_vote),
                label: const Text('ارسال رای'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _performVote() async {
    if (_selectedPlayerForVote != null) {
      await _gameProvider?.sendVote(_selectedPlayerForVote!);
      setState(() {
        _selectedPlayerForVote = null;
      });
    }
  }

  Future<void> _performNightAction(String actionType) async {
    if (_selectedPlayerForAction != null) {
      await _gameProvider?.sendNightAction(
        actionType,
        targetUsername: _selectedPlayerForAction,
      );
      setState(() {
        _selectedPlayerForAction = null;
      });
    }
  }

  void _showEndPhaseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('پایان فاز'),
        content: const Text('آیا مطمئن هستید که می‌خواهید فاز فعلی را به پایان برسانید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لغو'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _gameProvider?.endPhase();
            },
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
  }

  String _getPhaseTitle(String? phase) {
    switch (phase) {
      case 'night':
        return 'شب';
      case 'day':
        return 'روز';
      case 'voting':
        return 'رای‌گیری';
      case 'finished':
        return 'تمام شده';
      default:
        return 'در انتظار';
    }
  }
}