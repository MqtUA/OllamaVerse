import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/thinking_model_detection_service.dart';
import '../theme/dracula_theme.dart';
import '../theme/material_light_theme.dart';
import 'custom_markdown_body.dart';
import 'thinking_indicator.dart';

/// A widget that displays thinking content with expand/collapse functionality
class ThinkingBubble extends StatefulWidget {
  final Message message;
  final double fontSize;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;
  final bool showThinkingIndicator;

  const ThinkingBubble({
    super.key,
    required this.message,
    required this.fontSize,
    this.isExpanded = false,
    this.onToggleExpanded,
    this.showThinkingIndicator = false,
  });

  @override
  State<ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<ThinkingBubble>
    with TickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Animation for expand/collapse
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );

    // Animation for fade in/out
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    // Set initial state
    if (widget.isExpanded) {
      _expandController.value = 1.0;
    }
    _fadeController.forward();
  }

  @override
  void didUpdateWidget(ThinkingBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.message.hasThinking) {
      return const SizedBox.shrink();
    }

    final thinkingContent = widget.message.thinkingContent!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        decoration: BoxDecoration(
          color: _getThinkingBubbleColor(isDark),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: _getThinkingBorderColor(isDark),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(26), // 0.1 * 255 ≈ 26
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thinking header with toggle button
            _buildThinkingHeader(thinkingContent, isDark),

            // Expandable thinking content
            SizeTransition(
              sizeFactor: _expandAnimation,
              child: _buildThinkingContent(thinkingContent, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThinkingHeader(ThinkingContent thinkingContent, bool isDark) {
    return InkWell(
      onTap: widget.onToggleExpanded,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Thinking indicator icon/animation
            if (widget.showThinkingIndicator)
              const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: ThinkingIndicator(size: 16.0),
              )
            else
              Icon(
                Icons.psychology,
                size: 16.0,
                color: _getThinkingIconColor(isDark),
              ),

            const SizedBox(width: 8.0),

            // "Thinking" label
            Text(
              'Thinking',
              style: TextStyle(
                fontSize: widget.fontSize * 0.9,
                fontWeight: FontWeight.w600,
                color: _getThinkingTextColor(isDark),
              ),
            ),

            // Summary (when collapsed)
            if (!widget.isExpanded &&
                thinkingContent.thinkingSummary.isNotEmpty) ...[
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  thinkingContent.thinkingSummary,
                  style: TextStyle(
                    fontSize: widget.fontSize * 0.8,
                    color: _getThinkingSummaryColor(isDark),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            const Spacer(),

            // Expand/collapse button
            AnimatedRotation(
              turns: widget.isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 20.0,
                color: _getThinkingIconColor(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThinkingContent(ThinkingContent thinkingContent, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Divider
          Container(
            height: 1.0,
            color: _getThinkingDividerColor(isDark),
            margin: const EdgeInsets.only(bottom: 12.0),
          ),

          // Thinking content
          if (thinkingContent.thinkingText?.isNotEmpty ?? false)
            CustomMarkdownBody(
              data: thinkingContent.thinkingText!,
              fontSize: widget.fontSize * 0.9,
              selectable: true,
              onTapLink: (text, href, title) {
                if (href != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Link tapped: $href')),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  // Theme-aware color methods
  Color _getThinkingBubbleColor(bool isDark) {
    return isDark
        ? DraculaColors.background.withAlpha(128) // Darker with transparency
        : MaterialLightColors.surfaceVariant
            .withAlpha(179); // Light with transparency
  }

  Color _getThinkingBorderColor(bool isDark) {
    return isDark
        ? DraculaColors.purple.withAlpha(102) // Purple border for dark theme
        : MaterialLightColors.primary
            .withAlpha(77); // Primary color border for light
  }

  Color _getThinkingIconColor(bool isDark) {
    return isDark ? DraculaColors.purple : MaterialLightColors.primary;
  }

  Color _getThinkingTextColor(bool isDark) {
    return isDark ? DraculaColors.purple : MaterialLightColors.primary;
  }

  Color _getThinkingSummaryColor(bool isDark) {
    return isDark
        ? DraculaColors.comment
        : MaterialLightColors.onSurfaceVariant;
  }

  Color _getThinkingDividerColor(bool isDark) {
    return isDark
        ? DraculaColors.selection
        : MaterialLightColors.outline.withAlpha(128);
  }
}
