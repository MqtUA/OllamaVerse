import 'package:flutter/material.dart';

/// A widget that provides smooth transitions for content changes
/// Performance optimized with RepaintBoundary and reduced complexity
class AnimatedTransition extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final bool show;

  const AnimatedTransition({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.show = true,
  });

  @override
  Widget build(BuildContext context) {
    // Performance optimization: RepaintBoundary to isolate repaints
    return RepaintBoundary(
      child: AnimatedOpacity(
        duration: duration,
        curve: curve,
        opacity: show ? 1.0 : 0.0,
        child: AnimatedSlide(
          duration: duration,
          curve: curve,
          offset: show
              ? Offset.zero
              : const Offset(0, 0.05), // Reduced slide distance
          child: AnimatedScale(
            duration: duration,
            curve: curve,
            scale: show ? 1.0 : 0.98, // Reduced scale for smoother animation
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A widget that provides a fade transition for lists
/// Performance optimized with conditional rendering
class AnimatedListTransition extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final bool show;

  const AnimatedListTransition({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.show = true,
  });

  @override
  Widget build(BuildContext context) {
    // Performance optimization: early return if not showing
    if (!show) {
      return const SizedBox.shrink();
    }

    // Performance optimization: RepaintBoundary for list items
    return RepaintBoundary(
      child: AnimatedContainer(
        duration: duration,
        curve: curve,
        height: show ? null : 0,
        child: AnimatedOpacity(
          duration: duration,
          curve: curve,
          opacity: show ? 1.0 : 0.0,
          child: child,
        ),
      ),
    );
  }
}

/// A widget that provides a slide transition for messages
/// Performance optimized with reduced slide distance
class AnimatedMessageTransition extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final bool isUser;

  const AnimatedMessageTransition({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 250), // Slightly faster
    this.curve = Curves.easeInOut,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    // Performance optimization: RepaintBoundary for message items
    return RepaintBoundary(
      child: AnimatedSlide(
        duration: duration,
        curve: curve,
        offset: Offset(
            isUser ? 0.5 : -0.5, 0.0), // Reduced slide distance for performance
        child: AnimatedOpacity(
          duration: duration,
          curve: curve,
          opacity: 1.0,
          child: child,
        ),
      ),
    );
  }
}

/// A widget that provides a loading animation
/// Performance optimized with lighter animation and caching
class AnimatedLoadingIndicator extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const AnimatedLoadingIndicator({
    super.key,
    this.color = Colors.blue,
    this.size = 24.0,
    this.duration = const Duration(milliseconds: 1200), // Slightly faster
  });

  @override
  State<AnimatedLoadingIndicator> createState() =>
      _AnimatedLoadingIndicatorState();
}

class _AnimatedLoadingIndicatorState extends State<AnimatedLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();

    // Performance optimization: use more efficient rotation animation
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear, // Linear is more efficient for rotation
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Performance optimization: RepaintBoundary with cached child
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.rotate(
            angle: _animation.value * 2 * 3.14159,
            child: child, // Use cached child
          );
        },
        child: Icon(
          Icons.refresh,
          color: widget.color,
          size: widget.size,
        ),
      ),
    );
  }
}

/// Performance optimized bounce animation for interactive elements
class AnimatedBounceTransition extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Duration duration;

  const AnimatedBounceTransition({
    super.key,
    required this.child,
    this.onTap,
    this.duration = const Duration(milliseconds: 100),
  });

  @override
  State<AnimatedBounceTransition> createState() =>
      _AnimatedBounceTransitionState();
}

class _AnimatedBounceTransitionState extends State<AnimatedBounceTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95, // Subtle bounce for better performance
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() async {
    await _controller.forward();
    await _controller.reverse();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: widget.child,
            );
          },
        ),
      ),
    );
  }
}
