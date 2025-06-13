import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Performance monitoring service for tracking UI performance
/// Monitors theme switching, animations, and frame rendering
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._();
  static PerformanceMonitor get instance => _instance;

  PerformanceMonitor._();

  // Performance metrics storage
  final List<double> _frameRenderTimes = [];
  final List<double> _themeSwitchTimes = [];
  final List<double> _animationFrameDrops = [];

  // Performance thresholds
  static const double _frameDropThreshold = 16.67; // 60 FPS threshold
  static const double _themeSwitchThreshold =
      50.0; // 50ms threshold (more strict)

  bool _isMonitoring = false;
  DateTime? _themeChangeStartTime;

  /// Start monitoring performance
  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;

    // Monitor frame rendering performance
    SchedulerBinding.instance.addTimingsCallback(_onFrameRendered);

    if (kDebugMode) {
      developer.log('Performance monitoring started',
          name: 'PerformanceMonitor');
    }
  }

  /// Stop monitoring performance
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    SchedulerBinding.instance.removeTimingsCallback(_onFrameRendered);

    if (kDebugMode) {
      developer.log('Performance monitoring stopped',
          name: 'PerformanceMonitor');
    }
  }

  /// Mark the start of a theme change operation
  void markThemeChangeStart() {
    _themeChangeStartTime = DateTime.now();

    if (kDebugMode) {
      developer.log('Theme change started', name: 'PerformanceMonitor');
    }
  }

  /// Mark the end of a theme change operation
  void markThemeChangeEnd() {
    if (_themeChangeStartTime == null) return;

    final duration = DateTime.now()
        .difference(_themeChangeStartTime!)
        .inMilliseconds
        .toDouble();
    _themeSwitchTimes.add(duration);

    // Keep only recent measurements
    if (_themeSwitchTimes.length > 10) {
      _themeSwitchTimes.removeAt(0);
    }

    if (kDebugMode) {
      final status = duration > _themeSwitchThreshold ? 'SLOW' : 'GOOD';
      developer.log(
        'Theme change completed: ${duration.toStringAsFixed(1)}ms [$status]',
        name: 'PerformanceMonitor',
      );
    }

    _themeChangeStartTime = null;
  }

  /// Handle frame rendering performance
  void _onFrameRendered(List<FrameTiming> timings) {
    if (!_isMonitoring) return;

    for (final timing in timings) {
      final renderTime =
          timing.totalSpan.inMicroseconds / 1000.0; // Convert to milliseconds
      _frameRenderTimes.add(renderTime);

      // Track frame drops
      if (renderTime > _frameDropThreshold) {
        _animationFrameDrops.add(renderTime);

        if (kDebugMode) {
          developer.log(
            'Frame drop detected: ${renderTime.toStringAsFixed(1)}ms',
            name: 'PerformanceMonitor',
          );
        }
      }
    }

    // Keep only recent measurements
    if (_frameRenderTimes.length > 100) {
      _frameRenderTimes.removeRange(0, _frameRenderTimes.length - 100);
    }

    if (_animationFrameDrops.length > 20) {
      _animationFrameDrops.removeRange(0, _animationFrameDrops.length - 20);
    }
  }

  /// Get performance statistics
  PerformanceStats getStats() {
    // Calculate frame drop count - actual dropped frames from recent renders
    final droppedFrames =
        _frameRenderTimes.where((time) => time > _frameDropThreshold).length;

    return PerformanceStats(
      averageFrameTime: _frameRenderTimes.isEmpty
          ? 0.0
          : _frameRenderTimes.reduce((a, b) => a + b) /
              _frameRenderTimes.length,
      maxFrameTime: _frameRenderTimes.isEmpty
          ? 0.0
          : _frameRenderTimes.reduce((a, b) => a > b ? a : b),
      frameDropCount:
          droppedFrames, // Fixed: show actual dropped frames, not accumulated drops
      averageThemeSwitchTime: _themeSwitchTimes.isEmpty
          ? 0.0
          : _themeSwitchTimes.reduce((a, b) => a + b) /
              _themeSwitchTimes.length,
      maxThemeSwitchTime: _themeSwitchTimes.isEmpty
          ? 0.0
          : _themeSwitchTimes.reduce((a, b) => a > b ? a : b),
      isPerformant: _isPerformanceGood(),
    );
  }

  /// Check if current performance is good
  bool _isPerformanceGood() {
    if (_frameRenderTimes.isEmpty) return true;

    final recentFrameDrops = _frameRenderTimes
        .where(
          (time) => time > _frameDropThreshold,
        )
        .length;

    final recentSlowThemeSwitches = _themeSwitchTimes
        .where(
          (time) => time > _themeSwitchThreshold,
        )
        .length;

    // Performance is good if we have less than 10% frame drops and fast theme switches
    final frameDropRate = _frameRenderTimes.isEmpty
        ? 0.0
        : recentFrameDrops / _frameRenderTimes.length;
    final slowThemeRate = _themeSwitchTimes.isEmpty
        ? 0.0
        : recentSlowThemeSwitches / _themeSwitchTimes.length;

    return frameDropRate < 0.1 && slowThemeRate < 0.1;
  }

  /// Reset all performance metrics
  void resetMetrics() {
    _frameRenderTimes.clear();
    _themeSwitchTimes.clear();
    _animationFrameDrops.clear();

    if (kDebugMode) {
      developer.log('Performance metrics reset', name: 'PerformanceMonitor');
    }
  }

  /// Log current performance summary
  void logPerformanceSummary() {
    final stats = getStats();

    final summary = '''
📊 PERFORMANCE SUMMARY 📊
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 Overall Status: ${stats.isPerformant ? "✅ EXCELLENT" : "⚠️ NEEDS IMPROVEMENT"}

🖼️ Frame Rendering:
   • Average Frame Time: ${stats.averageFrameTime.toStringAsFixed(1)}ms (target: <16.67ms)
   • Max Frame Time: ${stats.maxFrameTime.toStringAsFixed(1)}ms
   • Frame Drops: ${stats.frameDropCount} (target: <5)
   • Frame Performance: ${stats.averageFrameTime < 8.0 ? "🟢 EXCELLENT" : stats.averageFrameTime < 12.0 ? "🟡 GOOD" : "🔴 POOR"}

🎨 Theme Switching:
   • Average Speed: ${stats.averageThemeSwitchTime.toStringAsFixed(1)}ms (target: <50ms)
   • Max Speed: ${stats.maxThemeSwitchTime.toStringAsFixed(1)}ms
   • Theme Performance: ${stats.averageThemeSwitchTime < 30.0 ? "🟢 INSTANT" : stats.averageThemeSwitchTime < 50.0 ? "🟡 FAST" : "🔴 SLOW"}

📈 Recommendations:
${_getPerformanceRecommendations(stats)}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''';

    // Use developer.log for production-safe logging
    if (kDebugMode) {
      // Use print only in debug mode for immediate console visibility
      print(summary);
      developer.log(summary, name: 'PerformanceMonitor');
    } else {
      // Production: use developer.log only
      developer.log(summary, name: 'PerformanceMonitor');
    }
  }

  /// Get performance recommendations
  String _getPerformanceRecommendations(PerformanceStats stats) {
    final recommendations = <String>[];

    if (stats.frameDropCount > 5) {
      recommendations.add(
          '   • 🎯 Add RepaintBoundary widgets around complex UI components');
      recommendations.add('   • 🎯 Use const constructors for static widgets');
      recommendations.add('   • 🎯 Minimize setState() calls in hot paths');
    }
    if (stats.averageThemeSwitchTime > 50) {
      recommendations.add(
          '   • 🎨 Theme switches taking too long - consider instant switching');
      recommendations
          .add('   • 🎨 Cache theme data to avoid repeated calculations');
    }
    if (stats.averageFrameTime > 12.0) {
      recommendations
          .add('   • ⚡ Move expensive operations to isolates or async methods');
      recommendations
          .add('   • ⚡ Profile widget rebuilds using Flutter Inspector');
    }

    if (recommendations.isEmpty) {
      return '   • Performance is excellent! 🚀';
    }

    return recommendations.join('\n');
  }
}

/// Performance statistics data class
class PerformanceStats {
  final double averageFrameTime;
  final double maxFrameTime;
  final int frameDropCount;
  final double averageThemeSwitchTime;
  final double maxThemeSwitchTime;
  final bool isPerformant;

  const PerformanceStats({
    required this.averageFrameTime,
    required this.maxFrameTime,
    required this.frameDropCount,
    required this.averageThemeSwitchTime,
    required this.maxThemeSwitchTime,
    required this.isPerformant,
  });

  @override
  String toString() {
    return 'PerformanceStats('
        'avgFrame: ${averageFrameTime.toStringAsFixed(1)}ms, '
        'frameDrops: $frameDropCount, '
        'avgTheme: ${averageThemeSwitchTime.toStringAsFixed(1)}ms, '
        'performant: $isPerformant)';
  }
}
