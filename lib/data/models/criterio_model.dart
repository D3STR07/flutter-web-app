import 'package:cloud_firestore/cloud_firestore.dart';

class Criterio {
  final String id;
  final String etapaId;
  final String text;
  final int order;
  final double maxScore;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Criterio({
    required this.id,
    required this.etapaId,
    required this.text,
    required this.order,
    this.maxScore = 10.0,
    this.createdAt,
    this.updatedAt,
  });

  factory Criterio.fromFirestore(Map<String, dynamic> data, String id) {
    return Criterio(
      id: id,
      etapaId: data['etapaId']?.toString() ?? '',
      text: data['text']?.toString() ?? '',
      order: (data['order'] as int?) ?? 0,
      maxScore: (data['maxScore'] as num?)?.toDouble() ?? 10.0,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'etapaId': etapaId,
      'text': text,
      'order': order,
      'maxScore': maxScore,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'etapaId': etapaId,
      'text': text,
      'order': order,
      'maxScore': maxScore,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Criterio.fromMap(Map<String, dynamic> map) {
    return Criterio(
      id: map['id']?.toString() ?? '',
      etapaId: map['etapaId']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      order: map['order'] as int? ?? 0,
      maxScore: (map['maxScore'] as num?)?.toDouble() ?? 10.0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : null,
    );
  }

  Criterio copyWith({
    String? id,
    String? etapaId,
    String? text,
    int? order,
    double? maxScore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Criterio(
      id: id ?? this.id,
      etapaId: etapaId ?? this.etapaId,
      text: text ?? this.text,
      order: order ?? this.order,
      maxScore: maxScore ?? this.maxScore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Criterio(id: $id, text: $text, maxScore: $maxScore)';
  }
}