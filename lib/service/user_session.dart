import 'package:cloud_firestore/cloud_firestore.dart';

class UserSession {
  // ID del documento en Firebase (importante para actualizaciones)
  static String? firebaseId;
  
  // Datos del usuario desde Firebase (TUS CAMPOS)
  static String? idInterno;
  static String? cod;
  static String? nombre;
  static String? rol;
  static String? numjuez;
  
  // Estado de la sesión
  static bool? activo;
  static DateTime? loginTime;
  static DateTime? lastActivity;

  // ========== CONTEXTO DEL JUEZ ==========
  static String? _selectedParticipanteId;
  static String? _selectedParticipanteNombre;
  
  /// Actualizar participante seleccionado
  static Future<void> setSelectedParticipante({
    required String participanteId,
    required String participanteNombre,
  }) async {
    _selectedParticipanteId = participanteId;
    _selectedParticipanteNombre = participanteNombre;
    
    print('🎯 JUEZ SELECCIONÓ PARTICIPANTE:');
    print('   Juez: ${displayName}');
    print('   Participante: $participanteNombre');
    print('   ID Participante: $participanteId');
    print('⏰ Timestamp: ${DateTime.now()}');
    print('------------------------------------------');
    
    // Usar las propiedades estáticas directamente
    if (rol == 'juez' && firebaseId != null) {
      try {
        await FirebaseFirestore.instance
          .collection('jueces')
          .doc(firebaseId!)
          .update({
            'participanteActivo': participanteId,
            'participanteActivoNombre': participanteNombre,
            'ultimaConexion': FieldValue.serverTimestamp(),
          });
        
        print('✅ Guardado en Firebase: jueces/$firebaseId');
      } catch (e) {
        print('⚠️ Error guardando en Firebase: $e');
        // Continuamos aunque falle
      }
    }
  }
  
  /// Obtener participante seleccionado
  static String? get selectedParticipanteId => _selectedParticipanteId;
  static String? get selectedParticipanteNombre => _selectedParticipanteNombre;
  
  /// Verificar si hay participante seleccionado
  static bool get hasSelectedParticipante => 
      _selectedParticipanteId != null && _selectedParticipanteId!.isNotEmpty;
  
  /// Limpiar selección (para logout o cambio)
  static void clearSelectedParticipante() {
    _selectedParticipanteId = null;
    _selectedParticipanteNombre = null;
  }
  
