import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/room_info.dart';
import '../services/room_service.dart';

class RoomTableScreen extends StatefulWidget {
  const RoomTableScreen({super.key});

  @override
  State<RoomTableScreen> createState() => _RoomTableScreenState();
}

class _RoomTableScreenState extends State<RoomTableScreen> with TickerProviderStateMixin {
  final RoomService _roomService = RoomService();
  RoomInfo? _roomInfo;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRoomInfo();
    });
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _loadRoomInfo();
      }
    });
  }

  Future<void> _loadRoomInfo() async {
    try {
      print('🔄 Loading room info...');
      final data = await _roomService.getRoomInfo();
      print('📊 Raw data: $data');
      
      final roomInfo = RoomInfo.fromJson(data as Map<String, dynamic>);
      
      if (mounted) {
        setState(() {
          _roomInfo = roomInfo;
          _isLoading = false;
          _errorMessage = null;
        });
        print('✅ Room info updated in state');
      }
    } catch (e) {
      print('❌ Error loading room info: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _toggleReady() async {
    try {
      await _roomService.toggleReady();
      _loadRoomInfo(); // Refresh after toggle
    } catch (e) {
      print('❌ Error toggling ready: $e');
    }
  }

  Future<void> _toggleMicrophone() async {
    try {
      await _roomService.toggleMicrophone();
      _loadRoomInfo(); // Refresh after toggle
    } catch (e) {
      print('❌ Error toggling microphone: $e');
    }
  }

  Future<void> _updateSeatPosition(int position) async {
    try {
      await _roomService.updateSeatPosition(position: position);
      _loadRoomInfo(); // Refresh after update
    } catch (e) {
      print('❌ Error updating seat position: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'خطا در بارگذاری اطلاعات اتاق',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadRoomInfo,
                child: const Text('تلاش مجدد'),
              ),
            ],
          ),
        ),
      );
    }

    if (_roomInfo == null) {
      return const Scaffold(
        body: Center(
          child: Text('اطلاعات اتاق یافت نشد'),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: _roomInfo!.scenario?.imageUrl != null
              ? DecorationImage(
                  image: NetworkImage(_roomInfo!.scenario!.imageUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with room info
              _buildHeader(),
              
              // Table with players
              Expanded(
                child: _buildTable(),
              ),
              
              // Controls
              _buildControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _roomInfo!.roomName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_roomInfo!.currentPlayers}/${_roomInfo!.maxPlayers} بازیکن',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          // Room status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(_roomInfo!.roomStatus),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getStatusText(_roomInfo!.roomStatus),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Center(
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          image: _roomInfo!.scenario?.tableImageUrl != null
              ? DecorationImage(
                  image: NetworkImage(_roomInfo!.scenario!.tableImageUrl!),
                  fit: BoxFit.cover,
                )
              : null,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.brown, width: 4),
        ),
        child: Stack(
          children: _buildPlayerSeats(),
        ),
      ),
    );
  }

  List<Widget> _buildPlayerSeats() {
    final players = _roomInfo!.players;
    final seatCount = _roomInfo!.maxPlayers;
    final positions = _generateSeatPositions(seatCount);
    
    List<Widget> seats = [];
    
    for (int i = 0; i < seatCount; i++) {
      final position = positions[i];
      PlayerInfo? player;
      try {
        player = players.firstWhere((p) => p.seatPosition == i);
      } catch (e) {
        player = null;
      }
      
      seats.add(
        Positioned(
          left: position['x']! * 300 - 30,
          top: position['y']! * 300 - 30,
          child: _buildPlayerSeat(player, i),
        ),
      );
    }
    
    return seats;
  }

  Widget _buildPlayerSeat(PlayerInfo? player, int seatIndex) {
    return GestureDetector(
      onTap: () => _updateSeatPosition(seatIndex),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: player != null ? Colors.blue : Colors.grey[300],
          shape: BoxShape.circle,
          border: Border.all(
            color: player?.isReady == true ? Colors.green : Colors.white,
            width: 3,
          ),
        ),
        child: player != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (player.avatarUrl != null)
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(player.avatarUrl!),
                    )
                  else
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blue[700],
                      child: Text(
                        player.username[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    player.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )
            : Icon(
                Icons.person_add,
                color: Colors.grey[600],
                size: 30,
              ),
      ),
    );
  }

  Widget _buildControls() {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUsername = authProvider.authData?.user.username;
    
    if (currentUsername == null) return const SizedBox.shrink();
    
    try {
      final currentPlayer = _roomInfo!.players.firstWhere(
        (p) => p.username == currentUsername,
      );
      
      return Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Ready button
            ElevatedButton.icon(
              onPressed: _toggleReady,
              icon: Icon(currentPlayer.isReady ? Icons.check_circle : Icons.radio_button_unchecked),
              label: Text(currentPlayer.isReady ? 'آماده' : 'آماده نیستم'),
              style: ElevatedButton.styleFrom(
                backgroundColor: currentPlayer.isReady ? Colors.green : Colors.grey,
                foregroundColor: Colors.white,
              ),
            ),
            
            // Microphone button
            ElevatedButton.icon(
              onPressed: _toggleMicrophone,
              icon: Icon(currentPlayer.isMicrophoneOn ? Icons.mic : Icons.mic_off),
              label: Text(currentPlayer.isMicrophoneOn ? 'میکروفون روشن' : 'میکروفون خاموش'),
              style: ElevatedButton.styleFrom(
                backgroundColor: currentPlayer.isMicrophoneOn ? Colors.red : Colors.grey,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  List<Map<String, double>> _generateSeatPositions(int count) {
    List<Map<String, double>> positions = [];
    for (int i = 0; i < count; i++) {
      final angle = (2 * pi * i) / count - pi / 2; // Start from top
      final x = 0.5 + 0.35 * cos(angle);
      final y = 0.5 + 0.35 * sin(angle);
      positions.add({'x': x, 'y': y});
    }
    return positions;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'waiting':
        return Colors.orange;
      case 'ready':
        return Colors.green;
      case 'in_progress':
        return Colors.red;
      case 'finished':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'waiting':
        return 'در انتظار';
      case 'ready':
        return 'آماده';
      case 'in_progress':
        return 'در حال بازی';
      case 'finished':
        return 'تمام شده';
      default:
        return 'نامشخص';
    }
  }
}
