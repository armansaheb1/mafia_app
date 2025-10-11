// lib/screens/scenario_slider_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/game_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../models/scenario.dart';
import '../services/scenario_service.dart';
import '../services/image_optimization_service.dart';
import 'create_room_screen.dart';
import 'join_room_screen.dart';

class ScenarioSliderScreen extends StatefulWidget {
  const ScenarioSliderScreen({super.key});

  @override
  State<ScenarioSliderScreen> createState() => _ScenarioSliderScreenState();
}

class _ScenarioSliderScreenState extends State<ScenarioSliderScreen> {
  final PageController _pageController = PageController();
  List<Scenario> scenarios = [];
  int currentIndex = 0;
  bool isLoading = true;
  String? error;
  Map<String, List<dynamic>> scenarioRooms = {};

  // تصاویر پس‌زمینه کل اپ برای هر سناریو (ابعاد بهینه 1920x1080)
  final Map<String, String> appBackgrounds = {
    'شب‌های مافیا (کلاسیک تلویزیونی)': 'https://picsum.photos/1920/1080?random=1',
    'پدرخوانده (Godfather Show)': 'https://picsum.photos/1920/1080?random=2',
    'شب‌های مافیا (با فراماسون‌ها)': 'https://picsum.photos/1920/1080?random=3',
    'نسخه اینترنتی (10 نفره)': 'https://picsum.photos/1920/1080?random=4',
    'کلاسیک ساده': 'https://picsum.photos/1920/1080?random=5',
    'تیم بزرگ پیشرفته': 'https://picsum.photos/1920/1080?random=6',
  };

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _loadScenarios();
    await _loadLastScenario();
    