  /// Inicializar contexto del juez (llamar después del login)
  static Future<void> initJuezContext() async {
    // Usar las propiedades estáticas directamente
    if (rol != 'juez' || firebaseId == null) return;
    
    print('🔄 RECUPERANDO CONTEXTO DEL JUEZ:');
    print('   Juez ID: $firebaseId');
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('jueces')
          .doc(firebaseId!)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final participanteId = data['participanteActivo'];
        final participanteNombre = data['participanteActivoNombre'];
        
        if (participanteId != null && participanteNombre != null) {
          _selectedParticipanteId = participanteId.toString();
          _selectedParticipanteNombre = participanteNombre.toString();
          print('   📍 Participante recuperado: $participanteNombre');
        }
      }
    } catch (e) {
      print('   ⚠️ Error recuperando contexto: $e');
    }
  }

  // ========== MÉTODOS DE CONFIGURACIÓN ==========
  
  /// Limpia toda la sesión (logout)
  static void clear() {
    firebaseId = null;
    idInterno = null;
    cod = null;
    nombre = null;
    rol = null;
    numjuez = null;
    activo = null;
    loginTime = null;
    lastActivity = null;
    clearSelectedParticipante();
  }

  /// Carga datos desde Firebase (TUS CAMPOS ESPECÍFICOS)
  static void setFromFirestore({
    required String firebaseDocId,
    required Map<String, dynamic> data,
  }) {
    firebaseId = firebaseDocId;
    idInterno = data['idInterno']?.toString() ?? '';
    cod = data['cod']?.toString() ?? '';
    nombre = data['nombre']?.toString() ?? '';
    rol = data['rol']?.toString() ?? '';
    numjuez = data['numjuez']?.toString() ?? '';
    activo = data['activo'] ?? true; // Sin cast innecesario
    loginTime = DateTime.now();
    lastActivity = DateTime.now();
  }

  /// Actualiza la última actividad (para timeouts)
  static void updateActivity() {
    lastActivity = DateTime.now();
  }

  // ========== GETTERS (PROPIEDADES CALCULADAS) ==========
  
  /// Verifica si hay un usuario logueado
  static bool get isLoggedIn => cod != null && cod!.isNotEmpty;
  
  /// Verifica si es juez
  static bool get isJudge => rol == 'juez';
  
  /// Verifica si es administrador
  static bool get isAdmin => rol == 'admin';
  
  /// Nombre para mostrar (formato: "Juez 12 - azahel")
  static String get displayName {
    if (numjuez != null && numjuez!.isNotEmpty && nombre != null && nombre!.isNotEmpty) {
      return '$numjuez - $nombre';
    }
    if (nombre != null && nombre!.isNotEmpty) {
      return nombre!;
    }
    if (numjuez != null && numjuez!.isNotEmpty) {
      return numjuez!;
    }
    return 'Usuario';
  }
  
  /// Solo el número del juez (ej: "Juez 12")
  static String get judgeNumberDisplay {
    if (numjuez != null && numjuez!.isNotEmpty) {
      return numjuez!;
    }
    return 'Juez';
  }
  
  /// Solo el nombre (ej: "azahel")
  static String get userNameDisplay {
    if (nombre != null && nombre!.isNotEmpty) {
      return nombre!;
    }
    return 'Usuario';
  }
  
  /// Estado actual de la sesión
  static String get status {
    if (!isLoggedIn) return 'Desconectado';
    return activo == true ? 'Conectado' : 'Inactivo';
  }
  
  /// Tiempo desde el login
  static String get sessionDuration {
    if (loginTime == null) return '--:--';
    
    final duration = DateTime.now().difference(loginTime!);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    
    return '$hours:$minutes';
  }

  // ========== MÉTODOS DE VALIDACIÓN ==========
  
  /// Verifica si la sesión ha expirado (30 minutos de inactividad)
  static bool get isExpired {
    if (lastActivity == null) return true;
    
    final inactivityDuration = DateTime.now().difference(lastActivity!);
    return inactivityDuration.inMinutes > 30;
  }
  
  /// Verifica si todos los datos requeridos están presentes
  static bool get isValid {
    return cod != null && 
           cod!.isNotEmpty && 
           nombre != null && 
           nombre!.isNotEmpty && 
           rol != null && 
           firebaseId != null;
  }

  // Estos getters ahora devuelven valores apropiados
  static String? get token => firebaseId;
  static String? get userId => firebaseId;

  // ========== MÉTODOS DE SEGURIDAD ==========
  
  /// Verifica si el usuario tiene permiso para una acción
  static bool hasPermission({required String action}) {
    if (!isLoggedIn) return false;
    
    switch (action) {
      case 'calificar':
        return isJudge;
      case 'administrar':
        return isAdmin;
      case 'ver_resultados':
        return isJudge || isAdmin;
      case 'configurar_evento':
        return isAdmin;
      default:
        return false;
    }
  }
  
  /// Valida que la sesión esté activa y válida
  static String? validateSession() {
    if (!isLoggedIn) {
      return 'No hay sesión activa';
    }
    
    if (!isValid) {
      return 'Sesión incompleta o corrupta';
    }
    
    if (isExpired) {
      return 'Sesión expirada por inactividad';
    }
    
    if (activo == false) {
      return 'Usuario marcado como inactivo';
    }
    
    return null; // ✅ Sesión válida
  }
}