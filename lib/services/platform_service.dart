import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformService {
  static String getBaseUrl() {
    // استفاده از سرور واقعی
    return 'https://allinone.wiki';
  }
  
  static String getWebSocketUrl() {
    // استفاده از سرور واقعی
    return 'ws://allinone.wiki';
  }
  
  static String getMediaUrl() {
    // استفاده از سرور واقعی
    return 'https://allinone.wiki';
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
