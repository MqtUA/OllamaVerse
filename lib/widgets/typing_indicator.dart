import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(26), // 0.1 * 255 ≈ 26
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDot(0.0),
              const SizedBox(width: 4),
              _buildDot(0.2),
              const SizedBox(width: 4),
              _buildDot(0.4),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDot(double delay) {
    final delayedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay,
        delay + 0.5,
        curve: Curves.easeInOut,
      ),
    );

    return Transform.translate(
      offset: Offset(0, -4.0 * delayedAnimation.value),
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
