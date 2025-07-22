import 'dart:async';
import 'dart:collection';

/// Performance monitoring service for generation settings and API calls
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  static PerformanceMonitor get instance => _instance;
  PerformanceMonitor._internal();

  // Metrics storage
  final Queue<PerformanceMetric> _metrics = Queue<PerformanceMetric>();
  final Map<String, List<Duration>> _operationTimes = <String, List<Duration>>{};
  final Map<String, int> _operationCounts = <String, int>{};
  
  // Configuration
  static const int _maxMetricsHistory = 1000;
  static const Duration _metricsRetentionPeriod = Duration(hours: 1);
  
  // Timers for cleanup
  Timer? _cleanupTimer;
  
  /// Initialize the performance monitor
  void initialize() {
    // Start periodic cleanup
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) => _cleanup());
  }

  /// Dispose of the performance monitor
  void dispose() {
    _cleanupTimer?.cancel();
    _metrics.clear();
    _operationTimes.clear();
    _operationCounts.clear();
  }

  /// Start timing an operation
  PerformanceTimer startTimer(String operationName) {
    return PerformanceTimer._(operationName, this);
  }

  /// Record a completed operation
  void _recordOperation(String operationName, Duration duration) {
    final now = DateTime.now();
    
    // Add to metrics history
    _metrics.add(PerformanceMetric(
      operationName: operationName,
      duration: duration,
      timestamp: now,
    ));
    
    // Update operation times
    _operationTimes.putIfAbsent(operationName, () => <Duration>[]);
    _operationTimes[operationName]!.add(duration);
    
    // Update operation counts
    _operationCounts[operationName] = (_operationCounts[operationName] ?? 0) + 1;
    
    // Limit history size
    while (_metrics.length > _maxMetricsHistory) {
      _metrics.removeFirst();
    }
    
    // Limit operation times history
    if (_operationTimes[operationName]!.length > 100) {
      _operationTimes[operationName]!.removeAt(0);
    }
  }

  /// Get performance statistics for an operation
  PerformanceStats? getStats(String operationName) {
    final times = _operationTimes[operationName];
    if (times == null || times.isEmpty) return null;
    
    final sortedTimes = List<Duration>.from(times)..sort();
    final count = times.length;
    final totalMs = times.fold<int>(0, (sum, duration) => sum + duration.inMicroseconds);
    
    return PerformanceStats(
      operationName: operationName,
      count: count,
      averageDuration: Duration(microseconds: totalMs ~/ count),
      minDuration: sortedTimes.first,
      maxDuration: sortedTimes.last,
      medianDuration: sortedTimes[count ~/ 2],
      p95Duration: sortedTimes[(count * 0.95).floor()],
    );
  }

  /// Get all available performance statistics
  Map<String, PerformanceStats> getAllStats() {
    final stats = <String, PerformanceStats>{};
    
    for (final operationName in _operationTimes.keys) {
      final operationStats = getStats(operationName);
      if (operationStats != null) {
        stats[operationName] = operationStats;
      }
    }
    
    return stats;
  }

  /// Get recent metrics within a time window
  List<PerformanceMetric> getRecentMetrics({
    Duration? within,
    String? operationName,
  }) {
    final cutoff = within != null 
        ? DateTime.now().subtract(within)
        : DateTime.now().subtract(_metricsRetentionPeriod);
    
    return _metrics.where((metric) {
      if (metric.timestamp.isBefore(cutoff)) return false;
      if (operationName != null && metric.operationName != operationName) return false;
      return true;
    }).toList();
  }

  /// Check if an operation is performing poorly
  bool isOperationSlow(String operationName, {Duration? threshold}) {
    final stats = getStats(operationName);
    if (stats == null) return false;
    
    final defaultThreshold = _getDefaultThreshold(operationName);
    final checkThreshold = threshold ?? defaultThreshold;
    
    return stats.averageDuration > checkThreshold || stats.p95Duration > checkThreshold * 2;
  }

  /// Get performance warnings
  List<PerformanceWarning> getWarnings() {
    final warnings = <PerformanceWarning>[];
    
    for (final operationName in _operationTimes.keys) {
      final stats = getStats(operationName);
      if (stats == null) continue;
      
      // Check for slow operations
      if (isOperationSlow(operationName)) {
        warnings.add(PerformanceWarning(
          type: PerformanceWarningType.slowOperation,
          operationName: operationName,
          message: 'Operation "$operationName" is performing slowly (avg: ${stats.averageDuration.inMilliseconds}ms)',
          severity: _getWarningSeverity(stats),
        ));
      }
      
      // Check for high frequency operations
      final recentCount = getRecentMetrics(
        within: const Duration(minutes: 1),
        operationName: operationName,
      ).length;
      
      if (recentCount > 100) {
        warnings.add(PerformanceWarning(
          type: PerformanceWarningType.highFrequency,
          operationName: operationName,
          message: 'Operation "$operationName" called $recentCount times in the last minute',
          severity: PerformanceWarningSeverity.medium,
        ));
      }
      
      // Check for high variance
      final variance = _calculateVariance(stats);
      if (variance > 0.5) {
        warnings.add(PerformanceWarning(
          type: PerformanceWarningType.highVariance,
          operationName: operationName,
          message: 'Operation "$operationName" has inconsistent performance',
          severity: PerformanceWarningSeverity.low,
        ));
      }
    }
    
    return warnings;
  }

  /// Generate a performance report
  PerformanceReport generateReport() {
    final stats = getAllStats();
    final warnings = getWarnings();
    final totalOperations = _operationCounts.values.fold<int>(0, (sum, count) => sum + count);
    
    return PerformanceReport(
      generatedAt: DateTime.now(),
      totalOperations: totalOperations,
      operationStats: stats,
      warnings: warnings,
      recommendations: _generateRecommendations(stats, warnings),
    );
  }

  /// Start monitoring (for compatibility with existing code)
  void startMonitoring() {
    initialize();
  }

  /// Get performance summary (for compatibility with existing code)
  Map<String, dynamic> getPerformanceSummary() {
    final stats = getAllStats();
    final report = generateReport();
    
    return {
      'operationStats': stats,
      'warnings': report.warnings,
      'totalOperations': report.totalOperations,
    };
  }

  /// Get overall performance stats (for UI display)
  PerformanceStats getOverallStats() {
    final allStats = getAllStats();
    
    if (allStats.isEmpty) {
      // Return default stats if no data
      return const PerformanceStats(
        operationName: 'overall',
        count: 0,
        averageDuration: Duration.zero,
        minDuration: Duration.zero,
        maxDuration: Duration.zero,
        medianDuration: Duration.zero,
        p95Duration: Duration.zero,
      );
    }
    
    // Calculate overall statistics from all operations
    var totalCount = 0;
    var totalDuration = Duration.zero;
    var minDuration = const Duration(days: 1);
    var maxDuration = Duration.zero;
    final allDurations = <Duration>[];
    
    for (final stats in allStats.values) {
      totalCount += stats.count;
      totalDuration += Duration(microseconds: stats.averageDuration.inMicroseconds * stats.count);
      if (stats.minDuration < minDuration) minDuration = stats.minDuration;
      if (stats.maxDuration > maxDuration) maxDuration = stats.maxDuration;
      
      // Add individual durations for median/p95 calculation
      for (int i = 0; i < stats.count; i++) {
        allDurations.add(stats.averageDuration);
      }
    }
    
    if (totalCount == 0) {
      return const PerformanceStats(
        operationName: 'overall',
        count: 0,
        averageDuration: Duration.zero,
        minDuration: Duration.zero,
        maxDuration: Duration.zero,
        medianDuration: Duration.zero,
        p95Duration: Duration.zero,
      );
    }
    
    allDurations.sort();
    final averageDuration = Duration(microseconds: totalDuration.inMicroseconds ~/ totalCount);
    final medianDuration = allDurations[allDurations.length ~/ 2];
    final p95Duration = allDurations[(allDurations.length * 0.95).floor()];
    
    return PerformanceStats(
      operationName: 'overall',
      count: totalCount,
      averageDuration: averageDuration,
      minDuration: minDuration,
      maxDuration: maxDuration,
      medianDuration: medianDuration,
      p95Duration: p95Duration,
    );
  }

  /// Reset metrics (for compatibility with existing code)
  void resetMetrics() {
    _metrics.clear();
    _operationTimes.clear();
    _operationCounts.clear();
  }

  /// Log performance summary (for compatibility with existing code)
  void logPerformanceSummary() {
    // In production, this would log to a proper logging system
    // For now, we'll just generate the report silently
    generateReport();
  }

  /// Clean up old metrics
  void _cleanup() {
    final cutoff = DateTime.now().subtract(_metricsRetentionPeriod);
    
    // Remove old metrics
    _metrics.removeWhere((metric) => metric.timestamp.isBefore(cutoff));
    
    // Clean up operation times that are too old
    for (final operationName in _operationTimes.keys.toList()) {
      final times = _operationTimes[operationName]!;
      if (times.length > 50) {
        _operationTimes[operationName] = times.sublist(times.length - 50);
      }
    }
  }

  /// Get default performance threshold for an operation
  Duration _getDefaultThreshold(String operationName) {
    switch (operationName) {
      case 'settings_resolution':
        return const Duration(milliseconds: 5);
      case 'api_options_build':
        return const Duration(milliseconds: 2);
      case 'settings_validation':
        return const Duration(milliseconds: 10);
      case 'ui_update':
        return const Duration(milliseconds: 16); // 60 FPS
      case 'api_call':
        return const Duration(seconds: 5);
      default:
        return const Duration(milliseconds: 100);
    }
  }

  /// Get warning severity based on performance stats
  PerformanceWarningSeverity _getWarningSeverity(PerformanceStats stats) {
    final threshold = _getDefaultThreshold(stats.operationName);
    
    if (stats.averageDuration > threshold * 5) {
      return PerformanceWarningSeverity.high;
    } else if (stats.averageDuration > threshold * 2) {
      return PerformanceWarningSeverity.medium;
    } else {
      return PerformanceWarningSeverity.low;
    }
  }

  /// Calculate performance variance
  double _calculateVariance(PerformanceStats stats) {
    final avgMs = stats.averageDuration.inMilliseconds;
    final minMs = stats.minDuration.inMilliseconds;
    final maxMs = stats.maxDuration.inMilliseconds;
    
    if (avgMs == 0) return 0.0;
    
    return (maxMs - minMs) / avgMs;
  }

  /// Generate performance recommendations
  List<String> _generateRecommendations(
    Map<String, PerformanceStats> stats,
    List<PerformanceWarning> warnings,
  ) {
    final recommendations = <String>[];
    
    // Check for slow settings resolution
    final settingsStats = stats['settings_resolution'];
    if (settingsStats != null && settingsStats.averageDuration.inMilliseconds > 5) {
      recommendations.add('Consider caching settings resolution results');
    }
    
    // Check for frequent API option builds
    final apiStats = stats['api_options_build'];
    if (apiStats != null && apiStats.count > 1000) {
      recommendations.add('Consider caching API options for unchanged settings');
    }
    
    // Check for UI update frequency
    final uiStats = stats['ui_update'];
    if (uiStats != null && uiStats.averageDuration.inMilliseconds > 16) {
      recommendations.add('UI updates are slower than 60 FPS - consider debouncing or optimization');
    }
    
    // General recommendations based on warnings
    if (warnings.any((w) => w.type == PerformanceWarningType.highFrequency)) {
      recommendations.add('Consider implementing debouncing for frequently called operations');
    }
    
    if (warnings.any((w) => w.severity == PerformanceWarningSeverity.high)) {
      recommendations.add('Critical performance issues detected - immediate optimization recommended');
    }
    
    return recommendations;
  }
}