    // اطمینان از اینکه بک‌گراند اولیه لود شده است
    if (mounted && scenarios.isNotEmpty) {
      _updateAppBackground();
    }
  }

  Future<void> _loadScenarios() async {
    try {
      final loadedScenarios = await ScenarioService.getScenarios();
      
      if (mounted) {
        setState(() {
          scenarios = loadedScenarios;
          isLoading = false;
        });
      }
      
      // بارگذاری روم‌ها پس از بارگذاری سناریوها
      await _loadRoomsForAllScenarios();
      
      // اطمینان از اینکه UI به‌روزرسانی شده است
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadRoomsForAllScenarios() async {
    try {
      final gameProvider = context.read<GameProvider>();
      await gameProvider.fetchRooms();
      
      Map<String, List<dynamic>> roomsByScenario = {};
      for (final room in gameProvider.rooms) {
        if (room.scenario != null) {
          final scenarioName = room.scenario!.name;
          if (!roomsByScenario.containsKey(scenarioName)) {
            roomsByScenario[scenarioName] = [];
          }
          roomsByScenario[scenarioName]!.add(room);
        }
      }
      
      if (mounted) {
        setState(() {
          scenarioRooms = roomsByScenario;
        });
      }
    } catch (e) {
      print('خطا در بارگذاری اتاق‌ها: $e');
    }
  }

  Future<void> _loadLastScenario() async {
    // اطمینان از اینکه scenarios بارگذاری شده‌اند
    if (scenarios.isEmpty) {
      print('⚠️ Scenarios not loaded yet, skipping last scenario load');
      return;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final lastScenarioIndex = prefs.getInt('last_scenario_index');
    
    if (lastScenarioIndex != null && lastScenarioIndex < scenarios.length) {
      // برای اسلاید بی‌نهایت، به وسط اضافه کن
      final infiniteIndex = lastScenarioIndex + (scenarios.length * 1000);
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pageController.animateToPage(
            infiniteIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Future<void> _saveLastScenario(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_scenario_index', index);
  }

  void _onPageChanged(int index) {
    final actualIndex = index % scenarios.length;
    if (mounted) {
      setState(() {
        currentIndex = actualIndex;
      });
    }
    _saveLastScenario(actualIndex);
    _updateAppBackground();
  }

  void _updateAppBackground() {
    if (currentIndex < scenarios.length && scenarios.isNotEmpty) {
      final scenario = scenarios[currentIndex];
      final themeProvider = context.read<ThemeProvider>();
      
      // استفاده از عکس بک‌اند اگر موجود باشد، در غیر این صورت از عکس پیش‌فرض
      String backgroundUrl;
      if (scenario.imageUrl != null && scenario.imageUrl!.isNotEmpty) {
        // بهینه‌سازی URL عکس
        backgroundUrl = ImageOptimizationService.getOptimizedImageUrl(
          scenario.imageUrl!,
          quality: 'high',
        );
      } else {
        // عکس‌های پیش‌فرض با ابعاد بهینه
        backgroundUrl = appBackgrounds[scenario.name] ?? 
            'https://picsum.photos/1920/1080?random=0';
      }
      
      print('🖼️ Updating background for scenario: ${scenario.name}');
      themeProvider.updateBackground(backgroundUrl);
      
      // اطمینان از به‌روزرسانی UI
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1a1a1a),
                Color(0xFF2C2C2C),
              ],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
                ),
                SizedBox(height: 16),
                Text(
                  'در حال بارگذاری سناریوها...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (error != null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1a1a1a),
                Color(0xFF2C2C2C),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'خطا در بارگذاری: $error',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadScenarios,
                  child: const Text('تلاش مجدد'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          body: Container(
            decoration: themeProvider.hasBackground
                ? BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(themeProvider.currentBackgroundImage!),
                      fit: BoxFit.cover,
                      alignment: currentIndex < scenarios.length 
                          ? ImageOptimizationService.getOptimalAlignment(scenarios[currentIndex].name)
                          : Alignment.center,
                      onError: (exception, stackTrace) {
                        print('خطا در لود عکس پس‌زمینه: $exception');
                      },
                    ),
                  )
                : const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF1a1a1a),
                        Color(0xFF2C2C2C),
                      ],
                    ),
                  ),
            child: Container(
              // پرده شفاف تاریک برای افزایش کنتراست
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Header
                    _buildHeader(),
                    
                    // PageView برای سناریوها (بی‌نهایت)
                    Expanded(
                      child: Stack(
                        children: [
                          PageView.builder(
                            controller: _pageController,
                            onPageChanged: _onPageChanged,
                            itemCount: null, // بی‌نهایت
                            itemBuilder: (context, index) {
                              final actualIndex = index % scenarios.length;
                              return _buildScenarioPage(scenarios[actualIndex]);
                            },
                          ),
                          
                          // نشانگرهای اسلاید
                          _buildSlideIndicators(),
                          
                          // آیکون‌های اسلاید در گوشه‌ها
                          _buildSlideArrows(),
                        ],
                      ),
                    ),
                    
                    // Bottom Actions
                    _buildBottomActions(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSlideIndicators() {
    if (scenarios.isEmpty) return const SizedBox.shrink();
    
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // متن راهنما
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFFD700).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: const Text(
              'اسلاید کنید',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // نشانگرهای نقطه‌ای
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(scenarios.length, (index) {
              final isActive = index == currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive 
                      ? const Color(0xFFFFD700) 
                      : const Color(0xFFFFD700).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: isActive ? [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ] : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideArrows() {
    return Positioned(
      top: 0,
      bottom: 0,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // فلش چپ
          Container(
            margin: const EdgeInsets.only(left: 16),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 2000),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return AnimatedOpacity(
                  opacity: 0.4 + (0.2 * value),
                  duration: const Duration(milliseconds: 300),
                  child: Transform.translate(
                    offset: Offset(-5 * (1 - value), 0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Color(0xFFFFD700),
                        size: 24,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // فلش راست
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 2000),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return AnimatedOpacity(
                  opacity: 0.4 + (0.2 * value),
                  duration: const Duration(milliseconds: 300),
                  child: Transform.translate(
                    offset: Offset(5 * (1 - value), 0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Color(0xFFFFD700),
                        size: 24,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          // دکمه ریفرش (سمت چپ)
          IconButton(
            onPressed: _loadScenarios,
            icon: const Icon(Icons.refresh, color: Color(0xFFFFD700)),
            tooltip: 'تازه‌سازی',
          ),
          
          // نام سناریو (وسط)
          Expanded(
            child: Text(
              currentIndex < scenarios.length ? scenarios[currentIndex].name : '',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFFFFD700),
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          
          // دکمه خروج (سمت راست)
          IconButton(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout, color: Color(0xFFFFD700)),
            tooltip: 'خروج',
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioPage(Scenario scenario) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        
        return SingleChildScrollView(
          padding: EdgeInsets.all(isLandscape ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // فاصله برای جای آیکون حذف شده
              SizedBox(height: isLandscape ? 20 : MediaQuery.of(context).size.height * 0.3),
              
              // Description
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  scenario.description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatChip(
                    Icons.people,
                    '${scenario.minPlayers}-${scenario.maxPlayers} بازیکن',
                    const Color(0xFF4CAF50),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Rooms for this scenario
              if (scenarioRooms.containsKey(scenario.name) && scenarioRooms[scenario.name]!.isNotEmpty) ...[
                Text(
                  'اتاق‌های موجود',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: isLandscape ? 200 : 300,
                  child: _buildRoomsList(scenarioRooms[scenario.name]!),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.white70,
                        size: 28,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'هیچ اتاقی برای این سناریو وجود ندارد',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: color.withOpacity(0.7),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomsList(List<dynamic> rooms) {
    return ListView.builder(
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF8B0000),
                radius: 24,
                child: Text(
                  '${room.currentPlayers}/${room.maxPlayers}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'سناریو: ${room.scenario?.name ?? 'نامشخص'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _joinRoom(room.name),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: const Color(0xFF1a1a1a),
                  minimumSize: const Size(100, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'پیوستن',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _createRoom(),
              icon: const Icon(Icons.add),
              label: const Text('ساخت اتاق'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B0000),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _joinRandomRoom(),
              icon: const Icon(Icons.search),
              label: const Text('پیوستن تصادفی'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _createRoom() {
    if (currentIndex < scenarios.length) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateRoomScreen(
            selectedScenario: scenarios[currentIndex],
          ),
        ),
      );
    }
  }

  void _joinRandomRoom() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const JoinRoomScreen(),
      ),
    );
  }

  void _joinRoom(String roomName) {
    context.read<GameProvider>().joinRoom(roomName).then((_) {
      Navigator.pushReplacementNamed(context, '/lobby');
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در پیوستن به اتاق: $error'),
          backgroundColor: const Color(0xFF8B0000),
        ),
      );
    });
  }

  Future<void> _handleLogout() async {
    try {
      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
            ),
          ),
        );
      }

      // Clean up game state first
      final gameProvider = context.read<GameProvider>();
      await gameProvider.forceCleanup();

      // Then logout
      final authProvider = context.read<AuthProvider>();
      await authProvider.logout();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show success message briefly
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('با موفقیت خارج شدید'),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Wait a bit for the UI to update, then force a rebuild
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          setState(() {});
        }
        
        // Force a rebuild after the frame is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
        
        // If still not redirected, force navigation to login
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted && context.read<AuthProvider>().isLoggedIn == false) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }

      // The AuthWrapper should automatically redirect to LoginScreen
      // due to the context.watch<AuthProvider>() in main.dart
      
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در خروج: $e'),
            backgroundColor: const Color(0xFF8B0000),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}