// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  String? _currentBackgroundImage;
  String? _currentScenarioName;

  String? get currentBackgroundImage => _currentBackgroundImage;
  String? get currentScenarioName => _currentScenarioName;

  // تصاویر پس‌زمینه کل اپ برای هر سناریو
  final Map<String, String> appBackgrounds = {
    'شب‌های مافیا (کلاسیک تلویزیونی)': 'https://picsum.photos/1920/1080?random=1',
    'پدرخوانده (Godfather Show)': 'https://picsum.photos/1920/1080?random=2',
    'شب‌های مافیا (با فراماسون‌ها)': 'https://picsum.photos/1920/1080?random=3',
    'نسخه اینترنتی (10 نفره)': 'https://picsum.photos/1920/1080?random=4',
    'کلاسیک ساده': 'https://picsum.photos/1920/1080?random=5',
    'تیم بزرگ پیشرفته': 'https://picsum.photos/1920/1080?random=6',
  };

  void updateBackground(String scenarioNameOrUrl) {
    // اگر URL کامل است (شامل http یا https)
    if (scenarioNameOrUrl.startsWith('http')) {
      _currentBackgroundImage = scenarioNameOrUrl;
      _currentScenarioName = null;
    } else {
      // اگر نام سناریو است
      _currentScenarioName = scenarioNameOrUrl;
      _currentBackgroundImage = appBackgrounds[scenarioNameOrUrl];
    }
    notifyListeners();
  }

  void clearBackground() {
    _currentBackgroundImage = null;
    _currentScenarioName = null;
    notifyListeners();
  }

  bool get hasBackground => _currentBackgroundImage != null;
}