/// Timer for measuring operation performance
class PerformanceTimer {
  final String _operationName;
  final PerformanceMonitor _monitor;
  final Stopwatch _stopwatch;

  PerformanceTimer._(this._operationName, this._monitor) : _stopwatch = Stopwatch()..start();

  /// Stop the timer and record the result
  void stop() {
    _stopwatch.stop();
    _monitor._recordOperation(_operationName, _stopwatch.elapsed);
  }
}

/// Performance metric data
class PerformanceMetric {
  final String operationName;
  final Duration duration;
  final DateTime timestamp;

  const PerformanceMetric({
    required this.operationName,
    required this.duration,
    required this.timestamp,
  });
}

/// Performance statistics for an operation
class PerformanceStats {
  final String operationName;
  final int count;
  final Duration averageDuration;
  final Duration minDuration;
  final Duration maxDuration;
  final Duration medianDuration;
  final Duration p95Duration;

  const PerformanceStats({
    required this.operationName,
    required this.count,
    required this.averageDuration,
    required this.minDuration,
    required this.maxDuration,
    required this.medianDuration,
    required this.p95Duration,
  });

  /// Check if the operation is performing well
  bool get isPerformant {
    // Consider performant if average duration is reasonable
    return averageDuration.inMilliseconds < 100;
  }

