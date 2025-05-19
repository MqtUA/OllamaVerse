class AppSettings {
  final String ollamaHost;
  final int ollamaPort;
  final String authToken;
  final double fontSize;
  final bool darkMode;
  final bool showLiveResponse;
  final int contextLength;

  AppSettings({
    this.ollamaHost = '127.0.0.1',
    this.ollamaPort = 11434,
    this.authToken = '',
    this.fontSize = 16.0,
    this.darkMode = false,
    this.showLiveResponse = false,
    this.contextLength = 4096,
  });

  String get ollamaUrl => 'http://$ollamaHost:$ollamaPort';

  AppSettings copyWith({
    String? ollamaHost,
    int? ollamaPort,
    String? authToken,
    double? fontSize,
    bool? darkMode,
    bool? showLiveResponse,
    int? contextLength,
  }) {
    return AppSettings(
      ollamaHost: ollamaHost ?? this.ollamaHost,
      ollamaPort: ollamaPort ?? this.ollamaPort,
      authToken: authToken ?? this.authToken,
      fontSize: fontSize ?? this.fontSize,
      darkMode: darkMode ?? this.darkMode,
      showLiveResponse: showLiveResponse ?? this.showLiveResponse,
      contextLength: contextLength ?? this.contextLength,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      ollamaHost: json['ollamaHost'] ?? '127.0.0.1',
      ollamaPort: json['ollamaPort'] ?? 11434,
      authToken: json['authToken'] ?? '',
      fontSize: json['fontSize'] ?? 16.0,
      darkMode: json['darkMode'] ?? false,
      showLiveResponse: json['showLiveResponse'] ?? false,
      contextLength: json['contextLength'] ?? 4096,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ollamaHost': ollamaHost,
      'ollamaPort': ollamaPort,
      'authToken': authToken,
      'fontSize': fontSize,
      'darkMode': darkMode,
      'showLiveResponse': showLiveResponse,
      'contextLength': contextLength,
    };
  }
}
