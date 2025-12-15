import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

// Pantallas
import 'ui/screens/welcome_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/juez/participantes_screen.dart';
import 'ui/screens/juez/etapas_screen.dart';
import 'ui/screens/admin/admin_dashboard_screen.dart';

// Constantes
import 'utils/constants/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase SÍ funciona en Web
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ❌ SQLite y sync SOLO en mobile
  if (!kIsWeb) {
    // importa aquí si quieres luego
    // final dbHelper = DatabaseHelper();
    // await dbHelper.initCalificacionesTables();
    // SyncService().startMonitoring();
  }

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
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const WelcomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/participantes': (_) => const ParticipantesScreen(),
        '/etapas': (_) => const EtapasScreen(),
        '/admin-home': (_) => const AdminDashboardScreen(),
      },
    );
  }
}
