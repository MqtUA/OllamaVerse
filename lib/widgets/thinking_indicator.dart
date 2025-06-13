import 'package:flutter/material.dart';

/// Optimized thinking indicator with shared animation controller
class ThinkingIndicator extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const ThinkingIndicator({
    super.key,
    this.color = Colors.grey,
    this.size = 16.0,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
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
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDot(0.0),
          const SizedBox(width: 4),
          _buildDot(0.15),
          const SizedBox(width: 4),
          _buildDot(0.3),
        ],
      ),
    );
  }

  Widget _buildDot(double delay) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final progress = (_animation.value + delay) % 1.0;
        final opacity = (progress < 0.5) ? (progress * 2) : (2 - progress * 2);

        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: opacity.clamp(0.3, 1.0)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

/// Optimized pulsing thinking indicator for heavy thinking operations
class PulsingThinkingIndicator extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const PulsingThinkingIndicator({
    super.key,
    this.color = Colors.grey,
    this.size = 20.0,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<PulsingThinkingIndicator> createState() =>
      _PulsingThinkingIndicatorState();
}

class _PulsingThinkingIndicatorState extends State<PulsingThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
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

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Icon(
              Icons.psychology,
              color: widget.color.withValues(alpha: _opacityAnimation.value),
              size: widget.size,
            ),
          );
        },
      ),
    );
  }
}

/// Optimized wave thinking indicator with single controller
class WaveThinkingIndicator extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const WaveThinkingIndicator({
    super.key,
    this.color = Colors.grey,
    this.size = 16.0,
    this.duration = const Duration(milliseconds: 1000),
  });

  @override
  State<WaveThinkingIndicator> createState() => _WaveThinkingIndicatorState();
}

class _WaveThinkingIndicatorState extends State<WaveThinkingIndicator>
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
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) => _buildWaveDot(index)),
      ),
    );
  }

  Widget _buildWaveDot(int index) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final progress = (_animation.value + index * 0.1) % 1.0;
        final height = widget.size *
            (0.5 + 0.5 * (1 - (progress - 0.5).abs() * 2).clamp(0.0, 1.0));

        return Container(
          width: 3,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      },
    );
  }
}

/// Optimized typing indicator for text generation
class TypingThinkingIndicator extends StatefulWidget {
  final Color color;
  final double size;
  final Duration duration;

  const TypingThinkingIndicator({
    super.key,
    this.color = Colors.grey,
    this.size = 16.0,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<TypingThinkingIndicator> createState() =>
      _TypingThinkingIndicatorState();
}

class _TypingThinkingIndicatorState extends State<TypingThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();

    _animation = IntTween(
      begin: 0,
      end: 3,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final text = '.' * (_animation.value + 1);
          return Text(
            'Thinking$text',
            style: TextStyle(
              color: widget.color,
              fontSize: widget.size * 0.8,
              fontStyle: FontStyle.italic,
            ),
          );
        },
      ),
    );
  }
}
