import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/custom_markdown_body.dart';
import '../widgets/thinking_indicator.dart';
import '../widgets/thinking_theme.dart';

/// Unified thinking bubble that handles both static (from Message) and live (streaming) content
/// Consolidates functionality from ThinkingBubble and LiveThinkingBubble
class UnifiedThinkingBubble extends StatefulWidget {
  final double fontSize;
  final bool showThinkingIndicator;

  // Static mode properties (for completed messages)
  final Message? message;
  final bool? isExpanded;
  final VoidCallback? onToggleExpanded;

  // Live mode properties (for streaming)
  final bool isLiveMode;
  final String? liveContent;
  final String? bubbleId;

  const UnifiedThinkingBubble({
    super.key,
    required this.fontSize,
    this.showThinkingIndicator = false,

    // Static mode
    this.message,
    this.isExpanded,
    this.onToggleExpanded,

    // Live mode
    this.isLiveMode = false,
    this.liveContent,
    this.bubbleId,
  }) : assert(
          (isLiveMode && bubbleId != null) || (!isLiveMode && message != null),
          'Either provide message for static mode or bubbleId for live mode',
        );

  /// Factory constructor for static thinking bubble (completed messages)
  factory UnifiedThinkingBubble.static({
    required Message message,
    required double fontSize,
    bool showThinkingIndicator = false,
    bool isExpanded = false,
    VoidCallback? onToggleExpanded,
  }) {
    return UnifiedThinkingBubble(
      message: message,
      fontSize: fontSize,
      showThinkingIndicator: showThinkingIndicator,
      isExpanded: isExpanded,
      onToggleExpanded: onToggleExpanded,
      isLiveMode: false,
    );
  }

  /// Factory constructor for live thinking bubble (streaming)
  factory UnifiedThinkingBubble.live({
    required String bubbleId,
    required double fontSize,
    bool showThinkingIndicator = false,
  }) {
    return UnifiedThinkingBubble(
      bubbleId: bubbleId,
      fontSize: fontSize,
      showThinkingIndicator: showThinkingIndicator,
      isLiveMode: true,
    );
  }

  @override
  State<UnifiedThinkingBubble> createState() => _UnifiedThinkingBubbleState();
}

