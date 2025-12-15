import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:reina_nochebuena/inserarta5jueces.dart';
import 'firebase_options.dart';
import 'service/sync_service.dart';
import 'utils/helpers/database_helper.dart';

// Constantes
import 'package:reina_nochebuena/utils/constants/app_strings.dart';
import 'package:reina_nochebuena/utils/constants/app_colors.dart';

// Pantallas
import 'ui/screens/welcome_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/juez/participantes_screen.dart';
import 'ui/screens/juez/etapas_screen.dart';
import 'ui/screens/admin/admin_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase inicializado correctamente');
  } catch (e) {
    print('❌ Error inicializando Firebase: $e');
  }

  // INICIALIZAR BASE DE DATOS SQLite
  try {
    final dbHelper = DatabaseHelper();
    await dbHelper.initCalificacionesTables();
    print('✅ SQLite inicializado correctamente');
  } catch (e) {
    print('❌ Error inicializando SQLite: $e');
  }

  // Iniciar servicio de sincronización
  final syncService = SyncService();
  syncService.startMonitoring();

  // Cargar cache inicial
  WidgetsBinding.instance.addPostFrameCallback((_) {
    syncService.cargarCacheParticipantes();
  });

  //await subirAdmins();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Reina Nochebuena',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.primaryBackground,
        colorScheme: ColorScheme.dark(
          primary: AppColors.accentColor,
          secondary: AppColors.primaryColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/participantes': (context) => const ParticipantesScreen(),
        '/etapas': (context) => const EtapasScreen(),
        
        // Ruta temporal para admin
        '/admin-home': (context) => const AdminDashboardScreen(),
      },
    );
  }
}