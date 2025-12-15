import 'package:cloud_firestore/cloud_firestore.dart';

class Calificacion {
  final String id;
  final String juezId;
  final String participanteId;
  final String etapaId;
  final String criterioId;
  final double puntaje;
  final String? comentario;
  final bool isSynced;
  final DateTime fecha;
  final DateTime? fechaSync;

  Calificacion({
    required this.id,
    required this.juezId,
    required this.participanteId,
    required this.etapaId,
    required this.criterioId,
    required this.puntaje,
    this.comentario,
    this.isSynced = false,
    required this.fecha,
    this.fechaSync,
  });

  // Para crear nueva calificación
  factory Calificacion.createNew({
    required String juezId,
    required String participanteId,
    required String etapaId,
    required String criterioId,
    required double puntaje,
    String? comentario,
  }) {
    final now = DateTime.now();
    final docId = '${participanteId}_${etapaId}_${juezId}_${criterioId}_${now.millisecondsSinceEpoch}';
    
    return Calificacion(
      id: docId,
      juezId: juezId,
      participanteId: participanteId,
      etapaId: etapaId,
      criterioId: criterioId,
      puntaje: puntaje,
      comentario: comentario,
      isSynced: false,
      fecha: now,
    );
  }

  // Para estructura organizada (participante/etapa/criterios)
  factory Calificacion.fromFirestoreOrganizada(Map<String, dynamic> data, String docId) {
    final parts = docId.split('_');
    
    return Calificacion(
      id: docId,
      juezId: data['juezId']?.toString() ?? '',
      participanteId: data['participanteId']?.toString() ?? 
                     (parts.length > 0 ? parts[0] : ''),
      etapaId: data['etapaId']?.toString() ?? 
               (parts.length > 1 ? parts[1] : ''),
      criterioId: data['criterioId']?.toString() ?? 
                  (parts.length > 3 ? parts[3] : ''),
      puntaje: (data['puntaje'] as num?)?.toDouble() ?? 0.0,
      comentario: data['comentario']?.toString(),
      isSynced: data['isSynced'] as bool? ?? true,
      fecha: data['fecha'] != null
          ? (data['fecha'] as Timestamp).toDate()
          : DateTime.now(),
      fechaSync: data['fechaSync'] != null
          ? (data['fechaSync'] as Timestamp).toDate()
          : null,
    );
  }

  // Para estructura plana (colección simple)
  factory Calificacion.fromFirestorePlana(Map<String, dynamic> data, String id) {
    return Calificacion(
      id: id,
      juezId: data['juezId']?.toString() ?? '',
      participanteId: data['participanteId']?.toString() ?? '',
      etapaId: data['etapaId']?.toString() ?? '',
      criterioId: data['criterioId']?.toString() ?? '',
      puntaje: (data['puntaje'] as num?)?.toDouble() ?? 0.0,
      comentario: data['comentario']?.toString(),
      isSynced: data['isSynced'] as bool? ?? true,
      fecha: data['fecha'] != null
          ? (data['fecha'] as Timestamp).toDate()
          : DateTime.now(),
      fechaSync: data['fechaSync'] != null
          ? (data['fechaSync'] as Timestamp).toDate()
          : null,
    );
  }

  // === MÉTODOS NUEVOS PARA RESOLVER LOS ERRORES ===
  
  // Método genérico toFirestore (usa estructura plana por defecto)
  Map<String, dynamic> toFirestore() {
    return toFirestorePlana(); // Cambia a toFirestoreOrganizada() si necesitas estructura organizada
  }

  // Método genérico fromFirestore (usa estructura plana por defecto)
  // Este es el que estás llamando en tu servicio
  factory Calificacion.fromFirestore(Map<String, dynamic> data) {
    // Si data tiene 'id' como campo, úsalo, sino genera uno
    final id = data['id']?.toString() ?? '';
    
    return Calificacion(
      id: id.isNotEmpty ? id : 'temp_${DateTime.now().millisecondsSinceEpoch}',
      juezId: data['juezId']?.toString() ?? '',
      participanteId: data['participanteId']?.toString() ?? '',
      etapaId: data['etapaId']?.toString() ?? '',
      criterioId: data['criterioId']?.toString() ?? '',
      puntaje: (data['puntaje'] as num?)?.toDouble() ?? 0.0,
      comentario: data['comentario']?.toString(),
      isSynced: data['isSynced'] as bool? ?? true,
      fecha: data['fecha'] != null
          ? (data['fecha'] is Timestamp 
              ? (data['fecha'] as Timestamp).toDate()
              : DateTime.parse(data['fecha'].toString()))
          : DateTime.now(),
      fechaSync: data['fechaSync'] != null
          ? (data['fechaSync'] is Timestamp
              ? (data['fechaSync'] as Timestamp).toDate()
              : DateTime.parse(data['fechaSync'].toString()))
          : null,
    );
  }