class _UnifiedThinkingBubbleState extends State<UnifiedThinkingBubble>
    with TickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Live mode specific state
  bool _hasScheduledAutoCollapse = false;

  @override
  void initState() {
    super.initState();

    // Animation for expand/collapse
    _expandController = AnimationController(
      duration: ThinkingConstants.animationDuration,
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
    if (widget.isLiveMode) {
      _initializeLiveMode();
    } else {
      _initializeStaticMode();
    }

    _fadeController.forward();
  }

  void _initializeLiveMode() {
    // Set up live mode initialization after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final settings =
          Provider.of<SettingsProvider>(context, listen: false).settings;
      final chatProvider = Provider.of<ChatProvider?>(context, listen: false);

      // Initialize expansion state based on settings
      if (chatProvider != null && !chatProvider.isThinkingBubbleExpanded(widget.bubbleId!)) {
        if (settings.thinkingBubbleDefaultExpanded) {
          chatProvider.toggleThinkingBubble(widget.bubbleId!);
        }
      }

      // Set animation state
      final isExpanded =
          chatProvider?.isThinkingBubbleExpanded(widget.bubbleId!) ?? false;
      if (isExpanded) {
        _expandController.forward();
      }
    });
  }

  void _initializeStaticMode() {
    if (widget.isExpanded == true) {
      _expandController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(UnifiedThinkingBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.isLiveMode && widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded == true) {
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

  void _toggleExpansion() {
    if (widget.isLiveMode) {
      final chatProvider = Provider.of<ChatProvider?>(context, listen: false);
      if (chatProvider != null) {
        chatProvider.toggleThinkingBubble(widget.bubbleId!);

        final isExpanded =
            chatProvider.isThinkingBubbleExpanded(widget.bubbleId!);
        if (isExpanded) {
          _expandController.forward();
        } else {
          _expandController.reverse();
        }
      }
    } else {
      widget.onToggleExpanded?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLiveMode) {
      return _buildLiveMode();
    } else {
      return _buildStaticMode();
    }
  }

  Widget _buildLiveMode() {
    return Consumer2<ChatProvider, SettingsProvider>(
      builder: (context, chatProvider, settingsProvider, child) {
        if (!chatProvider.hasActiveThinkingBubble) {
          return const SizedBox.shrink();
        }

        final thinkingContent = chatProvider.currentThinkingContent;
        final colors = ThinkingTheme.getColors(context);
        final settings = settingsProvider.settings;

        // Auto-collapse logic
        _handleAutoCollapse(chatProvider, settings);

        return _buildBubbleContainer(
          colors: colors,
          isLive: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(
                title: chatProvider.isActiveChatGenerating
                    ? 'Thinking...'
                    : 'Thought Process',
                colors: colors,
                isLive: true,
                isExpanded:
                    chatProvider.isThinkingBubbleExpanded(widget.bubbleId!),
                showIndicator: widget.showThinkingIndicator ||
                    chatProvider.isActiveChatGenerating,
              ),
              SizeTransition(
                sizeFactor: _expandAnimation,
                child: _buildContent(
                  content: thinkingContent.isNotEmpty
                      ? thinkingContent
                      : 'Processing...',
                  colors: colors,
                  isLive: true,
                  isProcessing: thinkingContent.isEmpty,
                  selectable: !chatProvider.isGenerating,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStaticMode() {
    if (!widget.message!.hasThinking) {
      return const SizedBox.shrink();
    }

    final thinkingContent = widget.message!.thinkingContent!;
    final colors = ThinkingTheme.getColors(context);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: _buildBubbleContainer(
        colors: colors,
        isLive: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(
              title: 'Thinking',
              colors: colors,
              isLive: false,
              isExpanded: widget.isExpanded ?? false,
              showIndicator: widget.showThinkingIndicator,
              summary: widget.isExpanded != true
                  ? thinkingContent.thinkingSummary
                  : null,
            ),
            SizeTransition(
              sizeFactor: _expandAnimation,
              child: _buildContent(
                content: thinkingContent.thinkingText ?? '',
                colors: colors,
                isLive: false,
                selectable: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubbleContainer({
    required ThinkingColors colors,
    required bool isLive,
    required Widget child,
  }) {
    return Container(
      margin: ThinkingConstants.margin,
      decoration: BoxDecoration(
        color: isLive ? colors.liveBubbleBackground : colors.bubbleBackground,
        borderRadius: BorderRadius.circular(ThinkingConstants.borderRadius),
        border: Border.all(
          color: isLive ? colors.liveBorder : colors.border,
          width: ThinkingConstants.borderWidth,
        ),
        boxShadow: isLive ? null : ThinkingConstants.boxShadow,
      ),
      child: child,
    );
  }

  Widget _buildHeader({
    required String title,
    required ThinkingColors colors,
    required bool isLive,
    required bool isExpanded,
    required bool showIndicator,
    String? summary,
  }) {
    return InkWell(
      onTap: _toggleExpansion,
      borderRadius: const BorderRadius.vertical(
          top: Radius.circular(ThinkingConstants.borderRadius)),
      child: Padding(
        padding: ThinkingConstants.padding,
        child: Row(
          children: [
            // Thinking indicator or icon
            if (showIndicator)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ThinkingIndicator(
                  color: colors.icon,
                  size: ThinkingConstants.iconSize,
                ),
              )
            else
              Icon(
                Icons.psychology,
                size: ThinkingConstants.iconSize,
                color: colors.icon,
              ),

            const SizedBox(width: 8.0),

            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: widget.fontSize * 0.9,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),

            // Summary (when collapsed and available)
            if (!isExpanded && summary?.isNotEmpty == true) ...[
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  summary!,
                  style: TextStyle(
                    fontSize: widget.fontSize * 0.8,
                    color: colors.summary,
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
              turns: isExpanded ? 0.5 : 0.0,
              duration: ThinkingConstants.animationDuration,
              child: Icon(
                isLive ? Icons.expand_more : Icons.keyboard_arrow_down,
                size: ThinkingConstants.expandIconSize,
                color: colors.icon,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent({
    required String content,
    required ThinkingColors colors,
    required bool isLive,
    bool isProcessing = false,
    bool selectable = true,
  }) {
    return Container(
      padding: ThinkingConstants.contentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Divider
          Container(
            height: 1.0,
            color: colors.divider,
            margin: const EdgeInsets.only(bottom: 12.0),
          ),

          // Content
          if (content.isNotEmpty && !isProcessing)
            CustomMarkdownBody(
              data: content,
              fontSize: widget.fontSize * 0.9,
              selectable: selectable,
            )
          else
            Text(
              isProcessing ? 'Processing...' : content,
              style: TextStyle(
                fontSize: widget.fontSize * 0.9,
                fontStyle: FontStyle.italic,
                color: colors.summary,
              ),
            ),
        ],
      ),
    );
  }

  void _handleAutoCollapse(ChatProvider chatProvider, dynamic settings) {
    if (!chatProvider.isActiveChatGenerating &&
        !chatProvider.isInsideThinkingBlock &&
        settings.thinkingBubbleAutoCollapse &&
        chatProvider.isThinkingBubbleExpanded(widget.bubbleId!) &&
        !_hasScheduledAutoCollapse) {
      _hasScheduledAutoCollapse = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted &&
            chatProvider.isThinkingBubbleExpanded(widget.bubbleId!)) {
          _toggleExpansion();
        }
        if (mounted) {
          _hasScheduledAutoCollapse = false;
        }
      });
    }

    // Reset auto-collapse flag when thinking starts again
    if (chatProvider.isActiveChatGenerating && _hasScheduledAutoCollapse) {
      _hasScheduledAutoCollapse = false;
    }
  }
}
