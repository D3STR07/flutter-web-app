class ParticipantModel {
  final String id;
  final String name;
  final String photoUrl;

  final bool isActive;       // sigue en competencia
  final bool isQualified;    // pasó el corte actual
  final double totalScore;   // promedio general

  ParticipantModel({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.isActive,
    required this.isQualified,
    required this.totalScore,
  });

  factory ParticipantModel.fromMap(Map<String, dynamic> data, String id) {
    return ParticipantModel(
      id: id,
      name: data['name'],
      photoUrl: data['photoUrl'],
      isActive: data['isActive'] ?? true,
      isQualified: data['isQualified'] ?? true,
      totalScore: (data['totalScore'] ?? 0).toDouble(),
    );
  }
}
