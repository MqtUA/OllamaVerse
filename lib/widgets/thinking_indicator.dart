import 'package:flutter/material.dart';

/// A widget that displays an animated thinking indicator
class ThinkingIndicator extends StatefulWidget {
  final Color? color;
  final double size;
  final Duration duration;

  const ThinkingIndicator({
    super.key,
    this.color,
    this.size = 24.0,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.purple.shade300
            : Colors.blue.shade600);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulsing circle
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: effectiveColor.withValues(
                      alpha: 0.1 + _animation.value * 0.1),
                  border: Border.all(
                    color: effectiveColor.withValues(
                        alpha: 0.3 + _animation.value * 0.4),
                    width: 1.0,
                  ),
                ),
              ),

              // Inner brain icon
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 0.7 + _animation.value * 0.1,
                    child: Icon(
                      Icons.psychology,
                      size: widget.size * 0.6,
                      color: effectiveColor.withValues(
                          alpha: 0.7 + _animation.value * 0.3),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A more complex thinking indicator with multiple dots
class ThinkingDotsIndicator extends StatefulWidget {
  final Color? color;
  final double size;
  final Duration duration;
  final int dotCount;

  const ThinkingDotsIndicator({
    super.key,
    this.color,
    this.size = 24.0,
    this.duration = const Duration(milliseconds: 1500),
    this.dotCount = 3,
  });

  @override
  State<ThinkingDotsIndicator> createState() => _ThinkingDotsIndicatorState();
}

class _ThinkingDotsIndicatorState extends State<ThinkingDotsIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(widget.dotCount, (index) {
      return AnimationController(
        duration: widget.duration,
        vsync: this,
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0.4,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ));
    }).toList();

    // Start animations with delays
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.purple.shade300
            : Colors.blue.shade600);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.dotCount, (index) {
          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Container(
                margin: EdgeInsets.symmetric(
                  horizontal: widget.size * 0.05,
                ),
                child: Transform.scale(
                  scale: _animations[index].value,
                  child: Container(
                    width: widget.size * 0.2,
                    height: widget.size * 0.2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: effectiveColor.withValues(
                          alpha: _animations[index].value),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// A text-based thinking indicator
class ThinkingTextIndicator extends StatefulWidget {
  final Color? color;
  final double fontSize;
  final Duration duration;

  const ThinkingTextIndicator({
    super.key,
    this.color,
    this.fontSize = 14.0,
    this.duration = const Duration(milliseconds: 2000),
  });

  @override
  State<ThinkingTextIndicator> createState() => _ThinkingTextIndicatorState();
}

class _ThinkingTextIndicatorState extends State<ThinkingTextIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;

  final List<String> _thinkingTexts = [
    'Thinking...',
    'Analyzing...',
    'Reasoning...',
    'Processing...',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = IntTween(
      begin: 0,
      end: _thinkingTexts.length - 1,
    ).animate(_controller);

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.purple.shade300
            : Colors.blue.shade600);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          _thinkingTexts[_animation.value],
          style: TextStyle(
            color: effectiveColor,
            fontSize: widget.fontSize,
            fontStyle: FontStyle.italic,
          ),
        );
      },
    );
  }
}
