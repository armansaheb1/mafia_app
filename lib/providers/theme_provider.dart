// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  String? _currentBackgroundImage;
  String? _currentScenarioName;

  String? get currentBackgroundImage => _currentBackgroundImage;
  String? get currentScenarioName => _currentScenarioName;

  // تصاویر پس‌زمینه کل اپ برای هر سناریو
  final Map<String, String> appBackgrounds = {
    'شب‌های مافیا (کلاسیک تلویزیونی)': 'https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=1920&h=1080&fit=crop',
    'پدرخوانده (Godfather Show)': 'https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=1920&h=1080&fit=crop',
    'شب‌های مافیا (با فراماسون‌ها)': 'https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=1920&h=1080&fit=crop',
    'نسخه اینترنتی (10 نفره)': 'https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=1920&h=1080&fit=crop',
    'کلاسیک ساده': 'https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=1920&h=1080&fit=crop',
    'تیم بزرگ پیشرفته': 'https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=1920&h=1080&fit=crop',
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
