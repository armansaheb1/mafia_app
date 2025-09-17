import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/game_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/game_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => AuthProvider()),
        ChangeNotifierProvider(create: (ctx) => GameProvider()),
      ],
      child: MaterialApp(
        title: 'Mafia Game',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          fontFamily: 'Vazirmatn', // اگر فونت فارسی داری اضافه کن
        ),
        home: const AuthWrapper(),
        routes: {
          '/login': (ctx) => const LoginScreen(),
          '/home': (ctx) => const HomeScreen(),
          '/lobby': (ctx) => const LobbyScreen(),
          '/game': (ctx) => const GameScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isChecking = true;
  String _statusMessage = 'در حال بررسی وضعیت...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
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
        return const HomeScreen();
      } else {
        // بازی هنوز فعال است - رفتن به بازی
        return const GameScreen();
      }
    }

    // اگر کاربر در اتاق باشد اما بازی شروع نشده باشد
    if (gameProvider.currentRoom != null) {
      return const LobbyScreen();
    }

    // در غیر این صورت به صفحه اصلی برود
    return const HomeScreen();
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