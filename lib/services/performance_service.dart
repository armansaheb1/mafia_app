import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  final Map<String, Stopwatch> _timers = {};
  final Map<String, int> _counters = {};
  final Map<String, List<Duration>> _measurements = {};

  /// Start timing an operation
  void startTimer(String operation) {
    _timers[operation] = Stopwatch()..start();
    if (kDebugMode) {
      developer.log('⏱️ Started timer: $operation');
    }
  }

  /// Stop timing and log the result
  Duration stopTimer(String operation) {
    final timer = _timers.remove(operation);
    if (timer != null) {
      timer.stop();
      final duration = timer.elapsed;
      
      // Store measurement for analysis
      _measurements.putIfAbsent(operation, () => []).add(duration);
      
      if (kDebugMode) {
        developer.log('⏱️ Timer $operation: ${duration.inMilliseconds}ms');
      }
      
      return duration;
    }
    return Duration.zero;
  }

  /// Increment a counter
  void incrementCounter(String counter) {
    _counters[counter] = (_counters[counter] ?? 0) + 1;
  }

  /// Get counter value
  int getCounter(String counter) {
    return _counters[counter] ?? 0;
  }

  /// Reset all counters
  void resetCounters() {
    _counters.clear();
  }

  /// Get performance statistics
  Map<String, dynamic> getStats() {
    final stats = <String, dynamic>{};
    
    // Counter stats
    stats['counters'] = Map<String, int>.from(_counters);
    
    // Timer stats
    stats['measurements'] = <String, dynamic>{};
    for (final entry in _measurements.entries) {
      final measurements = entry.value;
      if (measurements.isNotEmpty) {
        final avgMs = measurements.map((d) => d.inMilliseconds).reduce((a, b) => a + b) / measurements.length;
        final minMs = measurements.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b);
        final maxMs = measurements.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b);
        
        stats['measurements'][entry.key] = {
          'count': measurements.length,
          'avg_ms': avgMs.round(),
          'min_ms': minMs,
          'max_ms': maxMs,
        };
      }
    }
    
    return stats;
  }

  /// Clear all performance data
  void clearStats() {
    _timers.clear();
    _counters.clear();
    _measurements.clear();
  }

  /// Measure async operation execution time
  Future<T> measureAsync<T>(String operation, Future<T> Function() fn) async {
    startTimer(operation);
    try {
      final result = await fn();
      return result;
    } finally {
      stopTimer(operation);
    }
  }

  /// Measure sync operation execution time
  T measureSync<T>(String operation, T Function() fn) {
    startTimer(operation);
    try {
      final result = fn();
      return result;
    } finally {
      stopTimer(operation);
    }
  }

  /// Log performance warning if operation takes too long
  void logSlowOperation(String operation, Duration threshold) {
    final measurements = _measurements[operation];
    if (measurements != null && measurements.isNotEmpty) {
      final lastMeasurement = measurements.last;
      if (lastMeasurement > threshold) {
        developer.log('⚠️ Slow operation detected: $operation took ${lastMeasurement.inMilliseconds}ms (threshold: ${threshold.inMilliseconds}ms)');
      }
    }
  }
}
