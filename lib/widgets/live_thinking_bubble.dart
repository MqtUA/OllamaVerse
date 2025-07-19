import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/custom_markdown_body.dart';
import '../widgets/thinking_indicator.dart';
import '../theme/dracula_theme.dart';

/// A live thinking bubble that displays thinking content in real-time during streaming
class LiveThinkingBubble extends StatefulWidget {
  final double fontSize;
  final bool showThinkingIndicator;

  const LiveThinkingBubble({
    super.key,
    required this.fontSize,
    this.showThinkingIndicator = false,
  });

  @override
  State<LiveThinkingBubble> createState() => _LiveThinkingBubbleState();
}

class _LiveThinkingBubbleState extends State<LiveThinkingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  static const String _liveThinkingBubbleId = 'live_thinking_bubble';
  bool _hasScheduledAutoCollapse = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Get default expansion state from settings and set in ChatProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check if widget is still mounted before accessing context
      if (!mounted) return;

      final settings =
          Provider.of<SettingsProvider>(context, listen: false).settings;
      final chatProvider = Provider.of<ChatProvider?>(context, listen: false);

      // Initialize the expansion state in ChatProvider if not already set
      if (chatProvider != null && !chatProvider.isThinkingBubbleExpanded(_liveThinkingBubbleId)) {
        if (settings.thinkingBubbleDefaultExpanded) {
          chatProvider.toggleThinkingBubble(_liveThinkingBubbleId);
        }
      }

      // Set animation state based on ChatProvider state
      final isExpanded =
          chatProvider?.isThinkingBubbleExpanded(_liveThinkingBubbleId) ?? false;
      if (isExpanded) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    final chatProvider = Provider.of<ChatProvider?>(context, listen: false);
    chatProvider?.toggleThinkingBubble(_liveThinkingBubbleId);

    // Update animation based on new state
    final isExpanded =
        chatProvider?.isThinkingBubbleExpanded(_liveThinkingBubbleId) ?? false;
    if (isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ChatProvider, SettingsProvider>(
      builder: (context, chatProvider, settingsProvider, child) {
        if (!chatProvider.hasActiveThinkingBubble) {
          return const SizedBox.shrink();
        }

        final thinkingContent = chatProvider.currentThinkingContent;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final settings = settingsProvider.settings;

        // Auto-collapse logic: if thinking is complete and auto-collapse is enabled
        if (!chatProvider.isActiveChatGenerating &&
            !chatProvider.isInsideThinkingBlock &&
            settings.thinkingBubbleAutoCollapse &&
            chatProvider.isThinkingBubbleExpanded(_liveThinkingBubbleId) &&
            !_hasScheduledAutoCollapse) {
          // Schedule auto-collapse only once
          _hasScheduledAutoCollapse = true;
          Future.delayed(const Duration(milliseconds: 500), () {
            // Double-check mounted state before accessing context or state
            if (mounted &&
                chatProvider.isThinkingBubbleExpanded(_liveThinkingBubbleId)) {
              _toggleExpansion();
            }
            // Reset the flag after the delay
            if (mounted) {
              _hasScheduledAutoCollapse = false;
            }
          });
        }

        // Reset auto-collapse flag when thinking starts again
        if (chatProvider.isActiveChatGenerating && _hasScheduledAutoCollapse) {
          _hasScheduledAutoCollapse = false;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8.0),
          decoration: BoxDecoration(
            color: isDark
                ? DraculaColors.purple.withAlpha(51)
                : Colors.purple.shade50,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: isDark
                  ? DraculaColors.purple.withAlpha(128)
                  : Colors.purple.shade200,
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with thinking indicator and expand/collapse button
              InkWell(
                onTap: _toggleExpansion,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12.0)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      // Thinking indicator
                      if (widget.showThinkingIndicator ||
                          chatProvider.isActiveChatGenerating)
                        ThinkingIndicator(
                          color: isDark
                              ? DraculaColors.purple
                              : Colors.purple.shade600,
                          size: 16.0,
                        )
                      else
                        Icon(
                          Icons.psychology,
                          size: 16.0,
                          color: isDark
                              ? DraculaColors.purple
                              : Colors.purple.shade600,
                        ),
                      const SizedBox(width: 8.0),

                      // Title
                      Expanded(
                        child: Text(
                          chatProvider.isActiveChatGenerating
                              ? 'Thinking...'
                              : 'Thought Process',
                          style: TextStyle(
                            fontSize: widget.fontSize * 0.9,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? DraculaColors.purple
                                : Colors.purple.shade700,
                          ),
                        ),
                      ),

                      // Expand/collapse button
                      AnimatedRotation(
                        turns: chatProvider
                                .isThinkingBubbleExpanded(_liveThinkingBubbleId)
                            ? 0.5
                            : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.expand_more,
                          color: isDark
                              ? DraculaColors.purple
                              : Colors.purple.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Thinking content (expandable)
              SizeTransition(
                sizeFactor: _expandAnimation,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 8.0),

                      // Thinking content
                      if (thinkingContent.isNotEmpty)
                        CustomMarkdownBody(
                          data: thinkingContent,
                          fontSize: widget.fontSize * 0.9,
                          selectable: !chatProvider
                              .isGenerating, // Disable selection during streaming
                        )
                      else
                        Text(
                          'Processing...',
                          style: TextStyle(
                            fontSize: widget.fontSize * 0.9,
                            fontStyle: FontStyle.italic,
                            color: isDark
                                ? DraculaColors.comment
                                : Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