  /// Get average frame time in milliseconds (for UI operations)
  double get averageFrameTime {
    // For UI operations, return average duration in ms, otherwise return 16ms (60 FPS target)
    if (operationName.contains('ui') || operationName.contains('render')) {
      return averageDuration.inMicroseconds / 1000.0;
    }
    return 16.0;
  }

  /// Get frame drop count (estimated based on performance)
  int get frameDropCount {
    // Estimate frame drops based on operations that exceed 16ms
    if (averageDuration.inMilliseconds > 16) {
      return (count * (averageDuration.inMilliseconds / 16)).round();
    }
    return 0;
  }

  /// Get average theme switch time in milliseconds (for theme operations)
  double get averageThemeSwitchTime {
    // For theme operations, return average duration in ms, otherwise return a default
    if (operationName.contains('theme')) {
      return averageDuration.inMicroseconds / 1000.0;
    }
    return 50.0;
  }

  @override
  String toString() {
    return 'PerformanceStats($operationName: '
        'count=$count, '
        'avg=${averageDuration.inMilliseconds}ms, '
        'min=${minDuration.inMilliseconds}ms, '
        'max=${maxDuration.inMilliseconds}ms, '
        'p95=${p95Duration.inMilliseconds}ms)';
  }
}

/// Performance warning
class PerformanceWarning {
  final PerformanceWarningType type;
  final String operationName;
  final String message;
  final PerformanceWarningSeverity severity;

