import 'package:flutter/material.dart';

/// A widget that provides smooth transitions for content changes
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
    return AnimatedOpacity(
      duration: duration,
      curve: curve,
      opacity: show ? 1.0 : 0.0,
      child: AnimatedSlide(
        duration: duration,
        curve: curve,
        offset: show ? Offset.zero : const Offset(0, 0.1),
        child: AnimatedScale(
          duration: duration,
          curve: curve,
          scale: show ? 1.0 : 0.95,
          child: child,
        ),
      ),
    );
  }
}

/// A widget that provides a fade transition for lists
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
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      height: show ? null : 0,
      child: AnimatedOpacity(
        duration: duration,
        curve: curve,
        opacity: show ? 1.0 : 0.0,
        child: child,
      ),
    );
  }
}

/// A widget that provides a slide transition for messages
class AnimatedMessageTransition extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final bool isUser;

  const AnimatedMessageTransition({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: duration,
      curve: curve,
      offset: Offset(isUser ? 1.0 : -1.0, 0.0),
      child: AnimatedOpacity(
        duration: duration,
        curve: curve,
        opacity: 1.0,
        child: child,
      ),
    );
  }
}

/// A widget that provides a loading animation
class AnimatedLoadingIndicator extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const AnimatedLoadingIndicator({
    super.key,
    this.color = Colors.blue,
    this.size = 24.0,
    this.duration = const Duration(milliseconds: 1500),
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
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _animation.value * 2 * 3.14159,
          child: Icon(Icons.refresh, color: widget.color, size: widget.size),
        );
      },
    );
  }
}
