import 'package:flutter/material.dart';

/// A widget that provides smooth theme switching animations
/// Optimized for performance with minimal rebuilds
class AnimatedThemeSwitcher extends StatefulWidget {
  final Widget child;
  final ThemeMode themeMode;
  final Duration duration;
  final Curve curve;

  const AnimatedThemeSwitcher({
    super.key,
    required this.child,
    required this.themeMode,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOutCubic,
  });

  @override
  State<AnimatedThemeSwitcher> createState() => _AnimatedThemeSwitcherState();
}

class _AnimatedThemeSwitcherState extends State<AnimatedThemeSwitcher>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Performance optimization: only animate when actually changing
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    // Performance optimization: use more efficient animation curves
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95, // Reduced effect for better performance
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0.0, 0.5, curve: widget.curve),
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.99, // Reduced scale for smoother animation
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0.0, 0.5, curve: widget.curve),
    ));

    // Performance optimization: add animation status listener
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        if (mounted) {
          setState(() {
            _isAnimating = false;
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(AnimatedThemeSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Performance optimization: only animate on actual theme changes
    if (oldWidget.themeMode != widget.themeMode && !_isAnimating) {
      _animateThemeChange();
    }

    // Update controller duration if changed
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  void _animateThemeChange() async {
    if (!mounted || _isAnimating) return;

    setState(() {
      _isAnimating = true;
    });

    try {
      await _controller.forward();
      if (mounted) {
        await _controller.reverse();
      }
    } catch (e) {
      // Handle animation errors gracefully
      if (mounted) {
        setState(() {
          _isAnimating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Performance optimization: avoid unnecessary rebuilds
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

/// A widget that provides status indicator animations
/// Optimized for performance with smart animation management
class AnimatedStatusIndicator extends StatefulWidget {
  final bool isConnected;
  final bool isLoading;
  final Duration animationDuration;
  final Color connectedColor;
  final Color disconnectedColor;
  final Color loadingColor;

  const AnimatedStatusIndicator({
    super.key,
    required this.isConnected,
    this.isLoading = false,
    this.animationDuration = const Duration(milliseconds: 500),
    this.connectedColor = Colors.green,
    this.disconnectedColor = Colors.red,
    this.loadingColor = Colors.orange,
  });

  @override
  State<AnimatedStatusIndicator> createState() =>
      _AnimatedStatusIndicatorState();
}

class _AnimatedStatusIndicatorState extends State<AnimatedStatusIndicator>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _colorController;
  late Animation<double> _pulseAnimation;
  late Animation<Color?> _colorAnimation;

  // Performance optimization: cache previous loading state
  bool _wasLoading = false;

  @override
  void initState() {
    super.initState();

    _wasLoading = widget.isLoading;

    // Performance optimization: shorter pulse duration for loading
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800), // Faster pulse
      vsync: this,
    );

    _colorController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    // Performance optimization: reduced pulse scale
    _pulseAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1, // Smaller scale for better performance
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _updateColorAnimation();

    if (widget.isLoading) {
      _pulseController.repeat(reverse: true);
    }
  }

  void _updateColorAnimation() {
    final targetColor = widget.isLoading
        ? widget.loadingColor
        : widget.isConnected
            ? widget.connectedColor
            : widget.disconnectedColor;

    _colorAnimation = ColorTween(
      begin: _colorAnimation.value ?? targetColor,
      end: targetColor,
    ).animate(CurvedAnimation(
      parent: _colorController,
      curve: Curves.easeInOut,
    ));

    _colorController.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(AnimatedStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Performance optimization: only update when state actually changes
    final loadingChanged = oldWidget.isLoading != widget.isLoading;
    final connectionChanged = oldWidget.isConnected != widget.isConnected;

    if (loadingChanged || connectionChanged) {
      _updateColorAnimation();

      // Performance optimization: smart pulse management
      if (widget.isLoading && !_wasLoading) {
        _pulseController.repeat(reverse: true);
      } else if (!widget.isLoading && _wasLoading) {
        _pulseController.stop();
        _pulseController.reset();
      }

      _wasLoading = widget.isLoading;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Performance optimization: RepaintBoundary to isolate repaints
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _colorController]),
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isLoading ? _pulseAnimation.value : 1.0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _colorAnimation.value,
                boxShadow: widget.isLoading
                    ? [
                        BoxShadow(
                          color: (_colorAnimation.value ?? Colors.transparent)
                              .withValues(
                                  alpha:
                                      0.3), // Reduced shadow opacity for performance
                          blurRadius: 3, // Reduced blur for performance
                          spreadRadius: 0.5,
                        ),
                      ]
                    : null, // No shadow when not loading for better performance
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A widget that provides smooth model switching animations
/// Performance optimized with caching and smart rebuilds
class AnimatedModelSelector extends StatefulWidget {
  final String selectedModel;
  final List<String> models;
  final Function(String) onModelSelected;
  final Duration animationDuration;

  const AnimatedModelSelector({
    super.key,
    required this.selectedModel,
    required this.models,
    required this.onModelSelected,
    this.animationDuration =
        const Duration(milliseconds: 150), // Faster for better UX
  });

  @override
  State<AnimatedModelSelector> createState() => _AnimatedModelSelectorState();
}

class _AnimatedModelSelectorState extends State<AnimatedModelSelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  // Performance optimization: track animation state
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    // Performance optimization: reduced scale for smoother animation
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02, // Smaller scale change
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _colorAnimation = ColorTween(
      begin: Colors.transparent,
      end: Theme.of(context)
          .primaryColor
          .withValues(alpha: 0.08), // Reduced opacity
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Performance optimization: add status listener
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        if (mounted) {
          setState(() {
            _isAnimating = false;
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(AnimatedModelSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Performance optimization: only animate on actual model changes
    if (oldWidget.selectedModel != widget.selectedModel && !_isAnimating) {
      _animateModelChange();
    }
  }

  void _animateModelChange() async {
    if (!mounted || _isAnimating) return;

    setState(() {
      _isAnimating = true;
    });

    try {
      await _controller.forward();
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 50)); // Shorter delay
        await _controller.reverse();
      }
    } catch (e) {
      // Handle animation errors gracefully
      if (mounted) {
        setState(() {
          _isAnimating = false;
        });
      }
    }
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
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: _colorAnimation.value,
                borderRadius: BorderRadius.circular(8),
              ),
              child: child,
            ),
          );
        },
        child: DropdownButton<String>(
          value: widget.selectedModel.isEmpty ? null : widget.selectedModel,
          items: widget.models.map((model) {
            return DropdownMenuItem<String>(
              value: model,
              child: Text(model),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              widget.onModelSelected(newValue);
            }
          },
        ),
      ),
    );
  }
}