  const PerformanceWarning({
    required this.type,
    required this.operationName,
    required this.message,
    required this.severity,
  });
}

/// Types of performance warnings
enum PerformanceWarningType {
  slowOperation,
  highFrequency,
  highVariance,
  memoryUsage,
}

/// Severity levels for performance warnings
enum PerformanceWarningSeverity {
  low,
  medium,
  high,
}

/// Complete performance report
class PerformanceReport {
  final DateTime generatedAt;
  final int totalOperations;
  final Map<String, PerformanceStats> operationStats;
  final List<PerformanceWarning> warnings;
  final List<String> recommendations;

  const PerformanceReport({
    required this.generatedAt,
    required this.totalOperations,
    required this.operationStats,
    required this.warnings,
    required this.recommendations,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Performance Report (${generatedAt.toIso8601String()})');
    buffer.writeln('Total Operations: $totalOperations');
    buffer.writeln();
    
    buffer.writeln('Operation Statistics:');
    for (final stats in operationStats.values) {
      buffer.writeln('  $stats');
    }
    buffer.writeln();
    
    if (warnings.isNotEmpty) {
      buffer.writeln('Warnings:');
      for (final warning in warnings) {
        buffer.writeln('  [${warning.severity.name.toUpperCase()}] ${warning.message}');
      }
      buffer.writeln();
    }
    
    if (recommendations.isNotEmpty) {
      buffer.writeln('Recommendations:');
      for (final recommendation in recommendations) {
        buffer.writeln('  • $recommendation');
      }
    }
    
    return buffer.toString();
  }
}