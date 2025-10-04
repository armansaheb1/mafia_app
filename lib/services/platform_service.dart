import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformService {
  static String getBaseUrl() {
    if (kDebugMode) {
      // برای همه پلتفرم‌ها از 172.20.10.10 استفاده کن (Flutter emulator)
      return 'http://172.20.10.10:8000';
    }
    
    // در حالت production، از URL اصلی استفاده کن
    return 'https://your-production-api.com';
  }
  
  static String getWebSocketUrl() {
    if (kDebugMode) {
      // برای همه پلتفرم‌ها از 172.20.10.10 استفاده کن
      return 'ws://172.20.10.10:8000';
    }
    
    // در حالت production
    return 'wss://your-production-api.com';
  }
  
  static String getMediaUrl() {
    if (kDebugMode) {
      // برای همه پلتفرم‌ها از 172.20.10.10 استفاده کن
      return 'http://172.20.10.10:8000';
    }
    
    // در حالت production
    return 'https://your-production-api.com';
  }
  
  static String getPlatformName() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isMacOS) return 'macOS';
    return 'Unknown';
  }
  
  static void printPlatformInfo() {
    if (kDebugMode) {
      print('🖥️ Platform: ${getPlatformName()}');
      print('🌐 API Base URL: ${getBaseUrl()}');
      print('🔌 WebSocket URL: ${getWebSocketUrl()}');
      print('📁 Media URL: ${getMediaUrl()}');
    }
  }
}
