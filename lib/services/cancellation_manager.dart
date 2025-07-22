import '../utils/cancellation_token.dart';
import '../utils/logger.dart';

/// Service responsible for managing cancellation tokens and coordinating operation cancellation
/// 
/// Provides centralized cancellation management to ensure operations can be cancelled
/// cleanly without leaving the system in an inconsistent state.
class CancellationManager {
  final Map<String, CancellationToken> _activeTokens = {};
  bool _disposed = false;

  /// Create a new cancellation token
  CancellationToken createToken() {
    if (_disposed) {
      throw StateError('CancellationManager has been disposed');
    }

    final token = CancellationToken();
    final tokenId = DateTime.now().millisecondsSinceEpoch.toString();
    _activeTokens[tokenId] = token;

    AppLogger.debug('Created cancellation token: $tokenId');
    return token;
  }

  /// Cancel all active tokens
  void cancelAll() {
    if (_disposed) return;

    AppLogger.info('Cancelling all active operations (${_activeTokens.length} tokens)');
    
    for (final entry in _activeTokens.entries) {
      try {
        entry.value.cancel();
        AppLogger.debug('Cancelled token: ${entry.key}');
      } catch (e) {
        AppLogger.error('Error cancelling token ${entry.key}', e);
      }
    }

    _cleanup();
  }

  /// Cancel a specific token by ID
  void cancelToken(String tokenId) {
    if (_disposed) return;

    final token = _activeTokens[tokenId];
    if (token != null) {
      try {
        token.cancel();
        _activeTokens.remove(tokenId);
        AppLogger.debug('Cancelled specific token: $tokenId');
      } catch (e) {
        AppLogger.error('Error cancelling token $tokenId', e);
      }
    }
  }

  /// Check if a token is cancelled
  bool isTokenCancelled(String tokenId) {
    if (_disposed) return true;

    final token = _activeTokens[tokenId];
    return token?.isCancelled ?? true;
  }

  /// Get the number of active tokens
  int get activeTokenCount => _disposed ? 0 : _activeTokens.length;

  /// Check if any tokens are active
  bool get hasActiveTokens => !_disposed && _activeTokens.isNotEmpty;

  /// Clean up cancelled or completed tokens
  void cleanup() {
    if (_disposed) return;

    _cleanup();
  }

  void _cleanup() {
    final cancelledTokens = <String>[];
    
    for (final entry in _activeTokens.entries) {
      if (entry.value.isCancelled) {
        cancelledTokens.add(entry.key);
      }
    }

    for (final tokenId in cancelledTokens) {
      _activeTokens.remove(tokenId);
    }

    if (cancelledTokens.isNotEmpty) {
      AppLogger.debug('Cleaned up ${cancelledTokens.length} cancelled tokens');
    }
  }

  /// Get status information about active tokens
  Map<String, dynamic> getStatus() {
    if (_disposed) {
      return {
        'disposed': true,
        'activeTokens': 0,
        'tokens': <String, bool>{},
      };
    }

    return {
      'disposed': false,
      'activeTokens': _activeTokens.length,
      'tokens': _activeTokens.map((key, value) => MapEntry(key, value.isCancelled)),
    };
  }

  /// Dispose of the cancellation manager
  void dispose() {
    if (_disposed) return;

    AppLogger.info('Disposing CancellationManager');
    
    // Cancel all remaining tokens
    cancelAll();
    
    _disposed = true;
  }

  /// Check if the manager has been disposed
  bool get isDisposed => _disposed;
}