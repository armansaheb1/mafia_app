import 'package:flutter/material.dart';

class ImageOptimizationService {
  /// ابعاد بهینه برای عکس‌های پس‌زمینه سناریوها
  static const Map<String, int> optimalDimensions = {
    'width': 1920,
    'height': 1080,
    'minWidth': 1280,
    'minHeight': 720,
    'maxWidth': 2560,
    'maxHeight': 1440,
  };

  /// نسبت ابعاد بهینه (16:9)
  static const double optimalAspectRatio = 16 / 9;

  /// بررسی ابعاد عکس
  static bool isOptimalSize(int width, int height) {
    final aspectRatio = width / height;
    final isAspectRatioValid = (aspectRatio - optimalAspectRatio).abs() < 0.1;
    final isWidthValid = width >= optimalDimensions['minWidth']! && 
                        width <= optimalDimensions['maxWidth']!;
    final isHeightValid = height >= optimalDimensions['minHeight']! && 
                         height <= optimalDimensions['maxHeight']!;
    
    return isAspectRatioValid && isWidthValid && isHeightValid;
  }

  /// محاسبه ابعاد بهینه برای دستگاه
  static Map<String, double> getOptimalSizeForDevice(Size screenSize) {
    final screenAspectRatio = screenSize.width / screenSize.height;
    
    double optimalWidth, optimalHeight;
    
    if (screenAspectRatio > optimalAspectRatio) {
      // صفحه عریض‌تر از 16:9
      optimalHeight = screenSize.height;
      optimalWidth = optimalHeight * optimalAspectRatio;
    } else {
      // صفحه باریک‌تر از 16:9
      optimalWidth = screenSize.width;
      optimalHeight = optimalWidth / optimalAspectRatio;
    }
    
    return {
      'width': optimalWidth,
      'height': optimalHeight,
    };
  }

  /// تنظیمات BoxFit برای انواع مختلف عکس
  static BoxFit getOptimalBoxFit(int imageWidth, int imageHeight, Size screenSize) {
    final imageAspectRatio = imageWidth / imageHeight;
    final screenAspectRatio = screenSize.width / screenSize.height;
    
    if ((imageAspectRatio - screenAspectRatio).abs() < 0.1) {
      return BoxFit.cover; // نسبت ابعاد مشابه
    } else if (imageAspectRatio > screenAspectRatio) {
      return BoxFit.fitHeight; // عکس عریض‌تر
    } else {
      return BoxFit.fitWidth; // عکس باریک‌تر
    }
  }

  /// تنظیمات Alignment برای انواع مختلف عکس
  static Alignment getOptimalAlignment(String scenarioName) {
    switch (scenarioName.toLowerCase()) {
      case 'شب‌های مافیا':
        return Alignment.bottomCenter; // تمرکز روی پایین عکس
      case 'پدرخوانده':
        return Alignment.center; // تمرکز روی مرکز
      case 'فراماسون‌ها':
        return Alignment.topCenter; // تمرکز روی بالای عکس
      case 'اینترنتی':
        return Alignment.center; // تمرکز روی مرکز
      case 'تیم بزرگ':
        return Alignment.center; // تمرکز روی مرکز
      default:
        return Alignment.center;
    }
  }

  /// تولید URL بهینه برای عکس
  static String getOptimizedImageUrl(String baseUrl, {String? quality = 'high'}) {
    // اگر کیفیت مشخص شده باشد، آن را به URL اضافه کن
    if (quality != null && quality != 'high') {
      return '$baseUrl?quality=$quality';
    }
    return baseUrl;
  }

  /// بررسی کیفیت عکس
  static String getImageQuality(int width, int height) {
    if (width >= 1920 && height >= 1080) {
      return 'high';
    } else if (width >= 1280 && height >= 720) {
      return 'medium';
    } else {
      return 'low';
    }
  }

  /// راهنمای ابعاد عکس
  static Map<String, dynamic> getImageGuidelines() {
    return {
      'recommended': {
        'width': 1920,
        'height': 1080,
        'aspectRatio': '16:9',
        'format': 'JPG or PNG',
        'maxSize': '2MB',
      },
      'alternative': {
        'width': 2560,
        'height': 1440,
        'aspectRatio': '16:9',
        'format': 'JPG or PNG',
        'maxSize': '3MB',
      },
      'minimum': {
        'width': 1280,
        'height': 720,
        'aspectRatio': '16:9',
        'format': 'JPG or PNG',
        'maxSize': '1MB',
      },
      'tips': [
        'از عکس‌های با کنتراست بالا استفاده کنید',
        'رنگ‌های تیره برای پس‌زمینه مناسب‌تر است',
        'از جزئیات زیاد پرهیز کنید تا متن خوانا باشد',
        'نور ملایم و کم برای بهتر دیده شدن متن',
      ],
    };
  }
}

