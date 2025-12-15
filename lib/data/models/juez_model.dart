// lib/data/models/juez_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Juez {
  final String id;
  final String idInterno;
  final String cod;
  final String nombre;
  final String numjuez;
  final String rol;
  final bool activo;

  Juez({
    required this.id,
    required this.idInterno,
    required this.cod,
    required this.nombre,
    required this.numjuez,
    required this.rol,
    required this.activo,
  });

  factory Juez.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Juez(
      id: doc.id,
      idInterno: data['idInterno'] ?? '',
      cod: data['cod'] ?? '',
      nombre: data['nombre'] ?? '',
      numjuez: data['numjuez'] ?? '',
      rol: data['rol'] ?? 'juez',
      activo: data['activo'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'idInterno': idInterno,
      'cod': cod,
      'nombre': nombre,
      'numjuez': numjuez,
      'rol': rol,
      'activo': activo,
    };
  }

  String get displayName {
    if (numjuez.isNotEmpty) {
      return '$numjuez - $nombre';
    }
    return nombre;
  }

  bool get isActive => activo;
  bool get isAdmin => rol == 'admin';
}