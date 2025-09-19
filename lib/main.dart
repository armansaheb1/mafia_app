import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/game_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
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
        background: mafiaDark,
        onPrimary: Colors.white,
        onSecondary: mafiaDark,
        onSurface: Colors.white,
        onBackground: Colors.white,
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
      cardTheme: CardThemeData(
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
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return mafiaGold;
          }
          return mafiaLightGray;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
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
        ChangeNotifierProvider(create: (ctx) => GameProvider()),
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
      setState(() => _statusMessage = 'در حال بررسی احراز هویت...');
      
      // اول GameProvider رو initialize کن
      await gameProvider.initialize();
      
      // سپس احراز هویت رو چک کن
      await authProvider.checkAuthStatus();

      if (!authProvider.isLoggedIn) {
        setState(() => _isChecking = false);
        return;
      }

      setState(() => _statusMessage = 'در حال بررسی بازی فعال...');
      
      // چک کردن بازی فعال از سرور
      await gameProvider.checkActiveGame();

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

    final authProvider = context.watch<AuthProvider>();
    final gameProvider = context.watch<GameProvider>();

    // اگر کاربر لاگین نکرده باشد
    if (!authProvider.isLoggedIn) {
      return const LoginScreen();
    }

    // اگر بازی فعال وجود دارد
    if (gameProvider.currentRoom != null && gameProvider.currentPhase != null) {
      if (gameProvider.currentPhase == 'finished') {
        // بازی تمام شده - نمایش پیام و رفتن به خانه
        _showGameFinishedMessage(gameProvider.currentGameState?.winner ?? 'نامشخص');
        return const ScenarioSliderScreen();
      } else {
        // بازی هنوز فعال است - رفتن به بازی
        return const GameScreen();
      }
    }

    // اگر کاربر در اتاق باشد اما بازی شروع نشده باشد
    if (gameProvider.currentRoom != null) {
      return LobbyScreen();
    }

    // در غیر این صورت به صفحه اصلی برود
    return const ScenarioSliderScreen();
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