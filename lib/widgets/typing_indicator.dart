import 'package:flutter/material.dart';

/// Performance optimized typing indicator with cached animations
class TypingIndicator extends StatefulWidget {
  final double size;
  final Color color;

  const TypingIndicator({
    super.key,
    this.size = 10.0,
    this.color = Colors.grey,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Performance optimization: cache animations
  late List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 1000), // Slightly faster for better UX
    )..repeat();

    // Performance optimization: create animations once and cache them
    _dotAnimations = [
      _createDotAnimation(0.0),
      _createDotAnimation(0.2),
      _createDotAnimation(0.4),
    ];
  }

  /// Creates an optimized dot animation with caching
  Animation<double> _createDotAnimation(double delay) {
    return Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay,
        delay + 0.5,
        curve: Curves.easeInOut,
      ),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Performance optimization: RepaintBoundary to isolate repaints
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withAlpha(20), // Reduced shadow for performance
                  blurRadius: 1.5, // Reduced blur for performance
                  offset: const Offset(0, 0.5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Performance optimized dot builder using cached animations
  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _dotAnimations[index],
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
              0,
              -3.0 *
                  _dotAnimations[index]
                      .value), // Reduced translation for smoother animation
          child: child,
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
