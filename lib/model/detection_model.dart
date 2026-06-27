class DetectionModel {
  final String name;
  final double confidence;

  DetectionModel({
    required this.name,
    required this.confidence,
  });

  factory DetectionModel.fromJson(Map<String, dynamic> json) {
    return DetectionModel(
      name: json["name"],
      confidence: json["confidence"].toDouble(),
    );
  }
}