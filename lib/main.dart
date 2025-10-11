import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/game_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/game_screen.dart';
import 'screens/game_table_screen.dart';
import 'screens/scenario_slider_screen.dart';
import 'services/platform_service.dart';

void main() {
  // نمایش اطلاعات پلتفرم در حالت دیباگ
  PlatformService.printPlatformInfo();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  ThemeData _buildMafiaTheme() {
    const Color mafiaDark = Color(0xFF1a1a1a);
    const Color mafiaRed = Color(0xFF8B0000);
    const Color mafiaGold = Color(0xFFFFD700);
    const Color mafiaGray = Color(0xFF2C2C2C);
    const Color mafiaLightGray = Color(0xFF404040);

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Vazirmatn',
      colorScheme: const ColorScheme.dark(
        primary: mafiaRed,
        secondary: mafiaGold,
        surface: mafiaDark,
        onPrimary: Colors.white,
        onSecondary: mafiaDark,
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: mafiaDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: mafiaDark,
        foregroundColor: mafiaGold,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: mafiaGold,
        ),
      ),
      cardTheme: CardTheme(
        color: mafiaGray,
        elevation: 8,
        shadowColor: mafiaRed.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mafiaRed,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: mafiaRed.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: mafiaGold,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: mafiaLightGray,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: mafiaRed),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: mafiaLightGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: mafiaGold, width: 2),
        ),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white54),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return mafiaGold;
          }
          return mafiaLightGray;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return mafiaRed.withOpacity(0.5);
          }
          return mafiaLightGray.withOpacity(0.3);
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: mafiaLightGray,
        thickness: 1,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => AuthProvider()),
        ChangeNotifierProvider(create: (ctx) {
          final gameProvider = GameProvider();
          gameProvider.initializeGameService(ctx);
          return gameProvider;
        }),
        ChangeNotifierProvider(create: (ctx) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Mafia Game',
            theme: _buildMafiaTheme(),
            home: const AuthWrapper(),
        routes: {
          '/login': (ctx) => const LoginScreen(),
          '/register': (ctx) => const RegisterScreen(),
          '/home': (ctx) => const ScenarioSliderScreen(),
          '/old-home': (ctx) => const HomeScreen(),
          '/lobby': (ctx) => LobbyScreen(),
          '/game': (ctx) => const GameScreen(),
          '/game-table': (ctx) => const GameTableScreen(),
        },
        debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  bool _isChecking = true;
  String _statusMessage = 'در حال بررسی وضعیت...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // هنگام بستن اپ یا رفتن به background، از لابی خارج شو
      final gameProvider = context.read<GameProvider>();
      if (gameProvider.currentRoom != null) {
        gameProvider.forceCleanup();
      }
    }
  }

  Future<void> _initializeApp() async {
    final authProvider = context.read<AuthProvider>();
    final gameProvider = context.read<GameProvider>();

    try {
      print('🚀 Initializing app...');
      setState(() => _statusMessage = 'در حال راه‌اندازی...');
      
      // اول GameProvider را initialize کن
      await gameProvider.initialize();
      
      setState(() => _statusMessage = 'در حال بررسی احراز هویت...');
      
      // چک کردن وضعیت authentication
      await authProvider.checkAuthStatus();

      if (!authProvider.isLoggedIn) {
        setState(() => _isChecking = false);
        return;
      }

      // فقط API را چک کن - هیچ state محلی استفاده نکن
      print('🔍 Checking backend for active player...');
      setState(() => _statusMessage = 'در حال بررسی بازیکن فعال در سرور...');
      
      final hasActivePlayer = await gameProvider.checkActivePlayerFromBackend();
      
      if (hasActivePlayer) {
        print('✅ Active player found - navigation will be handled by GameProvider');
        setState(() => _statusMessage = 'بازیکن فعال پیدا شد! در حال اتصال...');
      } else {
        print('❌ No active player found - going to main page');
        setState(() => _statusMessage = 'هیچ بازی فعالی پیدا نشد');
      }
      
      setState(() => _isChecking = false);

    } catch (e) {
      print('❌ Error in app initialization: $e');
      setState(() {
        _isChecking = false;
      });
    }
  }

  void _showGameFinishedMessage(String winner) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('بازی قبلاً به پایان رسیده بود. برنده: $winner'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'باشه',
            onPressed: () {},
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                _statusMessage,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final gameProvider = context.watch<GameProvider>();

        // Debug log for auth status
        if (kDebugMode) {
          print('🔍 AuthWrapper - isLoggedIn: ${authProvider.isLoggedIn}');
        }

        // اگر کاربر لاگین نکرده باشد
        if (!authProvider.isLoggedIn) {
          if (kDebugMode) {
            print('🔄 Redirecting to LoginScreen');
          }
          return const LoginScreen();
        }

        // اگر بازی فعال وجود دارد
        if (gameProvider.currentRoom != null) {
          if (kDebugMode) {
            print('🔍 AuthWrapper - Room found: ${gameProvider.currentRoom!.name}');
            print('🔍 AuthWrapper - Room status: ${gameProvider.currentRoom!.status}');
            print('🔍 AuthWrapper - Current phase: ${gameProvider.currentPhase}');
            print('🔍 AuthWrapper - Game state: ${gameProvider.currentGameState?.phase}');
            print('🔍 AuthWrapper - WebSocket connected: ${gameProvider.isWebSocketConnected}');
          }
          
          if (gameProvider.currentRoom!.status == 'waiting') {
            // اتاق در انتظار بازیکن - برو به لابی
            if (kDebugMode) {
              print('🔄 Going to lobby - room is waiting');
            }
            return LobbyScreen();
          } else if (gameProvider.currentRoom!.status == 'in_progress') {
            // اتاق در حال بازی - بررسی فاز بازی
            final gamePhase = gameProvider.currentPhase ?? gameProvider.currentGameState?.phase;
            
            if (kDebugMode) {
              print('🎮 Room is in progress - checking game phase');
              print('🎮 Current phase: $gamePhase');
              print('🎮 Game state phase: ${gameProvider.currentGameState?.phase}');
            }
            
            if (gamePhase == 'waiting' || gamePhase == null || gamePhase == '') {
              // بازی در حال شروع یا فاز نامشخص - برو به لابی
              if (kDebugMode) {
                print('🔄 Game is starting or phase unknown - going to lobby');
                print('🔄 Game phase value: "$gamePhase" (type: ${gamePhase.runtimeType})');
                print('🔄 Game phase length: ${gamePhase?.length ?? 0}');
              }
              return LobbyScreen();
            } else {
              // بازی فعال با فاز مشخص - برو به بازی
              if (kDebugMode) {
                print('🎮 Active game with phase $gamePhase - going to game table');
                print('🎮 Game phase value: "$gamePhase" (type: ${gamePhase.runtimeType})');
                print('🎮 Game phase length: ${gamePhase?.length ?? 0}');
              }
              return GameTableScreen();
            }
          } else if (gameProvider.currentRoom!.status == 'finished') {
            // اتاق تمام شده - رفتن به خانه
            if (kDebugMode) {
              print('🔄 Room finished - going to main page');
            }
            return const ScenarioSliderScreen();
          } else {
            // وضعیت نامشخص - برو به لابی
            if (kDebugMode) {
              print('🔄 Unknown room status - going to lobby');
            }
            return LobbyScreen();
          }
        }

        // در غیر این صورت به صفحه اصلی برود
        return const ScenarioSliderScreen();
      },
    );
  }
}

// اضافه کردن یک splash screen سفارشی (اختیاری)
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Colors.blue, Colors.purple],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.groups,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 20),
              const Text(
                'بازی مافیا',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'نسخه 1.0.0',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.8)),
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

