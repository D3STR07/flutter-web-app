import 'package:cloud_firestore/cloud_firestore.dart';

class Participante {
  final String id;
  final String idInterno;
  final String nombre;
  final String? fotoUrl;
  final bool activo;
  final DateTime? createdAt;

  // NUEVO
  final double totalScore;
  final bool califica; // visible para jueces
  final int? posicionActual;

  Participante({
    required this.id,
    required this.idInterno,
    required this.nombre,
    this.fotoUrl,
    required this.activo,
    this.createdAt,
    this.totalScore = 0.0,
    this.califica = true,
    this.posicionActual,
  });

  factory Participante.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Participante(
      id: doc.id,
      idInterno: data['idInterno'] ?? '',
      nombre: data['nombre'] ?? '',
      fotoUrl: data['fotoUrl'],
      activo: data['activo'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),

      // NUEVO
      totalScore: (data['totalScore'] ?? 0).toDouble(),
      califica: data['califica'] ?? true,
      posicionActual: data['posicionActual'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idInterno': idInterno,
      'nombre': nombre,
      'fotoUrl': fotoUrl,
      'activo': activo,
      'createdAt': createdAt,

      // NUEVO
      'totalScore': totalScore,
      'califica': califica,
      'posicionActual': posicionActual,
    };
  }

  String get shortName {
    if (nombre.length > 20) {
      return '${nombre.substring(0, 20)}...';
    }
    return nombre;
  }

  String get displayName {
    if (nombre.length > 30) {
      return '${nombre.substring(0, 30)}...';
    }
    return nombre;
  }

  bool get isActive => activo;
}
