import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Etapa {
  final String id;
  final String name;
  final String? subtitle;
  final String color;
  final int order; // ✅ MANTENER COMO 'order' (no etapaOrder)
  final String status;
  final DateTime? createdAt;
  final int? maxScore;
  final String type;
  final String? categoriaId;
  final String? categoriaNombre;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final int minParticipantes;
  final int maxParticipantes;
  final bool requiereVotacionUnica;
  final Map<String, dynamic> configuracion;
  final bool isSynced;
  final DateTime? lastUpdated;

  Etapa({
    required this.id,
    required this.name,
    this.subtitle,
    required this.color,
    required this.order, // ✅ AQUÍ TAMBIÉN
    required this.status,
    this.createdAt,
    this.maxScore,
    required this.type,
    this.categoriaId,
    this.categoriaNombre,
    this.fechaInicio,
    this.fechaFin,
    this.minParticipantes = 1,
    this.maxParticipantes = 20,
    this.requiereVotacionUnica = true,
    this.configuracion = const {},
    this.isSynced = true,
    this.lastUpdated,
  });

  // Constructor para creación local
  factory Etapa.createLocal({
    required String name,
    String? subtitle,
    required String color,
    required int order, // ✅
    String status = 'closed',
    int? maxScore,
    required String type,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    return Etapa(
      id: id,
      name: name,
      subtitle: subtitle,
      color: color,
      order: order, // ✅
      status: status,
      createdAt: DateTime.now(),
      maxScore: maxScore,
      type: type,
      isSynced: false,
      lastUpdated: DateTime.now(),
    );
  }

  // Convertir a Map para SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'subtitle': subtitle,
      'color': color,
      'order': order, // ✅ EN SQLITE TAMBIÉN 'order'
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'maxScore': maxScore,
      'type': type,
      'categoriaId': categoriaId,
      'categoriaNombre': categoriaNombre,
      'fechaInicio': fechaInicio?.toIso8601String(),
      'fechaFin': fechaFin?.toIso8601String(),
      'minParticipantes': minParticipantes,
      'maxParticipantes': maxParticipantes,
      'requiereVotacionUnica': requiereVotacionUnica ? 1 : 0,
      'configuracion': configuracion.isNotEmpty ? 
          configuracion.entries.map((e) => '${e.key}:${e.value}').join('|') : '',
      'isSynced': isSynced ? 1 : 0,
      'lastUpdated': lastUpdated?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  // Crear desde Map de SQLite
  factory Etapa.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> configMap = {};
    if (map['configuracion'] != null && map['configuracion'].toString().isNotEmpty) {
      final configParts = map['configuracion'].toString().split('|');
      for (var part in configParts) {
        final keyValue = part.split(':');
        if (keyValue.length == 2) {
          configMap[keyValue[0]] = keyValue[1];
        }
      }
    }

    return Etapa(
      id: map['id'],
      name: map['name'],
      subtitle: map['subtitle'],
      color: map['color'],
      order: map['order'] ?? 0, // ✅ AQUÍ TAMBIÉN
      status: map['status'],
      createdAt: map['createdAt'] != null ? 
          DateTime.parse(map['createdAt']) : null,
      maxScore: map['maxScore'],
      type: map['type'],
      categoriaId: map['categoriaId'],
      categoriaNombre: map['categoriaNombre'],
      fechaInicio: map['fechaInicio'] != null ? 
          DateTime.parse(map['fechaInicio']) : null,
      fechaFin: map['fechaFin'] != null ? 
          DateTime.parse(map['fechaFin']) : null,
      minParticipantes: map['minParticipantes'],
      maxParticipantes: map['maxParticipantes'],
      requiereVotacionUnica: map['requiereVotacionUnica'] == 1,
      configuracion: configMap,
      isSynced: map['isSynced'] == 1,
      lastUpdated: map['lastUpdated'] != null ? 
          DateTime.parse(map['lastUpdated']) : null,
    );
  }

  // ✅✅✅ LO ÚNICO QUE CAMBIAMOS ES ESTO: mapeo de Firebase
  factory Etapa.fromFirestore(Map<String, dynamic> data, String id) {
    return Etapa(
      id: id,
      name: data['name'] ?? 'Sin nombre',
      subtitle: data['subtitle'],
      color: data['color'] ?? 'blue',
      // AQUÍ ESTÁ EL ARREGLO: 'etapa_order' en Firebase -> 'order' en Dart
      order: (data['etapa_order'] as num?)?.toInt() ?? 0,
      status: data['status'] ?? 'closed',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      maxScore: (data['maxScore'] as num?)?.toInt(),
      type: data['type'] ?? 'pasarela',
      categoriaId: data['categoriaId'],
      categoriaNombre: data['categoriaNombre'],
      fechaInicio: (data['fechaInicio'] as Timestamp?)?.toDate(),
      fechaFin: (data['fechaFin'] as Timestamp?)?.toDate(),
      minParticipantes: (data['minParticipantes'] as num?)?.toInt() ?? 1,
      maxParticipantes: (data['maxParticipantes'] as num?)?.toInt() ?? 20,
      requiereVotacionUnica: data['requiereVotacionUnica'] ?? true,
      configuracion: data['configuracion'] ?? {},
      isSynced: true,
    );
  }

  // Para Firebase
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'subtitle': subtitle,
      'color': color,
      // AQUÍ TAMBIÉN: 'order' en Dart -> 'etapa_order' en Firebase
      'order': order,
      'status': status,
      'createdAt': createdAt,
      'maxScore': maxScore,
      'type': type,
      'categoriaId': categoriaId,
      'categoriaNombre': categoriaNombre,
      'fechaInicio': fechaInicio,
      'fechaFin': fechaFin,
      'minParticipantes': minParticipantes,
      'maxParticipantes': maxParticipantes,
      'requiereVotacionUnica': requiereVotacionUnica,
      'configuracion': configuracion,
      'ultimaActualizacion': DateTime.now(),
    };
  }

  // Copiar con cambios
  Etapa copyWith({
    String? id,
    String? name,
    String? subtitle,
    String? color,
    int? order, // ✅
    String? status,
    DateTime? createdAt,
    int? maxScore,
    String? type,
    String? categoriaId,
    String? categoriaNombre,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? minParticipantes,
    int? maxParticipantes,
    bool? requiereVotacionUnica,
    Map<String, dynamic>? configuracion,
    bool? isSynced,
    DateTime? lastUpdated,
  }) {
    return Etapa(
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      color: color ?? this.color,
      order: order ?? this.order, // ✅
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      maxScore: maxScore ?? this.maxScore,
      type: type ?? this.type,
      categoriaId: categoriaId ?? this.categoriaId,
      categoriaNombre: categoriaNombre ?? this.categoriaNombre,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      minParticipantes: minParticipantes ?? this.minParticipantes,
      maxParticipantes: maxParticipantes ?? this.maxParticipantes,
      requiereVotacionUnica: requiereVotacionUnica ?? this.requiereVotacionUnica,
      configuracion: configuracion ?? this.configuracion,
      isSynced: isSynced ?? this.isSynced,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // Getters para compatibilidad
  String get nombre => name;
  String get descripcion => subtitle ?? '';
  int get orden => order; // ✅
  String get estado => status;

  bool get estaCerrada => status == 'closed';
  bool get estaActiva => status == 'active';
  bool get estaFinalizada => status == 'finished';

  bool get puedeActivar => !estaActiva && !estaFinalizada;
  bool get puedeFinalizar => estaActiva;
  bool get puedeReabrir => estaFinalizada;

  String get estadoTexto {
    switch (status) {
      case 'closed':
        return 'CERRADA';
      case 'active':
        return 'EN CURSO';
      case 'finished':
        return 'FINALIZADA';
      default:
        return 'DESCONOCIDO';
    }
  }

  Color get colorFlutter {
    return _convertStringToColor(color);
  }

  bool get isActive => status == 'active';
  bool get isFinished => status == 'finished';

  String get icono {
    switch (status) {
      case 'closed':
        return '🔒';
      case 'active':
        return '⚡';
      case 'finished':
        return '✅';
      default:
        return '📁';
    }
  }

  bool get esAccesibleParaJueces => estaActiva;

  String get tituloCorto {
    if (name.length > 15) {
      return '${name.substring(0, 15)}...';
    }
    return name;
  }

  Color _convertStringToColor(String colorString) {
    switch (colorString.toLowerCase()) {
      case 'blue':
        return Colors.blue;
      case 'red':
        return Colors.red;
      case 'green':
        return Colors.green;
      case 'purple':
        return Colors.purple;
      case 'orange':
        return Colors.orange;
      case 'yellow':
        return Colors.yellow;
      case 'pink':
        return Colors.pink;
      case 'teal':
        return Colors.teal;
      case 'cyan':
        return Colors.cyan;
      case 'amber':
        return Colors.amber;
      case 'indigo':
        return Colors.indigo;
      case 'deepPurple':
        return Colors.deepPurple;
      case 'lightBlue':
        return Colors.lightBlue;
      case 'lime':
        return Colors.lime;
      default:
        return Colors.blue;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Etapa &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}