import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import './user_session.dart';

class AuthService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String collectionJueces = 'jueces';
  static const String collectionUsers = 'users';
  static const String collectionLogins = 'logins';

  // =========================
  // LOGIN PARA JUEZ (con auditoría y estado activo)
  // =========================
  Future<Map<String, dynamic>> loginWithCode(String code) async {
    try {
      final cleanCode = code.trim().toUpperCase();
      
      print('🔍 Buscando código juez: $cleanCode');
      
      final snapshot = await _db
          .collection(collectionJueces)
          .where('cod', isEqualTo: cleanCode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        print('❌ Código de juez no encontrado');
        return {
          'success': false,
          'message': 'Código de juez no encontrado',
          'user': null,
        };
      }

      final doc = snapshot.docs.first;
      final userData = doc.data() as Map<String, dynamic>;
      final userId = doc.id;
      
      print('✅ Juez encontrado: ${userData['nombre']}');
      print('📊 Estado actual: ${userData['activo'] ? "ACTIVO" : "INACTIVO"}');

      // 🔒 VERIFICAR SI YA ESTÁ ACTIVO (OCUPADO)
      if (userData['activo'] == true) {
        print('⚠️ Juez YA está activo (ocupado por alguien más)');
        return {
          'success': false,
          'message': 'Este juez ya está calificando en otro dispositivo. Espera a que termine.',
          'user': null,
        };
      }

      // 📝 REGISTRAR LOGIN (auditoría)
      await _db.collection(collectionLogins).add({
        'usuarioId': userId,
        'codigo': userData['cod'],
        'nombre': userData['nombre'],
        'rol': 'juez',
        'numjuez': userData['numjuez'],
        'timestamp': FieldValue.serverTimestamp(),
        'accion': 'login',
        'dispositivo': 'App Certamen',
        'tipo': 'juez',
      });

      // 🎯 GUARDAR EN UserSession usando setFromFirestore
      UserSession.setFromFirestore(
        firebaseDocId: userId,
        data: {
          'idInterno': userData['idInterno'] ?? '',
          'cod': userData['cod'] ?? '',
          'nombre': userData['nombre'] ?? '',
          'rol': 'juez',
          'numjuez': userData['numjuez'] ?? '',
          'activo': userData['activo'] ?? false,
        },
      );

      // 🔥 MARCAR COMO ACTIVO EN FIREBASE (OCUPAR EL USUARIO)
      await _db.collection(collectionJueces).doc(userId).update({
        'activo': true,
        'ultimaConexion': FieldValue.serverTimestamp(),
        'sesionActiva': true,
        'dispositivoActual': 'App Certamen',
      });

      print('🎉 Login juez exitoso para: ${UserSession.displayName}');
      print('🔐 Juez marcado como ACTIVO/OCUPADO');

      return {
        'success': true,
        'message': 'Bienvenido ${UserSession.displayName}!',
        'user': {
          'id': userId,
          'idInterno': userData['idInterno'],
          'code': userData['cod'], 
          'name': userData['nombre'],
          'role': 'juez',
          'judgeNumber': userData['numjuez'],
          'isActive': true,
        },
      };
      
    } on PlatformException catch (e) {
      print('❌ Error de Firebase: $e');
      return {
        'success': false,
        'message': 'Error de conexión con el servidor',
        'user': null,
      };
    } catch (e) {
      print('❌ Error inesperado: $e');
      return {
        'success': false,
        'message': 'Error inesperado. Intenta de nuevo.',
        'user': null,
      };
    }
  }

  // =========================
  // LOGIN PARA ADMINISTRADOR (FINALMENTE CORREGIDO)
  // =========================
  Future<Map<String, dynamic>> loginAdmin(String code) async {
    try {
      final cleanCode = code.trim();
      
      print('===============================');
      print('🔄 INTENTANDO LOGIN ADMIN');
      print('===============================');
      print('🔍 Código ingresado: $code');
      print('🔍 Código limpio: $cleanCode');
      
      // 1. Verificar conexión con Firebase
      print('\n🔌 Verificando conexión con Firebase...');
      try {
        await _db.collection('test').limit(1).get();
        print('✅ Conexión a Firebase OK');
      } catch (e) {
        print('❌ Error de conexión Firebase: $e');
        return {
          'success': false,
          'message': 'Error de conexión con la base de datos',
        };
      }
      
      // 3. BUSCAR ADMINISTRADOR - EN LA COLECCIÓN CORRECTA (jueces)
      print('\n🔍 BÚSQUEDA PRINCIPAL:');
      print('   Colección: jueces (¡CORREGIDO!)'); // Log actualizado
      print('   Condición 1: cod == "$cleanCode"');
      print('   Condición 2: rol == "admin"');
      
      final query = await _db
          .collection(collectionJueces) // *** CORRECCIÓN CLAVE ***
          .where('cod', isEqualTo: cleanCode)
          .where('rol', isEqualTo: 'admin')
          .limit(1)
          .get();

      print('📊 Resultados encontrados: ${query.docs.length}');
      
      // 4. SI NO ENCUENTRA, FALLAR
      if (query.docs.isEmpty) {
        print('\n❌ ADMIN NO ENCONTRADO CON CÓDIGO: $cleanCode');
        return {
          'success': false,
          'message': 'Código de administrador inválido. No se encontró ningún admin con código: $cleanCode',
        };
      }

      // 5. LOGIN EXITOSO
      final doc = query.docs.first;
      final data = doc.data();
      final userId = doc.id;

      print('\n✅ ADMINISTRADOR ENCONTRADO!');
      print('   🔑 ID: $userId');
      print('   👤 Nombre: ${data['nombre']}');
      print('   📊 Estado: ${data['activo'] ? "ACTIVO" : "INACTIVO"}');
      
      if (data['activo'] == false) {
        print('⚠️ Administrador inactivo');
        return {
          'success': false,
          'message': 'Administrador inactivo',
        };
      }

      // 📝 REGISTRAR LOGIN (auditoría)
      await _db.collection(collectionLogins).add({
        'usuarioId': userId,
        'codigo': data['cod'],
        'nombre': data['nombre'],
        'rol': 'admin',
        'numjuez': data['numjuez'], // Incluimos numjuez ya que está en jueces
        'timestamp': FieldValue.serverTimestamp(),
        'accion': 'login',
        'dispositivo': 'App Certamen',
        'tipo': 'admin',
      });

      // 🎯 GUARDAR EN UserSession usando setFromFirestore
      UserSession.setFromFirestore(
        firebaseDocId: userId,
        data: {
          'idInterno': data['idInterno']?.toString() ?? '',
          'cod': data['cod']?.toString() ?? cleanCode,
          'nombre': data['nombre']?.toString() ?? '',
          'rol': 'admin',
          'numjuez': data['numjuez']?.toString() ?? '', 
          'activo': data['activo'] ?? true,
        },
      );
      
      // 🔥 MARCAR COMO ACTIVO EN FIREBASE (OCUPAR EL USUARIO en la colección 'jueces')
      await _db.collection(collectionJueces).doc(userId).update({
        'activo': true,
        'ultimaConexion': FieldValue.serverTimestamp(),
        'sesionActiva': true,
        'dispositivoActual': 'App Certamen',
      });


      print('🎉 Login admin exitoso para: ${data['nombre']}');
      print('==========================================');

      return {
        'success': true,
        'message': 'Bienvenido administrador ${data['nombre']}!',
        'user': {
          ...data,
          'firebaseId': userId,
        }
      };
    } on PlatformException catch (e) {
      print('\n❌ ERROR DE FIREBASE: $e');
      print('📋 Tipo de error: ${e.runtimeType}');
      return {
        'success': false,
        'message': 'Error de conexión con el servidor: ${e.message}',
      };
    } catch (e) {
      print('\n❌ ERROR INESPERADO: $e');
      print('📋 Stack trace: ${e.toString()}');
      return {
        'success': false,
        'message': 'Error técnico: ${e.toString()}',
      };
    }
  }

  // =========================
  // LOGOUT PARA AMBOS ROLES
  // =========================
  Future<void> logout() async {
    try {
      final firebaseId = UserSession.firebaseId;
      final userRole = UserSession.rol;
      
      if (firebaseId != null && firebaseId.isNotEmpty) {
        // 📝 REGISTRAR LOGOUT (auditoría)
        await _db.collection(collectionLogins).add({
          'usuarioId': firebaseId,
          'codigo': UserSession.cod,
          'nombre': UserSession.nombre,
          'rol': UserSession.rol,
          'numjuez': UserSession.numjuez,
          'timestamp': FieldValue.serverTimestamp(),
          'accion': 'logout',
          'dispositivo': 'App Certamen',
          'tipo': userRole,
        });

        // 🔓 LIBERAR EL USUARIO SÓLO SI ES JUEZ O ADMIN (ya que ambos están en 'jueces')
        if (userRole == 'juez' || userRole == 'admin') {
          await _db.collection(collectionJueces).doc(firebaseId).update({
            'activo': false,
            'sesionActiva': false,
            'ultimaConexion': FieldValue.serverTimestamp(),
            // Limpiar participante activo
            'participanteActivo': FieldValue.delete(),
            'participanteActivoNombre': FieldValue.delete(),
          });
          print('👋 Logout exitoso. Usuario liberado de la colección jueces.');
        } else {
           print('👋 Logout exitoso. Administrador (otra colección).');
        }
      }
    } catch (e) {
      print('⚠️ Error en logout: $e');
    } finally {
      UserSession.clear();
    }
  }

  // =========================
  // VERIFICAR ESTADO DE SESIÓN
  // =========================
  Future<bool> checkSessionStatus(String userId, String role) async {
    try {
      if (role == 'juez' || role == 'admin') { // Admin también está en jueces
        final doc = await _db.collection(collectionJueces).doc(userId).get(); // Busca en jueces
        if (doc.exists) {
          // El campo sesionActiva existe para ambos en la colección jueces
          return doc.data()?['sesionActiva'] == true; 
        }
      }
      return false;
    } catch (e) {
      print('⚠️ Error verificando sesión: $e');
      return false;
    }
  }

  // =========================
  // MÉTODO COMPATIBILIDAD (alias para loginWithCode)
  // =========================
  Future<Map<String, dynamic>> loginJuez(String code) async {
    return await loginWithCode(code);
  }

  // =========================
  // MÉTODO PARA FORZAR LOGOUT (en caso de problemas)
  // =========================
  Future<void> forceLogout(String userId, String role) async {
    try {
      if (role == 'juez' || role == 'admin') { // Ambos roles están en jueces
        await _db.collection(collectionJueces).doc(userId).update({
          'activo': false,
          'sesionActiva': false,
          'ultimaConexion': FieldValue.serverTimestamp(),
          'participanteActivo': FieldValue.delete(),
          'participanteActivoNombre': FieldValue.delete(),
        });
        print('🔄 Usuario forzado a logout de jueces: $userId');
      }
      
      // Registrar en logs
      await _db.collection(collectionLogins).add({
        'usuarioId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'accion': 'forced_logout',
        'tipo': role,
        'motivo': 'Sesión forzada desde sistema',
      });
    } catch (e) {
      print('❌ Error en forceLogout: $e');
    }
  }
}