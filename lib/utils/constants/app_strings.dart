class AppStrings {
  // --- Información de la app ---
  static const String appName = 'Señorita Noche Buena';
  static const String appVersion = '1.0.0';
  static const String errorGeneric = 'Ocurrió un error. Inténtalo de nuevo.';
  
  // --- Textos de la pantalla de bienvenida ---
  static const String welcomeTitle = 'Señorita Noche Buena';
  static const String welcomeSubtitle = 'Sistema de Calificación Oficial';
  static const String startButton = 'INICIAR CALIFICACIÓN'; // Texto de botón cambiado para consistencia
  static const String eventHost = 'Huejutla de Reyes, Hidalgo';
  
  // --- Rutas de navegación ---
  static const String routeLogin = '/login';
  static const String routeJudgeHome = '/judge-home';
  static const String routeAdminHome = '/admin-home';

  // --- Login Screen ---
  static const String loginTitle = 'Ingreso al Sistema';
  static const String selectRolePrompt = 'Selecciona tu Rol para continuar'; // Nuevo
  static const String codeInputPrompt = 'Ingresa tu código de acceso'; // Nuevo
  
  // Roles
  static const String roleNone = 'none'; // Estado inicial
  static const String roleJudge = 'judge';
  static const String roleAdmin = 'admin';
  static const String roleJudgeLabel = 'JUEZ';
  static const String roleAdminLabel = 'ADMINISTRADOR';
  
  // Botones y Subtítulos de Rol
  static const String judgeButton = 'SOY JUEZ';
  static const String judgeSubtitle = 'Acceso exclusivo para miembros del jurado'; // Nuevo
  static const String adminButton = 'SOY ADMINISTRADOR';
  static const String adminSubtitle = 'Control total y reportes del sistema'; // Nuevo

  // Formulario de Código
  static const String codeHint = 'Ingresa tu código';
  static const String enterCode = 'INGRESAR';
  
  // Ejemplos
  static const String judgeCodeExample = 'Ejemplo: JUEZ-01 o JUEZ05'; // Nuevo
  static const String adminCodeExample = 'Ejemplo: ADMIN2024'; // Nuevo

  // --- Validaciones y Errores ---
  static const String codeRequired = 'El código es requerido';
  static const String codeMinLength = 'El código debe tener al menos 4 caracteres'; // Cambiado a 4 por UX
  static const String codeJudgeInvalid = 'Código de Juez inválido. Verifica tus credenciales.'; // Nuevo
  static const String codeAdminInvalid = 'Código de Administrador inválido.'; // Nuevo
  
  // Mensajes de Bienvenida
  static const String welcomeJudge = 'Bienvenido, Juez(a)';
  static const String welcomeAdmin = 'Bienvenido, Administrador';
}