  // Alternativa: fromFirestore con id separado (más común en Firestore)
  factory Calificacion.fromFirestoreWithId(Map<String, dynamic> data, String id) {
    return Calificacion(
      id: id,
      juezId: data['juezId']?.toString() ?? '',
      participanteId: data['participanteId']?.toString() ?? '',
      etapaId: data['etapaId']?.toString() ?? '',
      criterioId: data['criterioId']?.toString() ?? '',
      puntaje: (data['puntaje'] as num?)?.toDouble() ?? 0.0,
      comentario: data['comentario']?.toString(),
      isSynced: data['isSynced'] as bool? ?? true,
      fecha: data['fecha'] != null
          ? (data['fecha'] as Timestamp).toDate()
          : DateTime.now(),
      fechaSync: data['fechaSync'] != null
          ? (data['fechaSync'] as Timestamp).toDate()
          : null,
    );
  }
  // === FIN DE MÉTODOS NUEVOS ===

  // Para guardar en estructura organizada
  Map<String, dynamic> toFirestoreOrganizada() {
    return {
      'juezId': juezId,
      'participanteId': participanteId,
      'etapaId': etapaId,
      'criterioId': criterioId,
      'puntaje': puntaje,
      'comentario': comentario ?? '',
      'fecha': Timestamp.fromDate(fecha),
      'fechaSync': fechaSync != null ? Timestamp.fromDate(fechaSync!) : null,
      'juezNombre': '', // Se llenará en el servicio
      'isSynced': isSynced,
    };
  }

  // Para guardar en estructura plana
  Map<String, dynamic> toFirestorePlana() {
    return {
      'juezId': juezId,
      'participanteId': participanteId,
      'etapaId': etapaId,
      'criterioId': criterioId,
      'puntaje': puntaje,
      'comentario': comentario,
      'isSynced': isSynced,
      'fecha': Timestamp.fromDate(fecha),
      'fechaSync': fechaSync != null ? Timestamp.fromDate(fechaSync!) : null,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'juezId': juezId,
      'participanteId': participanteId,
      'etapaId': etapaId,
      'criterioId': criterioId,
      'puntaje': puntaje,
      'comentario': comentario,
      'isSynced': isSynced ? 1 : 0,
      'fecha': fecha.toIso8601String(),
      'fechaSync': fechaSync?.toIso8601String(),
    };
  }

  factory Calificacion.fromMap(Map<String, dynamic> map) {
    return Calificacion(
      id: map['id']?.toString() ?? '',
      juezId: map['juezId']?.toString() ?? '',
      participanteId: map['participanteId']?.toString() ?? '',
      etapaId: map['etapaId']?.toString() ?? '',
      criterioId: map['criterioId']?.toString() ?? '',
      puntaje: (map['puntaje'] as num?)?.toDouble() ?? 0.0,
      comentario: map['comentario']?.toString(),
      isSynced: map['isSynced'] == 1,
      fecha: DateTime.parse(map['fecha']),
      fechaSync: map['fechaSync'] != null
          ? DateTime.parse(map['fechaSync']!)
          : null,
    );
  }

  Calificacion copyWith({
    String? id,
    String? juezId,
    String? participanteId,
    String? etapaId,
    String? criterioId,
    double? puntaje,
    String? comentario,
    bool? isSynced,
    DateTime? fecha,
    DateTime? fechaSync,
  }) {
    return Calificacion(
      id: id ?? this.id,
      juezId: juezId ?? this.juezId,
      participanteId: participanteId ?? this.participanteId,
      etapaId: etapaId ?? this.etapaId,
      criterioId: criterioId ?? this.criterioId,
      puntaje: puntaje ?? this.puntaje,
      comentario: comentario ?? this.comentario,
      isSynced: isSynced ?? this.isSynced,
      fecha: fecha ?? this.fecha,
      fechaSync: fechaSync ?? this.fechaSync,
    );
  }

  Calificacion markAsSynced() {
    return copyWith(
      isSynced: true,
      fechaSync: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'Calificacion(id: $id, juez: $juezId, participante: $participanteId, etapa: $etapaId, criterio: $criterioId, puntaje: $puntaje, isSynced: $isSynced)';
  }
}