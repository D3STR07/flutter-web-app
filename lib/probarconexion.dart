import 'package:cloud_firestore/cloud_firestore.dart';

void testFirebaseConnection() async {
  try {
    await FirebaseFirestore.instance
        .collection('test')
        .doc('conexion')
        .set({'status': 'ok', 'timestamp': DateTime.now().toString()});

    print(" Firebase conectado correctamente.");
  } catch (e) {
    print(" Error conectando a Firebase: $e");
  }
}
