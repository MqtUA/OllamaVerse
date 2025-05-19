class OllamaModel {
  final String name;
  final String modifiedAt;
  final int size;
  final String digest;
  final Map<String, dynamic> details;

  OllamaModel({
    required this.name,
    required this.modifiedAt,
    required this.size,
    required this.digest,
    required this.details,
  });

  factory OllamaModel.fromJson(Map<String, dynamic> json) {
    return OllamaModel(
      name: json['name'],
      modifiedAt: json['modified_at'] ?? '',
      size: json['size'] ?? 0,
      digest: json['digest'] ?? '',
      details: json['details'] ?? {},
    );
  }
}
