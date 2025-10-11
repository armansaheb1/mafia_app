import 'package:flutter/material.dart';
import '../models/scenario.dart';
import '../models/player.dart';
import '../services/game_logic_service.dart';
import '../services/role_ability_service.dart';

class GameManagementScreen extends StatefulWidget {
  final Scenario scenario;
  final List<Player> players;

  const GameManagementScreen({
    super.key,
    required this.scenario,
    required this.players,
  });

  @override
  State<GameManagementScreen> createState() => _GameManagementScreenState();
}

class _GameManagementScreenState extends State<GameManagementScreen> {
  List<Player> _players = [];
  String _currentPhase = 'night';
  final int _dayNumber = 1;
  String? _winner;

  @override
  void initState() {
    super.initState();
    _players = GameLogicService.assignRoles(widget.players, widget.scenario);
  }

  @override
  Widget build(BuildContext context) {
    final gameInfo = GameLogicService.getGameInfo(_players);

    return Scaffold(
      appBar: AppBar(
        title: Text('مدیریت بازی - ${widget.scenario.name}'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _showGameInfo,
            icon: const Icon(Icons.info),
            tooltip: 'اطلاعات بازی',
          ),
        ],
      ),
      body: Column(
        children: [
          // اطلاعات کلی بازی
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoCard('روز', '$_dayNumber', Icons.wb_sunny),
                _buildInfoCard('فاز', (_currentPhase == 'night' || _currentPhase == 'mafia_night') ? 'شب' : 'روز', 
                  (_currentPhase == 'night' || _currentPhase == 'mafia_night') ? Icons.nightlight : Icons.wb_sunny),
                _buildInfoCard('زنده', '${gameInfo['alive_players']}', Icons.people),
                _buildInfoCard('مافیا', '${gameInfo['mafia_count']}', Icons.dangerous),
              ],
            ),
          ),

          // لیست بازیکنان
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _players.length,
              itemBuilder: (context, index) {
                final player = _players[index];
                return _buildPlayerCard(player);
              },
            ),
          ),

          // دکمه‌های کنترل
          if (_winner == null)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _currentPhase == 'night' ? _endNight : _startNight,
                      icon: Icon(_currentPhase == 'night' ? Icons.wb_sunny : Icons.nightlight),
                      label: Text(_currentPhase == 'night' ? 'پایان شب' : 'شروع شب'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentPhase == 'night' ? Colors.orange : Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _currentPhase == 'day' ? _startVoting : _startDay,
                      icon: const Icon(Icons.how_to_vote),
                      label: const Text('رای‌گیری'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // نمایش برنده
          if (_winner != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: _winner == 'mafia' ? Colors.red : Colors.blue,
              child: Row(
                children: [
                  Icon(
                    _winner == 'mafia' ? Icons.dangerous : Icons.celebration,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _winner == 'mafia' ? 'مافیا برنده شد!' : 'شهروندان برنده شدند!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerCard(Player player) {
    final role = player.role;
    final isAlive = player.isAlive;
    final roleColor = role != null ? _getRoleColor(role.roleType) : Colors.grey;
    final roleIcon = role != null ? RoleAbilityService.getRoleIcon(role) : Icons.help;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isAlive ? null : Colors.grey[300],
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAlive ? roleColor : Colors.grey,
          child: Icon(
            roleIcon,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          player.username,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isAlive ? null : Colors.grey,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (role != null)
              Text(
                role.displayName,
                style: TextStyle(
                  color: isAlive ? roleColor : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (role != null && role.description.isNotEmpty)
              Text(
                role.description,
                style: TextStyle(
                  fontSize: 12,
                  color: isAlive ? Colors.grey[600] : Colors.grey,
                ),
              ),
            if (!isAlive)
              const Text(
                'مرده',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: isAlive
            ? IconButton(
                onPressed: () => _killPlayer(player),
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'کشتن بازیکن',
              )
            : IconButton(
                onPressed: () => _revivePlayer(player),
                icon: const Icon(Icons.refresh, color: Colors.green),
                tooltip: 'احیای بازیکن',
              ),
      ),
    );
  }

  Color _getRoleColor(String roleType) {
    switch (roleType) {
      case 'town':
        return Colors.blue;
      case 'mafia':
        return Colors.red;
      case 'neutral':
        return Colors.orange;
      case 'special':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _killPlayer(Player player) {
    setState(() {
      _players = _players.map((p) => 
        p.username == player.username ? p.copyWith(isAlive: false) : p
      ).toList();
      
      _winner = GameLogicService.checkWinCondition(_players);
    });
  }

  void _revivePlayer(Player player) {
    setState(() {
      _players = _players.map((p) => 
        p.username == player.username ? p.copyWith(isAlive: true) : p
      ).toList();
      
      _winner = GameLogicService.checkWinCondition(_players);
    });
  }

  void _startNight() {
    setState(() {
      _currentPhase = 'night';
    });
  }

  void _endNight() {
    setState(() {
      _currentPhase = 'day';
    });
  }

  void _startDay() {
    setState(() {
      _currentPhase = 'day';
    });
  }

  void _startVoting() {
    // منطق رای‌گیری
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رای‌گیری'),
        content: const Text('رای‌گیری شروع شد!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('باشه'),
          ),
        ],
      ),
    );
  }

  void _showGameInfo() {
    final gameInfo = GameLogicService.getGameInfo(_players);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اطلاعات بازی'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تعداد کل بازیکنان: ${gameInfo['total_players']}'),
            Text('بازیکنان زنده: ${gameInfo['alive_players']}'),
            Text('مافیا زنده: ${gameInfo['mafia_count']}'),
            Text('شهروندان زنده: ${gameInfo['town_count']}'),
            Text('خنثی زنده: ${gameInfo['neutral_count']}'),
            if (gameInfo['winner'] != null)
              Text('برنده: ${gameInfo['winner']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('باشه'),
          ),
        ],
      ),
    );
  }
}
