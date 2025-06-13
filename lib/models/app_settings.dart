class AppSettings {
  final String ollamaHost;
  final int ollamaPort;
  final double fontSize;
  final bool showLiveResponse;
  final int contextLength;
  final String systemPrompt; // System prompt to be applied to all new chats
  final bool
      thinkingBubbleDefaultExpanded; // Default state for thinking bubbles
  final bool thinkingBubbleAutoCollapse; // Auto-collapse when thinking ends
  final bool darkMode;

  AppSettings({
    this.ollamaHost = '127.0.0.1',
    this.ollamaPort = 11434,
    this.fontSize = 16.0,
    this.showLiveResponse = false,
    this.contextLength = 4096,
    this.systemPrompt = '', // Default empty system prompt
    this.thinkingBubbleDefaultExpanded =
        true, // Default to expanded for better UX
    this.thinkingBubbleAutoCollapse = false, // Don't auto-collapse by default
    this.darkMode = false,
  });

  String get ollamaUrl => 'http://$ollamaHost:$ollamaPort';

  AppSettings copyWith({
    String? ollamaHost,
    int? ollamaPort,
    double? fontSize,
    bool? showLiveResponse,
    int? contextLength,
    String? systemPrompt,
    bool? thinkingBubbleDefaultExpanded,
    bool? thinkingBubbleAutoCollapse,
  }) {
    return AppSettings(
      ollamaHost: ollamaHost ?? this.ollamaHost,
      ollamaPort: ollamaPort ?? this.ollamaPort,
      fontSize: fontSize ?? this.fontSize,
      showLiveResponse: showLiveResponse ?? this.showLiveResponse,
      contextLength: contextLength ?? this.contextLength,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      thinkingBubbleDefaultExpanded:
          thinkingBubbleDefaultExpanded ?? this.thinkingBubbleDefaultExpanded,
      thinkingBubbleAutoCollapse:
          thinkingBubbleAutoCollapse ?? this.thinkingBubbleAutoCollapse,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      ollamaHost: json['ollamaHost'] ?? '127.0.0.1',
      ollamaPort: json['ollamaPort'] ?? 11434,
      fontSize: json['fontSize'] ?? 16.0,
      showLiveResponse: json['showLiveResponse'] ?? false,
      contextLength: json['contextLength'] ?? 4096,
      systemPrompt: json['systemPrompt'] ?? '',
      darkMode: json['darkMode'] ?? false,
      thinkingBubbleDefaultExpanded:
          json['thinkingBubbleDefaultExpanded'] ?? true,
      thinkingBubbleAutoCollapse: json['thinkingBubbleAutoCollapse'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ollamaHost': ollamaHost,
      'ollamaPort': ollamaPort,
      'fontSize': fontSize,
      'showLiveResponse': showLiveResponse,
      'contextLength': contextLength,
      'systemPrompt': systemPrompt,
      'darkMode': darkMode,
      'thinkingBubbleDefaultExpanded': thinkingBubbleDefaultExpanded,
      'thinkingBubbleAutoCollapse': thinkingBubbleAutoCollapse,
    };
  }
}
