import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> subirAdmins() async {
  final firestore = FirebaseFirestore.instance;
  final batch = firestore.batch();

  final juecesCol = firestore.collection('jueces');

  // ================= ADMIN 1 =================
  batch.set(juecesCol.doc('013'), {
    'activo': true,
    'cod': '100',
    'dispositivoActual': 'App Certamen',
    'idInterno': 'admin001',
    'nombre': 'Azahel',
    'numjuez': 'Admin 01',
    'participanteActivo': null,
    'participanteActivoNombre': null,
    'rol': 'admin',
    'sesionActiva': true,
    'ultimaConexion': FieldValue.serverTimestamp(),
  });

  // ================= ADMIN 2 =================
  batch.set(juecesCol.doc('014'), {
    'activo': true,
    'cod': '101',
    'dispositivoActual': 'App Certamen',
    'idInterno': 'admin002',
    'nombre': 'Admin Dos',
    'numjuez': 'Admin 02',
    'participanteActivo': null,
    'participanteActivoNombre': null,
    'rol': 'admin',
    'sesionActiva': true,
    'ultimaConexion': FieldValue.serverTimestamp(),
  });

  // ================= ADMIN 3 =================
  batch.set(juecesCol.doc('015'), {
    'activo': true,
    'cod': '102',
    'dispositivoActual': 'App Certamen',
    'idInterno': 'admin003',
    'nombre': 'Admin Tres',
    'numjuez': 'Admin 03',
    'participanteActivo': null,
    'participanteActivoNombre': null,
    'rol': 'admin',
    'sesionActiva': true,
    'ultimaConexion': FieldValue.serverTimestamp(),
  });

  // ================= ADMIN 4 =================
  batch.set(juecesCol.doc('016'), {
    'activo': true,
    'cod': '103',
    'dispositivoActual': 'App Certamen',
    'idInterno': 'admin004',
    'nombre': 'Admin Cuatro',
    'numjuez': 'Admin 04',
    'participanteActivo': null,
    'participanteActivoNombre': null,
    'rol': 'admin',
    'sesionActiva': true,
    'ultimaConexion': FieldValue.serverTimestamp(),
  });

  await batch.commit();
  print('Admins cargados correctamente.');
}
