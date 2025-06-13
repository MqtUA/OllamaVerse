import 'package:flutter/material.dart';
import '../utils/logger.dart';

/// A comprehensive error boundary widget that catches and handles widget errors
/// Provides fallback UI and error reporting functionality
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget? fallback;
  final String? errorTitle;
  final String? errorMessage;
  final VoidCallback? onError;
  final bool showDetails;
  final bool enableRecovery;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
    this.errorTitle,
    this.errorMessage,
    this.onError,
    this.showDetails = false,
    this.enableRecovery = true,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;
  bool _hasError = false;
  int _errorCount = 0;

  @override
  void initState() {
    super.initState();

    // Set up Flutter error handling for this boundary
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleError(details.exception, details.stack);
    };
  }

  void _handleError(Object error, StackTrace? stackTrace) {
    setState(() {
      _error = error;
      _stackTrace = stackTrace;
      _hasError = true;
      _errorCount++;
    });

    // Log the error
    AppLogger.error('ErrorBoundary caught error', error, stackTrace);

    // Call custom error handler if provided
    widget.onError?.call();
  }

  void _recover() {
    setState(() {
      _error = null;
      _stackTrace = null;
      _hasError = false;
    });
  }

  Widget _buildErrorWidget() {
    return widget.fallback ?? _buildDefaultErrorWidget();
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade300),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red.shade700,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.errorTitle ?? 'Something went wrong',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.errorMessage ??
                'An unexpected error occurred. The app will try to recover automatically.',
            style: TextStyle(
              color: Colors.red.shade600,
              fontSize: 14,
            ),
          ),
          if (widget.showDetails && _error != null) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              title: Text(
                'Error Details',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Error: ${_error.toString()}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                      if (_stackTrace != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Stack trace:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _stackTrace.toString(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                          maxLines: 10,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (widget.enableRecovery) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _recover,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ],
          if (_errorCount > 1) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning,
                    color: Colors.orange.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This error has occurred $_errorCount times. Consider restarting the app.',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorWidget();
    }

    // Wrap child with error handling
    return _ErrorBoundaryWrapper(
      onError: _handleError,
      child: widget.child,
    );
  }
}

/// Internal wrapper that catches errors during widget building
class _ErrorBoundaryWrapper extends StatelessWidget {
  final Widget child;
  final Function(Object, StackTrace?) onError;

  const _ErrorBoundaryWrapper({
    required this.child,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return child;
    } catch (error, stackTrace) {
      onError(error, stackTrace);
      return const SizedBox.shrink();
    }
  }
}

/// A simpler error boundary for non-critical UI components
class SimpleErrorBoundary extends StatelessWidget {
  final Widget child;
  final Widget? fallback;

  const SimpleErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      fallback: fallback ??
          Container(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning,
                  color: Colors.orange.shade600,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Content unavailable',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      showDetails: false,
      enableRecovery: false,
      child: child,
    );
  }
}

/// Error boundary specifically designed for chat messages
class MessageErrorBoundary extends StatelessWidget {
  final Widget child;
  final String? messageId;

  const MessageErrorBoundary({
    super.key,
    required this.child,
    this.messageId,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      errorTitle: 'Message Error',
      errorMessage:
          'Failed to display this message${messageId != null ? ' (ID: $messageId)' : ''}',
      fallback: Container(
        padding: const EdgeInsets.all(12.0),
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade600,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Message failed to load',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
      showDetails: false,
      enableRecovery: true,
      child: child,
    );
  }
}

/// Error boundary for service operations with retry functionality
class ServiceErrorBoundary extends StatefulWidget {
  final Widget child;
  final String serviceName;
  final Future<void> Function()? onRetry;

  const ServiceErrorBoundary({
    super.key,
    required this.child,
    required this.serviceName,
    this.onRetry,
  });

  @override
  State<ServiceErrorBoundary> createState() => _ServiceErrorBoundaryState();
}

class _ServiceErrorBoundaryState extends State<ServiceErrorBoundary> {
  bool _isRetrying = false;

  Future<void> _handleRetry() async {
    if (widget.onRetry != null && !_isRetrying) {
      setState(() {
        _isRetrying = true;
      });

      try {
        await widget.onRetry!();
      } catch (error) {
        AppLogger.error('Service retry failed', error);
      } finally {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      errorTitle: '${widget.serviceName} Error',
      errorMessage: 'The ${widget.serviceName} service encountered an error',
      fallback: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              color: Colors.grey.shade600,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.serviceName} Unavailable',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'The service is temporarily unavailable. Please try again.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isRetrying ? null : _handleRetry,
                child: _isRetrying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
      showDetails: true,
      enableRecovery: true,
      child: widget.child,
    );
  }
}
